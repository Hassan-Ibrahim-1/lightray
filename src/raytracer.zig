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

    for (0..spec.height) |j| {
        for (0..spec.width) |i| {
            const r = cast.as(f32, i) / cast.as(f32, spec.width - 1);
            const g = cast.as(f32, j) / cast.as(f32, spec.height - 1);
            const b = 0;

            const ir = cast.as(u8, 255.999 * r);
            const ig = cast.as(u8, 255.999 * g);
            const ib = cast.as(u8, 255.999 * b);

            pixels.appendAssumeCapacity(.init(ir, ig, ib));
        }
    }

    return Image{
        .width = spec.width,
        .height = spec.height,
        .format = image_format,
        .data = mem.sliceAsBytes(try pixels.toOwnedSlice(alloc)),
    };
}
