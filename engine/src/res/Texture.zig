const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const engine = @import("../engine.zig");
const gl = engine.gl;
const math = engine.math;
const assert = engine.debug.assert;
const log = engine.debug.log;
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vertex = engine.Vertex;
const cast = engine.cast;
const trait = engine.trait;
const Image = engine.Image;

const Texture = @This();

pub const Handle = enum(usize) {
    _,
    pub const zero: Handle = @enumFromInt(0);
};

handle: c_uint,
width: u32,
height: u32,
nr_channels: u32,
loaded: bool,
path: []const u8,

pub const Filter = enum(u32) {
    nearest = gl.NEAREST,
    linear = gl.LINEAR,

    pub fn as(self: Filter, T: type) T {
        comptime std.debug.assert(trait.isInt(T));
        return @intCast(@intFromEnum(self));
    }
};

pub fn init(path: []const u8) Image.Error!Texture {
    return loadTexture(path);
}

pub fn deinit(self: *Texture) void {
    assert(self.loaded, "Tried to deinit a texture that isn't loaded", .{});
    gl.DeleteTextures(1, @ptrCast(&self.handle));
    self.loaded = false;
    self.* = undefined;
}

fn loadTexture(path: []const u8) Image.Error!Texture {
    var handle: c_uint = undefined;
    gl.GenTextures(1, @ptrCast(&handle));
    var image = try Image.fromFile(path);
    defer image.freeFromFile();

    gl.BindTexture(gl.TEXTURE_2D, handle);

    gl.TexImage2D(
        gl.TEXTURE_2D,
        0,
        @intCast(image.format.as(c_int)),
        @intCast(image.width),
        @intCast(image.height),
        0,
        @intCast(image.format.as(c_int)),
        gl.UNSIGNED_BYTE,
        @ptrCast(image.data.ptr),
    );
    gl.GenerateMipmap(gl.TEXTURE_2D);
    const channels = image.format.channels();
    defaultTextureSampling(@intCast(channels));

    return .{
        .handle = handle,
        .width = image.width,
        .height = image.height,
        .nr_channels = channels,
        .loaded = true,
        .path = path,
    };
}

fn defaultTextureSampling(nr_channels: i32) void {
    if (nr_channels == 4) {
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    } else {
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
    }
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
}

pub fn bind(self: *const Texture) void {
    gl.BindTexture(gl.TEXTURE_2D, self.handle);
}

pub fn bindSlot(self: *const Texture, id: usize) void {
    gl.ActiveTexture(gl.TEXTURE0 + cast.as(c_uint, id));
    gl.BindTexture(gl.TEXTURE_2D, self.handle);
}

pub fn unbind(self: *const Texture) void {
    _ = self; // autofix
    gl.BindTexture(gl.TEXTURE_2D, 0);
}
