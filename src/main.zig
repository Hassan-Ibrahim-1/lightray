const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const ArrayList = std.ArrayList;
const builtin = @import("builtin");

const engine = @import("engine");
const renderer = engine.renderer;
const Shader = engine.Shader;
const VertexBuffer = engine.VertexBuffer;
const Color = engine.Color;
const math = engine.math;
const Vec3 = math.Vec3;
const gl = engine.gl;
const debug = engine.debug;
const utils = engine.utils;
const Pair = utils.Pair;
const ig = engine.ig;
const input = engine.input;

const log = debug.log.scoped(.main);

fn init() !void {
    const scene = engine.scene();
    const actor = scene.createActor("cube");
    const m = actor.render_item.createMesh();
    m.* = try renderer.cubeModel().meshes.items[0].clone();
    m.sendData();

    for (actor.render_item.meshes.items) |*mesh| {
        actor.bounding_box.insertMesh(mesh);
    }
}

fn update() !void {}

fn deinit() void {}

pub fn main() !void {
    if (builtin.os.tag == .linux) {
        try engine.init(&.{
            .width = 3840,
            .height = 2160,
            .name = "lightray",
        });
    } else {
        try engine.init(&.{
            .width = 1920,
            .height = 1080,
            .name = "lightray",
        });
    }
    defer engine.deinit();
    engine.run(&.{
        .init = init,
        .update = update,
        .deinit = deinit,
    });
}
