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

pub const ImageSpec = struct {
    width: u32,
    height: u32,
};

pub const image_format = Image.Format.rgb;

pub const Error = Allocator.Error || Io.Writer.Error;

/// image format is always rgb
pub fn raytrace(alloc: Allocator, spec: ImageSpec) Error!Image {
    var pixels: std.ArrayList(Color3) = .empty;
    try pixels.ensureTotalCapacityPrecise(alloc, spec.width * spec.height);
    errdefer pixels.deinit(alloc);

    const camera_center = Vec3.zero;
    const focal_length = 1.0;

    const viewport = Viewport.init(16.0 / 9.0, spec.width, focal_length, camera_center);

    for (0..spec.height) |j| {
        for (0..spec.width) |i| {
            // const pixel_center = pixel00_loc + (i * pixel_delta_u) + (j * pixel_delta_v);
            const pixel_center = viewport.top_left_pixel
                .add(viewport.pixel_delta_u.mulValue(cast.as(f32, i)))
                .add(viewport.pixel_delta_v.mulValue(cast.as(f32, j)));

            const ray_direction = pixel_center.sub(camera_center);
            const r = Ray.init(camera_center, ray_direction);

            const pixel_color = rayColor(r);

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

fn rayColor(ray: Ray) Color3 {
    const sphere = math.Sphere{
        .position = .init(0, 0, -1),
        .radius = 0.5,
    };

    if (ray.intersectsWithSphere(sphere)) |hit| {
        const n = ray.at(hit).sub(.init(0, 0, -1)).normalized();
        return Color3.fromVec3(n.add(.fromValue(1.0)).mulValue(0.5));
    }

    const unit_direction = ray.direction.normalized();
    const a = 0.5 * (unit_direction.y + 1.0);
    // return (1.0 - a) * Color3.init(1.0, 1.0, 1.0) + a * color(0.5, 0.7, 1.0);
    return Color3.white.mul(1.0 - a).add(Color3.initF32(0.5, 0.7, 1.0).mul(a));
}
