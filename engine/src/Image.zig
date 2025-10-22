const std = @import("std");
const engine = @import("engine.zig");
const gl = engine.gl;
const trait = engine.trait;
const log = engine.debug.log.scoped(.Image);

const c = engine.stb;

const Image = @This();

pub const Format = enum(u32) {
    red = gl.RED,
    rgb = gl.RGB,
    rgba = gl.RGBA,

    pub fn as(self: Format, T: type) T {
        comptime std.debug.assert(trait.isInt(T));
        return @intCast(@intFromEnum(self));
    }

    pub fn channels(self: Format) u32 {
        return switch (self) {
            .rgba => 4,
            .rgb => 3,
            .red => 1,
        };
    }
};

width: u32,
height: u32,
data: []u8,
format: Format,

pub const Error = error{
    LoadError,
};

const cast = engine.cast;

pub fn fromFile(path: []const u8) Error!Image {
    var width: c_int = 0;
    var height: c_int = 0;
    var channels: c_int = 0;
    const data = c.stbi_load(
        path.ptr,
        @ptrCast(&width),
        @ptrCast(&height),
        @ptrCast(&channels),
        0,
    );
    if (data == 0) {
        const failure_reason = c.stbi_failure_reason();
        const end = std.mem.indexOfSentinel(u8, 0, failure_reason);
        log.err(
            "Bad image load at path: {s}. reason: {s}",
            .{ path, failure_reason[0..end] },
        );
        return Error.LoadError;
    }

    // TODO: gamma correction
    const format: Format = switch (channels) {
        1 => .red,
        3 => .rgb,
        4 => .rgba,
        else => fmt: {
            engine.debug.log.warn(
                "Unsupported color channel count {} for path {s}\n defaulting to RGB",
                .{ channels, path },
            );
            break :fmt .rgb;
        },
    };

    return .{
        .format = format,
        .data = data[0..cast.as(usize, width * height)],
        .width = @intCast(width),
        .height = @intCast(height),
    };
}

/// Only call this if the image was created from `Image.fromFile`
pub fn freeFromFile(self: *Image) void {
    c.stbi_image_free(self.data.ptr);
    self.* = undefined;
}
