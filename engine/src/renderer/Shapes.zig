const std = @import("std");
const Allocator = std.mem.Allocator;
const engine = @import("../engine.zig");
const res = engine.res;
const Mesh = res.Mesh;
const ResourcePool = res.ResourcePool;
const math = engine.math;
const Vec3 = math.Vec3;
const Vec2 = math.Vec2;
const Vertex = engine.Vertex;
const Model = res.Model;

const Shapes = @This();

rect: Mesh,
cube: Mesh,
arrow: Mesh,

pub fn init(rp: *ResourcePool) Model.LoadMeshError!Shapes {
    return .{
        .rect = try createRectMesh(rp),
        .cube = try createCubeMesh(rp),
        .arrow = try createArrowMesh(rp),
    };
}

fn createRectMesh(rp: *ResourcePool) Allocator.Error!Mesh {
    const normal = Vec3.init(0, 0, 1);
    const vertices = [_]Vertex{
        Vertex.init(Vec3.init(0.5, 0.5, 0), normal, Vec2.init(1, 1)),
        Vertex.init(Vec3.init(0.5, -0.5, 0), normal, Vec2.init(1, 0)),
        Vertex.init(Vec3.init(-0.5, -0.5, 0), normal, Vec2.init(0, 0)),
        Vertex.init(Vec3.init(-0.5, 0.5, 0), normal, Vec2.init(0, 1)),
    };

    const indices = [_]u32{
        0, 1, 3,
        1, 2, 3,
    };

    const vb, const vb_handle = try rp.createVertexBuffer();
    vb.* = .init(rp.alloc);
    try vb.vertices.appendSlice(vb.alloc, &vertices);
    try vb.indices.appendSlice(vb.alloc, &indices);
    vb.sendData();

    return Mesh.init(vb_handle, vb.vertices.items);
}

fn createCubeMesh(rp: *ResourcePool) Allocator.Error!Mesh {
    const vertices = [_]Vertex{
        Vertex.init(Vec3.init(0.5, 0.5, 0.5), Vec3.init(0, 0, 1), Vec2.init(1, 1)),
        Vertex.init(Vec3.init(0.5, -0.5, 0.5), Vec3.init(0, 0, 1), Vec2.init(1, 0)),
        Vertex.init(Vec3.init(-0.5, -0.5, 0.5), Vec3.init(0, 0, 1), Vec2.init(0, 0)),
        Vertex.init(Vec3.init(-0.5, 0.5, 0.5), Vec3.init(0, 0, 1), Vec2.init(0, 1)),

        Vertex.init(Vec3.init(-0.5, 0.5, -0.5), Vec3.init(0, 0, -1), Vec2.init(1, 1)),
        Vertex.init(Vec3.init(-0.5, -0.5, -0.5), Vec3.init(0, 0, -1), Vec2.init(1, 0)),
        Vertex.init(Vec3.init(0.5, -0.5, -0.5), Vec3.init(0, 0, -1), Vec2.init(0, 0)),
        Vertex.init(Vec3.init(0.5, 0.5, -0.5), Vec3.init(0, 0, -1), Vec2.init(0, 1)),

        Vertex.init(Vec3.init(0.5, 0.5, -0.5), Vec3.init(1, 0, 0), Vec2.init(1, 1)),
        Vertex.init(Vec3.init(0.5, -0.5, -0.5), Vec3.init(1, 0, 0), Vec2.init(1, 0)),
        Vertex.init(Vec3.init(0.5, -0.5, 0.5), Vec3.init(1, 0, 0), Vec2.init(0, 0)),
        Vertex.init(Vec3.init(0.5, 0.5, 0.5), Vec3.init(1, 0, 0), Vec2.init(0, 1)),

        Vertex.init(Vec3.init(-0.5, 0.5, 0.5), Vec3.init(-1, 0, 0), Vec2.init(1, 1)),
        Vertex.init(Vec3.init(-0.5, -0.5, 0.5), Vec3.init(-1, 0, 0), Vec2.init(1, 0)),
        Vertex.init(Vec3.init(-0.5, -0.5, -0.5), Vec3.init(-1, 0, 0), Vec2.init(0, 0)),
        Vertex.init(Vec3.init(-0.5, 0.5, -0.5), Vec3.init(-1, 0, 0), Vec2.init(0, 1)),

        Vertex.init(Vec3.init(0.5, 0.5, -0.5), Vec3.init(0, 1, 0), Vec2.init(1, 1)),
        Vertex.init(Vec3.init(0.5, 0.5, 0.5), Vec3.init(0, 1, 0), Vec2.init(1, 0)),
        Vertex.init(Vec3.init(-0.5, 0.5, 0.5), Vec3.init(0, 1, 0), Vec2.init(0, 0)),
        Vertex.init(Vec3.init(-0.5, 0.5, -0.5), Vec3.init(0, 1, 0), Vec2.init(0, 1)),

        Vertex.init(Vec3.init(0.5, -0.5, 0.5), Vec3.init(0, -1, 0), Vec2.init(1, 1)),
        Vertex.init(Vec3.init(0.5, -0.5, -0.5), Vec3.init(0, -1, 0), Vec2.init(1, 0)),
        Vertex.init(Vec3.init(-0.5, -0.5, -0.5), Vec3.init(0, -1, 0), Vec2.init(0, 0)),
        Vertex.init(Vec3.init(-0.5, -0.5, 0.5), Vec3.init(0, -1, 0), Vec2.init(0, 1)),
    };

    const indices = [_]u32{
        0,  1,  3,
        1,  2,  3,

        4,  5,  7,
        5,  6,  7,

        8,  9,  11,
        9,  10, 11,

        12, 13, 15,
        13, 14, 15,

        16, 17, 19,
        17, 18, 19,

        20, 21, 23,
        21, 22, 23,
    };

    const vb, const vb_handle = try rp.createVertexBuffer();
    vb.* = .init(rp.alloc);
    try vb.vertices.appendSlice(vb.alloc, &vertices);
    try vb.indices.appendSlice(vb.alloc, &indices);
    vb.sendData();

    return Mesh.init(vb_handle, vb.vertices.items);
}

const fs = engine.fs;

pub fn createArrowMesh(rp: *ResourcePool) Model.LoadMeshError!Mesh {
    return Model.loadMesh(rp.alloc, rp, fs.modelPath("arrow.glb"));
}

pub fn setDrawMode(self: *Shapes, mode: Mesh.DrawMode) void {
    self.cube.draw_mode = mode;
    self.rect.draw_mode = mode;
    self.arrow.draw_mode = mode;
}
