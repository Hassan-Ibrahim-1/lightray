const std = @import("std");
const gl = @import("gl");
const engine = @import("engine.zig");
const math = engine.math;
const assert = engine.debug.assert;
const log = engine.debug.log;
const Size = engine.utils.Size;
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const ArrayList = std.ArrayList;
const Vertex = @import("vertex.zig").Vertex;
const Allocator = std.mem.Allocator;

const ComputeTexture = @This();

handle: c_uint,
width: u32,
height: u32,
nr_channels: u32,
_loaded: bool = false,
_owns_data: bool = true,
shader_slot: u32,

pub fn init(
    size: Size,
    nr_channels: u32,
    shader_slot: u32,
) ComputeTexture {
    var texture: ComputeTexture = undefined;
    texture.shader_slot = shader_slot;
    texture.nr_channels = nr_channels;
    texture.width = size.width;
    texture.height = size.height;

    gl.CreateTextures(gl.TEXTURE_2D, 1, @ptrCast(&texture.handle));

    const format: c_uint = switch (texture.nr_channels) {
        1 => gl.RED,
        3 => gl.RGB32F,
        4 => gl.RGBA32F,
        else => fmt: {
            log.err(
                "Unsupported color channel count {} defaulting to RGB32F",
                .{texture.nr_channels},
            );
            break :fmt gl.RGB32F;
        },
    };

    if (texture.nr_channels == 4) {
        gl.TextureParameteri(texture.handle, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.TextureParameteri(texture.handle, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    } else {
        gl.TextureParameteri(texture.handle, gl.TEXTURE_WRAP_S, gl.REPEAT);
        gl.TextureParameteri(texture.handle, gl.TEXTURE_WRAP_T, gl.REPEAT);
    }
    gl.TextureParameteri(texture.handle, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.TextureParameteri(texture.handle, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

    engine.debug.checkGlError();

    gl.TextureStorage2D(
        texture.handle,
        1,
        format,
        @intCast(texture.width),
        @intCast(texture.height),
    );

    engine.debug.checkGlError();

    gl.BindImageTexture(0, texture.handle, 0, gl.FALSE, 0, gl.WRITE_ONLY, format);

    engine.debug.checkGlError();

    texture._loaded = true;
    return texture;
}

/// deinit does nothing when you create a texture using this
/// the parent texture must be alive for this to function
pub fn fromTexture(tex: *const ComputeTexture) ComputeTexture {
    assert(tex._loaded, "other texture must be loaded", .{});
    return ComputeTexture{
        .handle = tex.handle,
        .shader_slot = tex.shader_slot,
        .width = tex.width,
        .height = tex.height,
        .nr_channels = tex.nr_channels,
        ._loaded = true,
        ._owns_data = false,
    };
}

pub fn deinit(self: *ComputeTexture) void {
    assert(self._loaded, "Tried to deinit a texture that isn't loaded", .{});
    if (!self._owns_data) {
        log.err(
            "Tried to deinit a texture that doesn't own its data",
        );
        return;
    }
    gl.DeleteTextures(1, @ptrCast(&self.handle));
    self._loaded = false;
}

pub fn bind(self: *ComputeTexture) void {
    gl.BindTextureUnit(self.shader_slot, self.handle);
}

pub fn loaded(self: *ComputeTexture) bool {
    return self._loaded;
}
