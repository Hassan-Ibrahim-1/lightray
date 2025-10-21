const std = @import("std");
const gl = @import("engine.zig").gl;
const trait = @import("engine.zig").trait;

pub const Format = enum(u32) {
    red = gl.RED,
    rgb = gl.RGB,
    rgba = gl.RGBA,

    pub fn as(self: Format, T: type) T {
        comptime std.debug.assert(trait.isInt(T));
        return @intFromEnum(self);
    }
};

width: u32,
height: u32,
data: []u8,
format: Format,
