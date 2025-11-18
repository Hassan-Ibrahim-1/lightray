const std = @import("std");
const builtin = @import("builtin");

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
const raytracer = @import("raytracer.zig");
const opts = @import("opts");

const log = engine.debug.log.scoped(.main);

var fb_handle: Framebuffer.Handle = undefined;
var rt_image: engine.Image = undefined;

fn init(rp: *res.ResourcePool) !void {
    const scene = engine.scene();
    _ = scene; // autofix
    // scene.skybox_hidden = true;

    const fb, fb_handle = try rp.createFramebuffer();
    const window_size = engine.windowSize();
    fb.* = .init(window_size.width, window_size.height);

    fb.bind();
    defer fb.unbind();

    const ca = fb.createColorAttachment(&.{
        .minimum_filter = .linear,
        .magnification_filter = .linear,
    });

    rt_image = try raytracer.raytrace(
        engine.arena(),
        .{ .width = 1280, .height = 720 },
    );

    rt_image.flipY();
    ca.setImage(rt_image);
    rt_image.flipY();

    _ = fb.createRenderbufferAttachment(.depth24_stencil8);

    std.debug.assert(fb.isComplete());

    renderer.setRenderTexture(ca.handle);

    std.fs.cwd().makeDir("renders") catch |err|
        if (err != error.PathAlreadyExists) {
            return err;
        };
}

var input_buf: [1024]u8 = @splat(0);

const mem = std.mem;

fn update() !void {
    if (engine.cursorEnabled()) {
        ig.begin("rt");
        defer ig.end();

        _ = ig.textInput("file name", &input_buf);
        if (ig.button("write image")) {
            const alloc = engine.frameAllocator();

            const null_index = mem.sliceTo(&input_buf, 0);
            if (null_index.len != 0) {
                const path = try std.fmt.allocPrintSentinel(
                    alloc,
                    "renders/{s}",
                    .{null_index},
                    0,
                );

                try rt_image.writePng(path);
                input_buf = @splat(0);
            } else {
                log.warn("empty path. not writing to file", .{});
            }
        }
    }
}

fn deinit() void {}

pub fn main() !void {
    if (opts.use_engine) {
        defer log.info("TERMINATED", .{});

        if (builtin.os.tag == .linux) {
            try engine.init(&.{
                .width = 3840,
                .height = 2160,
                .name = "lightray",
            });
        } else {
            try engine.init(&.{
                .width = 1280,
                .height = 720,
                .name = "lightray",
            });
        }
        defer engine.deinit();
        engine.run(&.{
            .init = init,
            .update = update,
            .deinit = deinit,
        });
    } else {
        var gpa: std.heap.DebugAllocator(.{}) = .init;
        defer std.debug.assert(gpa.deinit() == .ok);

        const alloc = gpa.allocator();

        const image = try raytracer.raytrace(
            alloc,
            .{ .width = 1280, .height = 720 },
        );
        defer alloc.free(image.data);

        const out = std.fmt.comptimePrint("{s}", .{opts.render_out});
        try image.writePng(out);
    }
}
