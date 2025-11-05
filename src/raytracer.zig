const std = @import("std");
const Io = std.Io;
const mem = std.mem;
const assert = std.debug.assert;
const Allocator = mem.Allocator;
const builtin = @import("builtin");

const engine = @import("engine");
const cast = engine.cast;
const math = engine.math;
const res = engine.res;
const fs = engine.fs;
const input = engine.input;
const renderer = engine.renderer;
const debug = renderer.debug;
const Framebuffer = res.Framebuffer;
const RenderPass = renderer.RenderPass;
const Vec3 = math.Vec3;
const Image = engine.Image;
pub const image_format = Image.Format.rgb;
const Ray = math.Ray;

pub const Color3 = @import("raytracer/Color3.zig");
pub const Interval = @import("raytracer/Interval.zig");

const log = engine.debug.log.scoped(.raytracer);
const cube_len: usize = 5000;

const Viewport = struct {
    pixel_delta_u: Vec3,
    pixel_delta_v: Vec3,
    top_left_pixel: Vec3,

    fn init(
        aspect_ratio: f32,
        image_width: u32,
        focal_length: f32,
        camera_center: Vec3,
    ) Viewport {
        const image_height = @max(1, cast.as(f32, image_width) / aspect_ratio);

        const vp_height = 2.0;
        const vp_width = vp_height * aspect_ratio;

        const vp_u = Vec3.init(vp_width, 0, 0);
        const vp_v = Vec3.init(0, -vp_height, 0);

        const pixel_delta_u = vp_u.divValue(cast.as(f32, image_width));
        const pixel_delta_v = vp_v.divValue(cast.as(f32, image_height));

        const vp_center = camera_center.sub(Vec3.init(0, 0, focal_length));
        const vp_upper_left = vp_center
            .sub(vp_u.mulValue(0.5))
            .sub(vp_v.mulValue(0.5));

        const top_left_pixel = vp_upper_left
            .add(pixel_delta_u.mulValue(0.5))
            .add(pixel_delta_v.mulValue(0.5));

        return .{
            .pixel_delta_u = pixel_delta_u,
            .pixel_delta_v = pixel_delta_v,
            .top_left_pixel = top_left_pixel,
        };
    }
};

const HitRecord = struct {
    p: Vec3,
    normal: Vec3,
    t: f32,
    front_face: bool,
    material: Material,

    fn setFaceNormal(self: *HitRecord, r: Ray, outward_normal: Vec3) void {
        self.front_face = r.direction.dot(outward_normal) < 0;
        self.normal = if (self.front_face) outward_normal else outward_normal.negate();
    }
};

const Sphere = struct {
    position: Vec3,
    radius: f32,
    material: Material,
};

const Hittable = union(enum) {
    sphere: Sphere,

    fn hit(self: Hittable, r: Ray, ray_t: Interval) ?HitRecord {
        return switch (self) {
            .sphere => |s| sphereHit(s, r, ray_t),
        };
    }

    fn sphereHit(s: Sphere, r: Ray, ray_t: Interval) ?HitRecord {
        assert(s.radius >= 0);

        const oc = s.position.sub(r.origin);
        const a = r.direction.lengthSquared();
        const h = r.direction.dot(oc);
        const c = oc.lengthSquared() - (s.radius * s.radius);
        const discriminant = h * h - a * c;
        if (discriminant < 0) {
            return null;
        }

        const sqrt_discriminant = @sqrt(discriminant);
        var root = (h - sqrt_discriminant) / a;
        if (!ray_t.surrounds(root)) {
            root = (h + sqrt_discriminant) / a;
            if (!ray_t.surrounds(root)) {
                return null;
            }
        }

        var rec: HitRecord = undefined;
        rec.t = root;
        rec.p = r.at(root);
        rec.setFaceNormal(r, rec.p.sub(s.position).divValue(s.radius));
        return rec;
    }
};

const Material = union(enum) {
    const ScatterInfo = struct {
        attenuation: Color3,
        scattered: Ray,
    };

    lambertian: struct {
        albedo: Color3,

        fn scatter(self: *const @This(), rec: HitRecord) ?ScatterInfo {
            var scatter_direction = rec.normal.add(Vec3.randomNormalized());
            if (scatter_direction.nearZero()) {
                scatter_direction = rec.normal;
            }
            return ScatterInfo{
                .scattered = .init(rec.p, scatter_direction),
                .attenuation = self.albedo,
            };
        }
    },

    metal: struct {
        albedo: Color3,

        fn scatter(self: *const @This(), r: Ray, rec: HitRecord) ?ScatterInfo {
            const reflected = Vec3.reflect(r.direction, rec.normal);
            return ScatterInfo{
                .scattered = .init(rec.p, reflected),
                .attenuation = self.albedo,
            };
        }
    },

    fn scatter(self: *const Material, r: Ray, rec: HitRecord) ?ScatterInfo {
        return switch (self.*) {
            .lambertian => |l| l.scatter(rec),
            .metal => |m| m.scatter(r, rec),
        };
    }
};

