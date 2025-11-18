const std = @import("std");
const Io = std.Io;
const mem = std.mem;
const assert = std.debug.assert;
const Allocator = mem.Allocator;
const builtin = @import("builtin");

const engine = @import("engine");
const cast = engine.cast;
const math = engine.math;
const input = engine.input;
const Vec3 = math.Vec3;
const Image = engine.Image;
pub const image_format = Image.Format.rgb;

pub const Color3 = @import("raytracer/Color3.zig");
pub const Interval = @import("raytracer/Interval.zig");

const log = engine.debug.log.scoped(.raytracer);
const cube_len: usize = 5000;

const Ray = struct {
    const Self = @This();

    origin: Vec3,
    direction: Vec3,
    /// I don't like that this has a time field, this
    /// should be tracked by objects themselves and not by
    /// this struct
    time: f32,

    pub const zero: Ray = .{
        .origin = .zero,
        .direction = .zero,
        .time = 0,
    };

    pub fn init(origin: Vec3, direction: Vec3, time: f32) Self {
        return .{
            .origin = origin,
            .direction = direction,
            .time = time,
        };
    }

    pub fn at(self: Self, t: f32) Vec3 {
        // P(t) = A + tB
        const tb = self.direction.mulValue(t);
        return Vec3.add(self.origin, tb);
    }

    /// returns the t value where intersection occurs.
    pub fn intersectsWithSphere(self: Ray, sphere: Sphere) ?f32 {
        const oc = sphere.position.sub(self.origin);
        const a = self.direction.lengthSquared();
        const h = self.direction.dot(oc);
        const c = oc.lengthSquared() - (sphere.radius * sphere.radius);
        const discriminant = h * h - a * c;
        if (discriminant < 0) {
            return null;
        }
        return (h - @sqrt(discriminant)) / a;
    }
};

