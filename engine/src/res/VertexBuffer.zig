const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const gl = @import("gl");

const engine = @import("../engine.zig");
const math = engine.math;
const log = engine.debug.log;
const Vertex = engine.Vertex;
const assert = engine.debug.assert;
const res = engine.res;

alloc: Allocator,

vao: ?c_uint,
vbo: ?c_uint,
ebo: ?c_uint,

vertices: ArrayList(Vertex),
indices: ArrayList(u32),

const VertexBuffer = @This();

pub const Handle = enum(usize) {
    _,
    pub const zero: Handle = @enumFromInt(0);
};

pub fn init(allocator: Allocator) VertexBuffer {
    return VertexBuffer{
        .alloc = allocator,

        .vao = null,
        .vbo = null,
        .ebo = null,

        .vertices = .empty,
        .indices = .empty,
    };
}

pub fn deinit(self: *VertexBuffer) void {
    self.vertices.deinit(self.alloc);
    self.indices.deinit(self.alloc);
    gl.DeleteVertexArrays(1, @ptrCast(&self.vao.?));
    if (self.vbo) |*vbo| {
        gl.DeleteBuffers(1, @ptrCast(vbo));
    }
    if (self.ebo) |*ebo| {
        gl.DeleteBuffers(1, @ptrCast(ebo));
    }
    self.* = undefined;
}

pub fn setVao(self: *VertexBuffer, vao: c_uint) void {
    assert(self.vao == null, "Already have a set vao", .{});
    self.vao = vao;
}

/// only binds the vao
pub fn bind(self: *const VertexBuffer) void {
    assert(self.vao != null, "Vao is null", .{});
    gl.BindVertexArray(self.vao.?);
    if (self.ebo) |ebo| {
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo);
    }
}

pub fn unbind(_: *const VertexBuffer) void {
    gl.BindVertexArray(0);
}

pub fn sendData(self: *VertexBuffer) void {
    self.sendVertexData();
    self.sendIndexData();
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
    setupVertexAttributes();
}

/// Assumes a vao is bound
fn setupVertexAttributes() void {
    setVertexAttribPointer(0, 3, @sizeOf(Vertex), @offsetOf(Vertex, "position"));
    setVertexAttribPointer(1, 3, @sizeOf(Vertex), @offsetOf(Vertex, "normal"));
    setVertexAttribPointer(2, 2, @sizeOf(Vertex), @offsetOf(Vertex, "uv"));
}

fn setVertexAttribPointer(
    attr: u4,
    size: usize,
    stride: usize,
    offset: usize,
) void {
    gl.VertexAttribPointer(
        attr,
        @intCast(size),
        gl.FLOAT,
        gl.FALSE,
        @intCast(stride),
        @intCast(offset),
    );
    gl.EnableVertexAttribArray(attr);
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
        @intCast(self.indices.items.len * @sizeOf(gl.uint)),
        @ptrCast(self.indices.items),
        gl.STATIC_DRAW,
    );
}

/// Doesn't create any new buffers, deletes the old vao and replaces it with a
/// new one. The new vao will have the vbo and ebo already setup and nothing else.
/// The attributes of the old vao are removed entirely.
pub fn reloadVao(self: *VertexBuffer) void {
    gl.DeleteVertexArrays(1, @ptrCast(&self.vao.?));

    self.vao = 0;
    gl.GenVertexArrays(1, @ptrCast(&self.vao.?));
    gl.BindVertexArray(self.vao.?);
    defer gl.BindVertexArray(0);

    if (self.vbo) |vbo| {
        gl.BindBuffer(gl.ARRAY_BUFFER, vbo);
        setupVertexAttributes();
    }
    defer if (self.vbo != null) {
        gl.BindBuffer(gl.ARRAY_BUFFER, 0);
    };

    if (self.ebo) |ebo| {
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo);
    }
}
