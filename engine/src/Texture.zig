const std = @import("std");
const gl = @import("gl");
const engine = @import("engine.zig");
const math = engine.math;
const assert = engine.debug.assert;
const log = engine.debug.log;
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const ArrayList = std.ArrayList;
const Vertex = @import("vertex.zig").Vertex;
const Allocator = std.mem.Allocator;
const c = @cImport({
    @cInclude("stb_image.h");
});

const Texture = @This();

handle: c_uint,
width: i32,
height: i32,
nr_channels: i32,
_loaded: bool = false,
path: []const u8,
_owns_data: bool = true,

pub fn init(path: []const u8) Texture {
    c.stbi_set_flip_vertically_on_load(1);
    return loadTexture(path);
}

/// deinit does nothing when you create a texture using this
/// the parent texture must be alive for this to function
pub fn fromTexture(tex: *const Texture) Texture {
    assert(tex._loaded, "other texture must be loaded", .{});
    return Texture{
        .handle = tex.handle,
        .width = tex.width,
        .height = tex.height,
        .nr_channels = tex.nr_channels,
        .path = tex.path,
        ._loaded = true,
        ._owns_data = false,
    };
}

pub fn deinit(self: *Texture) void {
    assert(self._loaded, "Tried to deinit a texture that isn't loaded", .{});
    if (!self._owns_data) {
        log.err(
            "Tried to deinit a texture that doesn't own its data\npath: {s}",
            .{self.path},
        );
        return;
    }
    gl.DeleteTextures(1, @ptrCast(&self.handle));
    self._loaded = false;
}

fn loadTexture(path: []const u8) Texture {
    var texture: Texture = undefined;
    texture.path = path;

    gl.GenTextures(1, @ptrCast(&texture.handle));
    const data = c.stbi_load(
        @ptrCast(path),
        @ptrCast(&texture.width),
        @ptrCast(&texture.height),
        @ptrCast(&texture.nr_channels),
        0,
    );
    defer c.stbi_image_free(data);
    assert(
        data != 0,
        "Bad texture load at path: {s}",
        .{path},
    );

    // TODO: gamma correction
    const format: c_uint = switch (texture.nr_channels) {
        1 => gl.RED,
        3 => gl.RGB,
        4 => gl.RGBA,
        else => fmt: {
            log.err(
                "Unsupported color channel count {} for path {s}\n defaulting to RGB",
                .{ texture.nr_channels, path },
            );
            break :fmt gl.RGB;
        },
    };
    //
    texture.bind();
    defer texture.unbind();

    gl.TexImage2D(
        gl.TEXTURE_2D,
        0,
        @intCast(format),
        texture.width,
        texture.height,
        0,
        format,
        gl.UNSIGNED_BYTE,
        data,
    );
    gl.GenerateMipmap(gl.TEXTURE_2D);
    defaultTextureSampling(texture.nr_channels);

    texture._loaded = true;
    return texture;
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
    gl.ActiveTexture(gl.TEXTURE0 + @as(c_uint, @intCast(id)));
    gl.BindTexture(gl.TEXTURE_2D, self.handle);
}

pub fn unbind(self: *const Texture) void {
    _ = self; // autofix
    gl.BindTexture(gl.TEXTURE_2D, 0);
}

pub fn loaded(self: *Texture) bool {
    return self._loaded;
}
