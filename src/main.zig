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

const cube_len: usize = 5000;

const Vec3 = math.Vec3;

fn init(rp: *res.ResourcePool) !void {
    const scene = engine.scene();
    scene.skybox_hidden = true;

    const cube = scene.createActor("some cube");
    try cube.render_item.addMesh(renderer.shapes().cube);

    const t, const handle = try rp.createTexture();
    log.info("loading texture", .{});
    t.* = try .init("engine/textures/fractal.jpeg");

    const ri = &cube.render_item;
    try ri.material.diffuse_textures.append(ri.alloc, handle);
}

var start: Vec3 = .init(0, 0, -1);
var end: Vec3 = .init(0, 0, 1);
var thickness: f32 = 0.1;

fn update() !void {
    const mouse_ray = input.getMouseRay();
    const aabb = renderer.shapes().cube.aabb;

    const hit = mouse_ray.getIntersection(aabb);

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