fn closestHit(hittables: []const Hittable, r: Ray, ray_t: Interval) ?HitRecord {
    var rec: ?HitRecord = null;
    var closest = ray_t.max;
    for (hittables) |*h| {
        if (h.hit(r, ray_t)) |hit_rec| {
            if (hit_rec.t > closest) continue;
            rec = hit_rec;
            closest = hit_rec.t;
        }
    }
    return rec;
}

pub const ImageSpec = struct {
    width: u32,
    height: u32,
};

pub const Error = Allocator.Error || Io.Writer.Error;

const max_depth = 500;

/// image format is always rgb
pub fn raytrace(alloc: Allocator, spec: ImageSpec) !Image {
    const camera_center = Vec3.zero;
    const focal_length = 1.0;

    const viewport = Viewport.init(16.0 / 9.0, spec.width, focal_length, camera_center);

    var hittables: std.ArrayList(Hittable) = .empty;
    defer hittables.deinit(alloc);

    try hittables.append(alloc, .{
        .sphere = .{
            .position = .init(0, 0, -1),
            .material = .{ .lambertian = .{ .albedo = .red } },
            .radius = 0.5,
        },
    });

    try hittables.append(alloc, .{
        .sphere = .{
            .position = .init(0, -100.5, -1),
            .material = .{ .lambertian = .{ .albedo = .green } },
            .radius = 100,
        },
    });

    const samples_per_pixel = 10;
    const pixel_sample_scale = 1.0 / cast.as(f32, samples_per_pixel);

    const pixels = try alloc.alloc(Color3, spec.width * spec.height);
    errdefer alloc.free(pixels);

    var thread_pool: std.Thread.Pool = undefined;
    try thread_pool.init(.{ .allocator = alloc });
    defer thread_pool.deinit();

    var wait_group: std.Thread.WaitGroup = .{};

    var timer = try std.time.Timer.start();

    for (0..spec.height) |row| {
        const start = row * spec.width;
        const end = (row + 1) * spec.width;
        const color_out = pixels[start..end];
        thread_pool.spawnWg(
            &wait_group,
            raytraceRow,
            .{
                cast.as(u32, row),
                spec.width,
                samples_per_pixel,
                pixel_sample_scale,
                &viewport,
                camera_center,
                hittables.items,
                color_out,
            },
        );
    }

    log.info("all workers dispatched", .{});

    wait_group.wait();

    const elapsed = cast.as(f64, timer.read()) / cast.as(f64, std.time.ns_per_s);
    log.info("rendered in {d:.4} seconds", .{elapsed});

    return Image{
        .width = spec.width,
        .height = spec.height,
        .format = image_format,
        .data = mem.sliceAsBytes(pixels),
    };
}

fn raytraceRow(
    row: u32,
    width: u32,
    samples_per_pixel: u32,
    pixel_sample_scale: f32,
    viewport: *const Viewport,
    camera_center: Vec3,
    hittables: []const Hittable,
    color_out: []Color3,
) void {
    for (0..width) |i| {
        const pixel_color: Color3 = col: {
            var col: Vec3 = .zero;
            for (0..samples_per_pixel) |_| {
                const sample_square = Vec3.init(
                    math.randomFloat(f32, 0, 1) - 0.5,
                    math.randomFloat(f32, 0, 1) - 0.5,
                    0,
                );

                // const pixel_center = pixel00_loc + (i * pixel_delta_u) + (j * pixel_delta_v);
                const pixel_center = viewport.top_left_pixel
                    .add(viewport.pixel_delta_u.mulValue(cast.as(f32, i) + sample_square.x))
                    .add(viewport.pixel_delta_v.mulValue(cast.as(f32, row) + sample_square.y));

                const ray_direction = pixel_center.sub(camera_center);
                const r = Ray.init(camera_center, ray_direction);
                col = col.add(rayColor(r, hittables, max_depth).clampedVec3());
            }
            break :col Color3.fromVec3(col.mulValue(pixel_sample_scale));
        };
        color_out[i] = pixel_color.toGamma();
    }
}

const use_lambertian_diffuse = true;

fn rayColor(ray: Ray, hittables: []const Hittable, depth: u32) Color3 {
    if (depth == 0) return .black;

    const starting_interval: Interval = .{ .min = 0.001, .max = math.infinity };

    if (closestHit(hittables, ray, starting_interval)) |rec| {
        if (rec.material.scatter(ray, rec)) |scatter_info| {
            return scatter_info.attenuation.mulColor(rayColor(
                scatter_info.scattered,
                hittables,
                depth - 1,
            ));
        }
        return .black;
    }

    const unit_direction = ray.direction.normalized();
    const a = 0.5 * (unit_direction.y + 1.0);
    // return (1.0 - a) * Color3.init(1.0, 1.0, 1.0) + a * color(0.5, 0.7, 1.0);
    return Color3.white.mul(1.0 - a).add(Color3.initF32(0.5, 0.7, 1.0).mul(a));
}
