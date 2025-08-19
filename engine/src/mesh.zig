const std = @import("std");
const gl = @import("gl");
const engine = @import("engine.zig");
const math = engine.math;
const log = engine.debug.log;
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const ArrayList = std.ArrayList;
const Vertex = @import("vertex.zig").Vertex;
const Allocator = std.mem.Allocator;
const VertexBuffer = @import("VertexBuffer.zig");
const assert = engine.debug.assert;

pub const DrawCommandType = enum(u8) {
    draw_arrays,
    draw_elements,
    draw_arrays_instanced,
    draw_elements_instanced,
};

pub const DrawCommandMode = enum(u8) {
    triangles,
    points,
    lines,
    line_strip,
    line_loop,
    triangle_strip,
    triangle_fan,
    patches,

    pub fn toInt(self: DrawCommandMode) c_uint {
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

pub const DrawCommand = struct {
    type: DrawCommandType,
    mode: DrawCommandMode,
    vertex_count: usize,
    instance_count: usize,
};

// TODO: add support for custom vaos
pub const Mesh = struct {
    allocator: Allocator,
    vertex_buffer: VertexBuffer,
    draw_command: ?DrawCommand,

    pub fn init(allocator: Allocator) Mesh {
        return Mesh{
            .allocator = allocator,
            .vertex_buffer = VertexBuffer.init(allocator),
            .draw_command = null,
        };
    }

    /// do not call createDrawCommand after this
    /// it won't work. make the draw command yourself
    pub fn fromVao(
        allocator: Allocator,
        vao: c_uint,
    ) Mesh {
        return Mesh{
            .allocator = allocator,
            .vertex_buffer = VertexBuffer.fromVao(allocator, vao),
            .draw_command = null,
        };
    }

    pub fn deinit(self: *Mesh) void {
        self.vertex_buffer.deinit();
    }

    /// sends both index and vertex data to the gpu
    pub fn sendData(self: *Mesh) void {
        self.vertex_buffer.sendVertexData();
        self.vertex_buffer.sendIndexData();
    }

    /// don't call this if you created your mesh using fromVao
    pub fn createDrawCommand(self: *Mesh) void {
        assert(
            self.vertex_buffer.vertices.items.len > 0,
            "Mesh must have vertices to create a draw command",
            .{},
        );

        self.draw_command = undefined;
        var dc = &self.draw_command.?;
        if (self.vertex_buffer.indices.items.len > 0) {
            dc.type = .draw_elements;
        } else {
            dc.type = .draw_arrays;
        }
        dc.mode = .triangles;
        if (self.vertex_buffer.indices.items.len == 0) {
            dc.vertex_count = self
                .vertex_buffer
                .vertices
                .items
                .len;
        } else {
            dc.vertex_count = self
                .vertex_buffer
                .indices
                .items
                .len;
        }
    }

    pub fn buffersCreated(self: *const Mesh) bool {
        return self.draw_command != null;
    }
};
