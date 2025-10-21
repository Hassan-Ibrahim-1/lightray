//! Represents a VBO on the GPU

const std = @import("std");
const engine = @import("../engine.zig");
const gl = engine.gl;
const math = engine.math;
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const Mat4 = math.Mat4;
const Mat3 = math.Mat3;
const cast = engine.cast;
const log = engine.debug.log.scoped(.Buffer);

const Buffer = @This();

handle: c_uint,
/// The size of each individual 'value' in the buffer
item_size: usize,
capacity: isize,

pub const Handle = enum(usize) {
    _,
    pub const zero: Handle = @enumFromInt(0);
};
/// where the last attribute for `Vertex` ends
pub const vertex_attribute_end = 2;

/// T must be a struct.
/// Assumes that a VAO is bound.
pub fn init(
    T: type,
    instanced: bool,
    attr_count: u4,
) struct { Buffer, u4 } {
    var handle: c_uint = undefined;
    gl.GenBuffers(1, @ptrCast(&handle));
    gl.BindBuffer(gl.ARRAY_BUFFER, handle);
    defer gl.BindBuffer(gl.ARRAY_BUFFER, 0);

    const attrs = setupAttributePointers(T, attr_count);
    if (instanced) {
        for (attr_count..attrs + 1) |i| {
            gl.VertexAttribDivisor(@intCast(i), 1);
        }
    }

    return .{
        .{
            .handle = handle,
            .capacity = 0,
            .item_size = @sizeOf(T),
        },
        attrs,
    };
}

pub fn initTypeless(size: usize) Buffer {
    var handle: c_uint = undefined;
    gl.GenBuffers(1, @ptrCast(&handle));

    return .{
        .handle = handle,
        .capacity = 0,
        .item_size = size,
    };
}

fn setupAttributePointers(T: type, attr_count: u4) u4 {
    var attrs = attr_count;

    const stride = @sizeOf(T);
    if (isRawType(T)) {
        return setVertexAttribute(T, attrs, stride, 0);
    }

    const ti = @typeInfo(T).@"struct";
    log.info("stride: {}", .{stride});
    inline for (ti.fields) |field| {
        const offset = @offsetOf(T, field.name);
        log.info(
            "{s}: {s} = {}, {}",
            .{ field.name, @typeName(field.type), attrs, offset },
        );
        attrs = setVertexAttribute(field.type, attrs, stride, offset);
    }
    return attrs;
}

fn setVertexAttribute(
    T: type,
    attr: c_uint,
    stride: c_int,
    offset: usize,
) u4 {
    switch (T) {
        bool => {
            gl.VertexAttribPointer(attr, 1, gl.UNSIGNED_BYTE, gl.FALSE, stride, offset);
            gl.EnableVertexAttribArray(attr);
            return @intCast(attr + 1);
        },
        f32 => {
            gl.VertexAttribPointer(attr, 1, gl.FLOAT, gl.FALSE, stride, offset);
            gl.EnableVertexAttribArray(attr);
            return @intCast(attr + 1);
        },
        i32 => {
            gl.VertexAttribIPointer(attr, 1, gl.INT, gl.FALSE, stride, offset);
            gl.EnableVertexAttribArray(attr);
            return @intCast(attr + 1);
        },
        u32 => {
            gl.VertexAttribPointer(attr, 1, gl.UNSIGNED_INT, gl.FALSE, stride, offset);
            gl.EnableVertexAttribArray(attr);
            return @intCast(attr + 1);
        },
        Vec2 => {
            gl.VertexAttribPointer(attr, 2, gl.FLOAT, gl.FALSE, stride, offset);
            gl.EnableVertexAttribArray(attr);
            return @intCast(attr + 1);
        },
        Vec3 => {
            gl.VertexAttribPointer(attr, 3, gl.FLOAT, gl.FALSE, stride, offset);
            gl.EnableVertexAttribArray(attr);
            return @intCast(attr + 1);
        },
        Vec4 => {
            gl.VertexAttribPointer(attr, 4, gl.FLOAT, gl.FALSE, stride, offset);
            gl.EnableVertexAttribArray(attr);
            return @intCast(attr + 1);
        },
        Mat3 => {
            const v4s = @sizeOf(Vec4);
            for (0..3) |i| {
                const a = attr + cast.as(c_uint, i);
                gl.VertexAttribPointer(a, 3, gl.FLOAT, gl.FALSE, stride, offset + i * v4s);
                gl.EnableVertexAttribArray(a);
            }
            return @intCast(attr + 3);
        },
        Mat4 => {
            const v4s = @sizeOf(Vec4);
            for (0..4) |i| {
                const a = attr + cast.as(c_uint, i);
                gl.VertexAttribPointer(a, 4, gl.FLOAT, gl.FALSE, stride, offset + i * v4s);
                gl.EnableVertexAttribArray(a);
            }
            return @intCast(attr + 4);
        },
        else => {
            @compileError(
                std.fmt.comptimePrint(
                    "Unsupported type {s}",
                    .{@typeName(T)},
                ),
            );
        },
    }
}

