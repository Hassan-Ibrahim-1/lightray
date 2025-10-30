const log = engine.debug.log.scoped(.raytracer);
const cube_len: usize = 5000;

const std = @import("std");
const Allocator = mem.Allocator;
const builtin = @import("builtin");
const mem = std.mem;

const engine = @import("engine");
const math = engine.math;
const res = engine.res;
const fs = engine.fs;
const ig = engine.ig;
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

/// image format is always rgb
pub fn raytrace(alloc: Allocator, spec: ImageSpec) Allocator.Error!Image {
    const len = spec.width * spec.height * image_format.channels();
    _ = len; // autofix

    const pixels = try alloc.alloc(Color3, spec.width * spec.height);
    errdefer alloc.free(pixels);

    @memset(pixels, .cyan);

    return Image{
        .width = spec.width,
        .height = spec.height,
        .format = image_format,
        .data = mem.sliceAsBytes(pixels),
    };
}
