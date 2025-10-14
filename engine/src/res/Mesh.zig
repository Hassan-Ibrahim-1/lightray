const std = @import("std");
const gl = @import("gl");
const engine = @import("../engine.zig");
const math = engine.math;
const log = engine.debug.log;
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const ArrayList = std.ArrayList;
const Vertex = engine.Vertex;
const Allocator = std.mem.Allocator;
const res = engine.res;
const assert = engine.debug.assert;
const trait = engine.trait;
const Transform = engine.Transform;

const Aabb = math.Aabb;

const Mesh = @This();

vertex_buffer: res.VertexBuffer.Handle,
draw_mode: DrawMode,
aabb: Aabb,

/// `vertices` are meant to be vb.vertices. used to generate the mesh's aabb
pub fn init(vb: res.VertexBuffer.Handle, vertices: []const Vertex) Mesh {
    var mesh = Mesh{
        .vertex_buffer = vb,
        .draw_mode = .triangles,
        .aabb = .zero,
    };
    mesh.generateAabb(vertices);
    return mesh;
}

pub const DrawMode = enum(u8) {
    triangles,
    points,
    lines,
    line_strip,
    line_loop,
    triangle_strip,
    triangle_fan,
    patches,

    pub fn as(self: DrawMode, T: type) T {
        comptime std.debug.assert(trait.isInt(T));

        return switch (self) {
            .triangles => gl.TRIANGLES,
            .triangle_strip => gl.TRIANGLE_STRIP,
            .triangle_fan => gl.TRIANGLE_FAN,
            .lines => gl.LINES,
            .line_strip => gl.LINE_STRIP,
            .line_loop => gl.LINE_LOOP,
            .points => gl.POINTS,
            .patches => gl.PATCHES,
        };
    }
};

pub fn generateAabb(self: *Mesh, vertices: []const Vertex) void {
    if (vertices.len == 0) {
        self.aabb = .zero;
        return;
    }
    self.aabb = .{
        .max = vertices[0].position,
        .min = vertices[0].position,
    };

    for (vertices) |*v| {
        self.aabb.min = Vec3.min(self.aabb.min, v.position);
        self.aabb.max = Vec3.max(self.aabb.max, v.position);
    }
}