inline fn isRawType(T: type) bool {
    return switch (T) {
        bool, f32, i32, u32, Vec2, Vec3, Vec4, Mat3, Mat4 => true,
        else => false,
    };
}

pub fn bind(self: *Buffer) void {
    gl.BindBuffer(gl.ARRAY_BUFFER, self.handle);
}

pub fn unbind(_: *Buffer) void {
    gl.BindBuffer(gl.ARRAY_BUFFER, 0);
}

/// `self` must be bound
/// returns next available attribute
pub fn setAttribute(
    self: *Buffer,
    T: type,
    attr: u4,
    offset: usize,
    instanced: bool,
) u4 {
    const stride = self.item_size;
    const next_attr = setVertexAttribute(
        T,
        @intCast(attr),
        @intCast(stride),
        @intCast(offset),
    );
    if (instanced) {
        for (attr..next_attr) |i| {
            gl.VertexAttribDivisor(@intCast(i), 1);
        }
    }
    return next_attr;
}

pub fn deinit(self: *Buffer) void {
    gl.DeleteBuffers(1, @ptrCast(&self.handle));
    self.* = undefined;
}

pub fn setData(self: *Buffer, T: type, data: []const T) void {
    return self.setDataWithOffset(T, data, 0);
}

/// assumes buffer is bound
pub fn setDataWithOffset(
    self: *Buffer,
    T: type,
    data: []const T,
    offset: isize,
) void {
    std.debug.assert(data.len > 0);
    std.debug.assert((data.len + cast.as(usize, offset)) <= self.capacity);

    gl.BufferSubData(
        gl.ARRAY_BUFFER,
        @intCast(offset),
        @intCast(self.capacity),
        @ptrCast(data),
    );
}

pub const Usage = enum(c_uint) {
    static_draw = gl.STATIC_DRAW,
    dynamic_draw = gl.DYNAMIC_DRAW,

    pub fn value(self: Usage) c_uint {
        return @intFromEnum(self);
    }
};

/// Deletes the existing data and creates new uninitialized buffers
/// changes the vbo so that it has @sizeOf(T) * cap items
/// assumes buffer is bound
pub fn resize(self: *Buffer, T: type, cap: usize, usage: Usage) void {
    self.capacity = @intCast(@sizeOf(T) * cap);
    resizeBuf(self.capacity, usage);
}

pub fn resizeBytes(self: *Buffer, bytes: usize, usage: Usage) void {
    self.capacity = @intCast(bytes);
    resizeBuf(self.capacity, usage);
}

fn resizeBuf(size: isize, usage: Usage) void {
    gl.BufferData(gl.ARRAY_BUFFER, size, null, usage.value());
}

pub fn clear(self: *Buffer) void {
    self.resizeBytes(0, .dynamic_draw);
}
