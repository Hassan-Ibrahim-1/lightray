const log = engine.debug.log.scoped(.raytracer);
const cube_len: usize = 5000;

const std = @import("std");
const Allocator = mem.Allocator;
const Io = std.Io;
const builtin = @import("builtin");
const mem = std.mem;

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
pub const Color3 = @import("raytracer/Color3.zig");
pub const Interval = @import("raytracer/Interval.zig");

const Viewport = struct {
    pixel_delta_u: Vec3,
    pixel_delta_v: Vec3,
    top_left_pixel: Vec3,

    pub fn init(
        aspect_ratio: f32,
        image_width: u32,
        focal_length: f32,
        camera_center: Vec3,
    ) Viewport {
        const image_height = @max(1, cast.as(f32, image_width) / aspect_ratio);

        const vp_height = 2.0;
        const vp_width = vp_height * aspect_ratio;

        // Basis vectors for the viewport
        const vp_u = Vec3.init(vp_width, 0, 0); // horizontal (right)
        const vp_v = Vec3.init(0, -vp_height, 0); // vertical (down)

        // Pixel deltas
        const pixel_delta_u = vp_u.divValue(cast.as(f32, image_width));
        const pixel_delta_v = vp_v.divValue(cast.as(f32, image_height));

        // Upper-left corner of the viewport in world space
        const vp_center = camera_center.sub(Vec3.init(0, 0, focal_length));
        const vp_upper_left = vp_center
            .sub(vp_u.mulValue(0.5)) // move left half width
            .sub(vp_v.mulValue(0.5)); // move up half height

        // Center of the top-left pixel
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

    fn setFaceNormal(self: *HitRecord, r: Ray, outward_normal: Vec3) void {
        self.front_face = r.direction.dot(outward_normal) < 0;
        self.normal = if (self.front_face) outward_normal else outward_normal.negate();
    }
};

const assert = std.debug.assert;

const Hittable = union(enum) {
    sphere: math.Sphere,

    fn hit(self: Hittable, r: Ray, ray_t: Interval) ?HitRecord {
        return switch (self) {
            .sphere => |s| sphereHit(s, r, ray_t),
        };
    }

    fn sphereHit(s: math.Sphere, r: Ray, ray_t: Interval) ?HitRecord {
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

pub const image_format = Image.Format.rgb;

pub const Error = Allocator.Error || Io.Writer.Error;

const max_depth = 500;

/// image format is always rgb
pub fn raytrace(alloc: Allocator, spec: ImageSpec) Error!Image {
    var pixels: std.ArrayList(Color3) = .empty;
    try pixels.ensureTotalCapacityPrecise(alloc, spec.width * spec.height);
    errdefer pixels.deinit(alloc);

    const camera_center = Vec3.zero;
    const focal_length = 1.0;

    const viewport = Viewport.init(16.0 / 9.0, spec.width, focal_length, camera_center);

    var hittables: std.ArrayList(Hittable) = .empty;
    defer hittables.deinit(alloc);

    try hittables.append(alloc, .{
        .sphere = .{
            .position = .init(0, 0, -1),
            .radius = 0.5,
        },
    });

    try hittables.append(alloc, .{
        .sphere = .{
            .position = .init(0, -100.5, -1),
            .radius = 100,
        },
    });

    const samples_per_pixel = 10;
    const pixel_sample_scale = 1.0 / cast.as(f32, samples_per_pixel);

    for (0..spec.height) |j| {
        log.info("scanlines remaining: {}", .{spec.height - j});
        for (0..spec.width) |i| {
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
                        .add(viewport.pixel_delta_v.mulValue(cast.as(f32, j) + sample_square.y));

                    const ray_direction = pixel_center.sub(camera_center);
                    const r = Ray.init(camera_center, ray_direction);
                    col = col.add(rayColor(r, hittables.items, max_depth).clampedVec3());
                }
                break :col Color3.fromVec3(col.mulValue(pixel_sample_scale));
            };

            pixels.appendAssumeCapacity(pixel_color);
        }
    }

    return Image{
        .width = spec.width,
        .height = spec.height,
        .format = image_format,
        .data = mem.sliceAsBytes(try pixels.toOwnedSlice(alloc)),
    };
}

const Ray = math.Ray;

fn rayColor(ray: Ray, hittables: []const Hittable, depth: u32) Color3 {
    if (depth == 0) return .black;

    const starting_interval: Interval = .{ .min = 0.001, .max = math.infinity };

    if (closestHit(hittables, ray, starting_interval)) |rec| {
        const direction = Vec3.randomOnHemisphere(rec.normal);
        return .fromVec3(
            rayColor(.init(rec.p, direction), hittables, depth - 1).clampedVec3().mulValue(0.5),
        );
    }

    const unit_direction = ray.direction.normalized();
    const a = 0.5 * (unit_direction.y + 1.0);
    // return (1.0 - a) * Color3.init(1.0, 1.0, 1.0) + a * color(0.5, 0.7, 1.0);
    return Color3.white.mul(1.0 - a).add(Color3.initF32(0.5, 0.7, 1.0).mul(a));
}
