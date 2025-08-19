const std = @import("std");
const gl = @import("gl");
const engine = @import("engine.zig");
const math = engine.math;
const log = engine.debug.log;
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const ArrayList = std.ArrayList;
const Vertex = engine.Vertex;
const Allocator = std.mem.Allocator;
const assert = engine.debug.assert;

const VertexBuffer = @This();

allocator: Allocator,
vao: ?c_uint,
vbo: ?c_uint,
ebo: ?c_uint,
vertices: ArrayList(Vertex),
indices: ArrayList(u32),

pub fn init(allocator: Allocator) VertexBuffer {
    return VertexBuffer{
        .allocator = allocator,
        .vao = null,
        .vbo = null,
        .ebo = null,
        .vertices = ArrayList(Vertex).init(allocator),
        .indices = ArrayList(u32).init(allocator),
    };
}

pub fn fromVao(allocator: Allocator, vao: c_uint) VertexBuffer {
    return VertexBuffer{
        .allocator = allocator,
        .vao = vao,
        .vbo = null,
        .ebo = null,
        .vertices = ArrayList(Vertex).init(allocator),
        .indices = ArrayList(u32).init(allocator),
    };
}

pub fn deinit(self: *VertexBuffer) void {
    self.vertices.deinit();
    self.indices.deinit();
    gl.DeleteVertexArrays(1, @ptrCast(&self.vao));
    if (self.vbo) |*vbo| {
        gl.DeleteBuffers(1, @ptrCast(vbo));
    }
    if (self.ebo) |*ebo| {
        gl.DeleteBuffers(1, @ptrCast(ebo));
    }
}

pub fn setVao(self: *VertexBuffer, vao: c_uint) void {
    assert(self.vao == null, "Already have a set vao", .{});
    self.vao = vao;
}

/// only binds the vao
pub fn bind(self: *const VertexBuffer) void {
    assert(self.vao != null, "Vao is null", .{});
    gl.BindVertexArray(self.vao.?);
}

pub fn unbind(self: *const VertexBuffer) void {
    _ = self;
    gl.BindVertexArray(0);
}

/// reallocates the vbo
/// position must be at 0
/// normal at 1
/// tex coords at 2
/// does nothing if vertices are empty
pub fn sendVertexData(self: *VertexBuffer) void {
    if (self.vertices.items.len == 0) return;

    if (self.vao == null) {
        self.vao = 0;
        gl.GenVertexArrays(1, @ptrCast(&self.vao.?));
    }
    if (self.vbo) |*vbo| {
        gl.DeleteBuffers(1, @ptrCast(vbo));
    }
    self.vbo = 0;

    const vao = self.vao.?;
    gl.BindVertexArray(vao);
    defer gl.BindVertexArray(0);

    gl.GenBuffers(1, @ptrCast(&self.vbo.?));
    gl.BindBuffer(gl.ARRAY_BUFFER, self.vbo.?);
    gl.BufferData(
        gl.ARRAY_BUFFER,
        @intCast(self.vertices.items.len * @sizeOf(Vertex)),
        @ptrCast(self.vertices.items),
        gl.STATIC_DRAW,
    );

    gl.EnableVertexAttribArray(0);
    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, @sizeOf(Vertex), 0);

    gl.VertexAttribPointer(
        1,
        3,
        gl.FLOAT,
        gl.FALSE,
        @sizeOf(Vertex),
        @offsetOf(Vertex, "normal"),
    );
    gl.EnableVertexAttribArray(1);

    gl.VertexAttribPointer(
        2,
        2,
        gl.FLOAT,
        gl.FALSE,
        @sizeOf(Vertex),
        @offsetOf(Vertex, "uv"),
    );
    gl.EnableVertexAttribArray(2);
}

/// reallocates the ebo
/// does nothing if indices is empty
pub fn sendIndexData(self: *VertexBuffer) void {
    if (self.indices.items.len == 0) return;

    if (self.vao == null) {
        self.vao = 0;
        gl.GenVertexArrays(1, @ptrCast(&self.vao.?));
    }
    if (self.ebo) |*ebo| {
        gl.DeleteBuffers(1, @ptrCast(ebo));
    }

    self.ebo = 0;
    gl.GenBuffers(1, @ptrCast(&self.ebo.?));

    gl.BindVertexArray(self.vao.?);
    defer gl.BindVertexArray(0);

    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, self.ebo.?);
    gl.BufferData(
        gl.ELEMENT_ARRAY_BUFFER,
        @intCast(self.indices.items.len * @sizeOf(u32)),
        @ptrCast(self.indices.items),
        gl.STATIC_DRAW,
    );
}