const Viewport = struct {
    pixel_delta_u: Vec3,
    pixel_delta_v: Vec3,
    top_left_pixel: Vec3,

    fn init(
        aspect_ratio: f32,
        image_width: u32,
        camera: *const Camera,
    ) Viewport {
        const image_height: i32 = @intFromFloat(
            @max(1, cast.as(f32, image_width) / aspect_ratio),
        );

        const theta = std.math.degreesToRadians(camera.vertical_fov);
        const h = @tan(theta / 2);
        const vp_height = 2.0 * h * camera.focus_distance;
        const vp_width = vp_height *
            (cast.as(f32, image_width) / cast.as(f32, image_height));

        const vp_u = camera.right.mulValue(vp_width);
        const vp_v = camera.up.mulValue(-vp_height);

        const pixel_delta_u = vp_u.divValue(cast.as(f32, image_width));
        const pixel_delta_v = vp_v.divValue(cast.as(f32, image_height));

        const vp_center = camera.position;

        const vp_upper_left = vp_center
            .sub(camera.front.mulValue(camera.focus_distance))
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

const Camera = struct {
    up: Vec3, // v
    right: Vec3, // u
    front: Vec3, // w

    world_up: Vec3,
    position: Vec3,
    look_at: Vec3,

    focal_length: f32,
    vertical_fov: f32,

    defocus_angle: f32,
    focus_distance: f32,

    defocus_disk_horizontal_radius: Vec3, // u
    defocus_disk_vertical_radius: Vec3, // v

    fn init(
        position: Vec3,
        look_at: Vec3,
        world_up: Vec3,
        vertical_fov: f32,
        defocus_angle: f32,
        focus_distance: f32,
    ) Camera {
        const front = position.sub(look_at).normalized();
        const right = Vec3.cross(world_up, front);
        const up = Vec3.cross(front, right);
        const focal_length = position.sub(look_at).length();
        const defocus_radius = focus_distance * @tan(
            std.math.degreesToRadians(defocus_angle / 2.0),
        );
        const defocus_disk_horizontal_radius = right.mulValue(defocus_radius);
        const defocus_disk_vertical_radius = up.mulValue(defocus_radius);

        return .{
            .up = up,
            .right = right,
            .front = front,
            .world_up = world_up,
            .position = position,
            .look_at = look_at,
            .focal_length = focal_length,
            .vertical_fov = vertical_fov,
            .defocus_angle = defocus_angle,
            .focus_distance = focus_distance,
            .defocus_disk_horizontal_radius = defocus_disk_horizontal_radius,
            .defocus_disk_vertical_radius = defocus_disk_vertical_radius,
        };
    }

    fn defocusDiskSample(self: *const Camera) Vec3 {
        const p = Vec3.randomOnUnitDisk();
        const horizontal = self.defocus_disk_horizontal_radius.mulValue(p.x);
        const vertical = self.defocus_disk_vertical_radius.mulValue(p.y);
        return self.position.add(horizontal).add(vertical);
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
    /// `position` is a ray because the sphere can move
    /// idk if I like this strategy; think more about how
    /// to represent moving objects later
    position: Ray,
    radius: f32,
    material: Material,

    fn initStatic(position: Vec3, radius: f32, material: Material) Sphere {
        return .{
            .position = .init(position, .zero, 0),
            .radius = radius,
            .material = material,
        };
    }

    fn initMovable(
        position: Vec3,
        end: Vec3,
        radius: f32,
        material: Material,
    ) Sphere {
        return .{
            .position = .init(position, end.sub(position), 0),
            .radius = radius,
            .material = material,
        };
    }
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

        const current_position = s.position.at(r.time);
        const oc = current_position.sub(r.origin);
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
        rec.material = s.material;
        rec.setFaceNormal(r, rec.p.sub(current_position).divValue(s.radius));
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

        fn scatter(self: *const @This(), r: Ray, rec: HitRecord) ?ScatterInfo {
            const scatter_direction = Vec3.randomOnHemisphere(rec.normal);
            // if (scatter_direction.nearZero()) {
            //     scatter_direction = rec.normal;
            // }
            return ScatterInfo{
                .scattered = .init(rec.p, scatter_direction, r.time),
                .attenuation = self.albedo,
            };
        }
    },

    metal: struct {
        albedo: Color3,
        /// between 0 and 1
        fuzz: f32,

        fn scatter(self: *const @This(), r: Ray, rec: HitRecord) ?ScatterInfo {
            const reflected = Vec3.reflect(r.direction, rec.normal)
                .normalized()
                .add(Vec3.randomNormalized().mulValue(self.fuzz));

            return ScatterInfo{
                .scattered = .init(rec.p, reflected, r.time),
                .attenuation = self.albedo,
            };
        }
    },

    dielectric: struct {
        refraction_index: f32,

        fn scatter(self: @This(), r: Ray, rec: HitRecord) ?ScatterInfo {
            const ri = if (rec.front_face) 1.0 / self.refraction_index else self.refraction_index;

            const direction = dir: {
                const unit_direction = r.direction.normalized();
                const cos_theta = @min(1.0, Vec3.dot(unit_direction.negate(), rec.normal));
                const sin_theta = @sqrt(1.0 - cos_theta * cos_theta);
                const cannot_refract = ri * sin_theta > 1.0;
                if (cannot_refract or reflectance(cos_theta, ri) > math.randomFloat01(f32)) {
                    break :dir Vec3.reflect(unit_direction, rec.normal);
                }
                break :dir Vec3.refract(unit_direction, rec.normal, ri);
            };

            return ScatterInfo{
                .scattered = .init(rec.p, direction, r.time),
                .attenuation = .white,
            };
        }

        fn reflectance(cosine: f32, refraction_index: f32) f32 {
            const r = (1 - refraction_index) / (1 + refraction_index);
            const r0 = r * r;
            return r0 + (1 - r0) * std.math.pow(f32, (1 - cosine), 5);
        }
    },

    fn scatter(self: *const Material, r: Ray, rec: HitRecord) ?ScatterInfo {
        return switch (self.*) {
            .lambertian => |l| l.scatter(r, rec),
            .metal => |m| m.scatter(r, rec),
            .dielectric => |d| d.scatter(r, rec),
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

const max_depth = 50;

/// image format is always rgb
pub fn raytrace(alloc: Allocator, spec: ImageSpec) !Image {
    const camera = Camera.init(
        Vec3.init(13, 2, 3),
        Vec3.init(0, 0, 0),
        Vec3.init(0, 1, 0),
        20,
        0.2,
        8.0,
    );

    const viewport = Viewport.init(
        16.0 / 9.0,
        spec.width,
        &camera,
    );

    var hittables: std.ArrayList(Hittable) = .empty;
    defer hittables.deinit(alloc);

    const ground_material = Material{ .lambertian = .{ .albedo = .initF32(0.5, 0.5, 0.5) } };
    try hittables.append(alloc, .{
        .sphere = .initStatic(
            .init(0, -1000, 0),
            1000,
            ground_material,
        ),
    });

    const count = 6;
    var a: i32 = -count;
    while (a < count) : (a += 1) {
        var b: i32 = -count;
        while (b < count) : (b += 1) {
            const choose_mat = math.randomFloat01(f32);
            const center = Vec3.init(
                cast.as(f32, a) + 0.9 * math.randomFloat01(f32),
                0.2,
                cast.as(f32, b) + 0.9 * math.randomFloat01(f32),
            );
            const radius = 0.2;
            if (center.sub(.init(4, radius, 0)).length() > 0.9) {
                if (choose_mat < 0.8) {
                    const albedo = Color3.random().mulColor(Color3.random());
                    const material = Material{ .lambertian = .{ .albedo = albedo } };
                    const center2 = center.add(Vec3.init(0, math.randomFloat(f32, 0, 0.5), 0));
                    try hittables.append(alloc, .{
                        .sphere = .initMovable(center, center2, radius, material),
                    });
                } else if (choose_mat < 0.95) {
                    const blue = math.randomFloat01(f32);
                    const albedo = Color3.initF32(0.5, 1, blue);
                    const fuzz = math.randomFloat(f32, 0, 0.5);
                    const material = Material{ .metal = .{ .albedo = albedo, .fuzz = fuzz } };
                    try hittables.append(alloc, .{
                        .sphere = .initStatic(
                            center,
                            radius,
                            material,
                        ),
                    });
                } else {
                    const material = Material{ .dielectric = .{ .refraction_index = 1.5 } };
                    try hittables.append(alloc, .{
                        .sphere = .initStatic(
                            center,
                            radius,
                            material,
                        ),
                    });
                }
            }
        }
    }

    const material1 = Material{ .dielectric = .{ .refraction_index = 1.5 } };
    try hittables.append(alloc, .{
        .sphere = .initStatic(
            .init(0, 1, 0),
            1.0,
            material1,
        ),
    });

    const material2 = Material{ .lambertian = .{ .albedo = .initF32(0.4, 0.2, 0.1) } };
    try hittables.append(alloc, .{
        .sphere = .initStatic(
            .init(-4, 1, 0),
            1.0,
            material2,
        ),
    });

    const material3 = Material{ .metal = .{ .albedo = .initF32(0.7, 0.6, 0.5), .fuzz = 0.0 } };
    try hittables.append(alloc, .{
        .sphere = .initStatic(
            .init(4, 1, 0),
            1.0,
            material3,
        ),
    });

    const samples_per_pixel = 60;
    const pixel_sample_scale = 1.0 / cast.as(f32, samples_per_pixel);

    const pixels = try alloc.alloc(Color3, spec.width * spec.height);
    errdefer alloc.free(pixels);

    var thread_pool: std.Thread.Pool = undefined;
    try thread_pool.init(.{ .allocator = alloc });
    defer thread_pool.deinit();

    log.info("using {} threads", .{thread_pool.threads.len});

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
                &camera,
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
    camera: *const Camera,
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

                const ray_origin =
                    if (camera.defocus_angle <= 0)
                        camera.position
                    else
                        camera.defocusDiskSample();

                const ray_time = math.randomFloat01(f32);

                const ray_direction = pixel_center.sub(camera.position);
                const r = Ray.init(ray_origin, ray_direction, ray_time);
                col = col.add(rayColor(r, hittables, max_depth).clampedVec3());
            }
            break :col Color3.fromVec3(col.mulValue(pixel_sample_scale));
        };
        color_out[i] = pixel_color.toGamma();
    }
}

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
