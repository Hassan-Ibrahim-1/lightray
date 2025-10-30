const std = @import("std");
const engine = @import("engine");
const math = engine.math;
const log = engine.debug.log.scoped(.main);
const builtin = @import("builtin");
const res = engine.res;
const fs = engine.fs;
const ig = engine.ig;
const input = engine.input;
const renderer = engine.renderer;
const debug = renderer.debug;
const Framebuffer = res.Framebuffer;
const RenderPass = renderer.RenderPass;

const cube_len: usize = 5000;

const Vec3 = math.Vec3;

var fb_handle: Framebuffer.Handle = undefined;
var fb_image: engine.Image = undefined;

const State = struct {
    render_pass: RenderPass,
};
var state: State = undefined;

fn init(rp: *res.ResourcePool) !void {
    const scene = engine.scene();
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
    ca.setEmptyImage(window_size.width, window_size.height, .rgba);

    _ = fb.createRenderbufferAttachment(.depth24_stencil8);

    std.debug.assert(fb.isComplete());

    renderer.setRenderTexture(ca.handle);

    state.render_pass = .{
        .spec = .{
            .render_debug_shapes = true,
            .render_billboards = true,
            .render_skybox = true,
        },
        .actors = undefined,
        .framebuffer = fb_handle,
        .clear_color = .from(26),
    };

    const cube = scene.createActor("cube");
    try cube.render_item.addMesh(renderer.shapes().cube);
}

var start: Vec3 = .init(0, 0, -1);
var end: Vec3 = .init(0, 0, 1);
var thickness: f32 = 0.1;

fn update() !void {
    const mouse_ray = input.getMouseRay();
    const aabb = renderer.shapes().cube.aabb;

    const hit = mouse_ray.getIntersection(aabb);

    const scene = engine.scene();
    state.render_pass.actors = scene.actors.values();
    try renderer.addRenderPass(&state.render_pass);

    if (engine.cursorEnabled()) {
        ig.begin("hm");
        defer ig.end();
        ig.fpsCounter();
        const mouse_pos = input.getMousePos();
        ig.print("mouse pos: {f}", .{mouse_pos});
        if (hit != null) {
            ig.text("intersection");
        } else {
            ig.text("no intersection");
        }

        _ = ig.dragVec3Ex("start", &start, 0.1, null, null);
        _ = ig.dragVec3Ex("end", &end, 0.1, null, null);
        _ = ig.dragFloatEx("thickness", &thickness, 0.01, 0, 100);
    }

    if (hit) |t| {
        const p = mouse_ray.at(t);
        debug.drawCube(.{
            .color = .green,
            .transform = .{
                .position = p,
                .scale = .fromValue(0.1),
            },
        });
    }

    debug.drawArrow(.{
        .start = start,
        .end = end,
        .thickness = thickness,
        .color = .orange,
    });

    debug.drawCube(.{
        .color = .yellow,
        .transform = .{
            .position = start,
            .scale = .fromValue(0.1),
        },
    });

    debug.drawCube(.{
        .color = .cyan,
        .transform = .{
            .position = end,
            .scale = .fromValue(0.1),
        },
    });
}

fn deinit() void {}

pub fn main() !void {
    defer log.info("TERMINATED", .{});

    if (builtin.os.tag == .linux) {
        try engine.init(&.{
            .width = 3840,
            .height = 2160,
            .name = "linalg",
        });
    } else {
        try engine.init(&.{
            .width = 1920,
            .height = 1080,
            .name = "linalg",
        });
    }
    defer engine.deinit();
    engine.run(&.{
        .init = init,
        .update = update,
        .deinit = deinit,
    });
}
