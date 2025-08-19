const std = @import("std");
const engine = @import("engine.zig");
const gl = @import("gl");
const c = @cImport({
    @cInclude("stb_image.h");
});
const Texture = engine.Texture;
const debug = engine.debug;
const log = debug.log;
const assert = debug.assert;

const Skybox = @This();

handle: c_uint = 0,
_loaded: bool = false,
texture_paths: [6][]const u8,

pub fn init(paths: [6][]const u8) Skybox {
    return loadSkybox(paths);
}

pub fn deinit(self: *Skybox) void {
    self.deleteTextures();
}

fn loadSkybox(paths: [6][]const u8) Skybox {
    var sb = Skybox{ .texture_paths = paths };

    gl.GenTextures(1, @ptrCast(&sb.handle));
    gl.BindTexture(gl.TEXTURE_CUBE_MAP, sb.handle);

    var width: c_int = 0;
    var height: c_int = 0;
    var nr_channels: c_int = 0;
    var data: [*c]u8 = undefined;
    c.stbi_set_flip_vertically_on_load(0);
    for (0..paths.len) |i| {
        data = c.stbi_load(
            @ptrCast(paths[i]),
            @ptrCast(&width),
            @ptrCast(&height),
            @ptrCast(&nr_channels),
            0,
        );
        if (data == 0) {
            const msg = c.stbi_failure_reason();
            log.info("msg: {s}", .{msg});
        }
        assert(data != 0, "bad file read at {s}", .{paths[i]});
        defer c.stbi_image_free(data);

        gl.TexImage2D(
            gl.TEXTURE_CUBE_MAP_POSITIVE_X + @as(c_uint, @intCast(i)),
            0,
            gl.RGB,
            width,
            height,
            0,
            gl.RGB,
            gl.UNSIGNED_BYTE,
            data,
        );
    }

    gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    // z-axis
    gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_R, gl.CLAMP_TO_EDGE);

    sb._loaded = true;
    return sb;
}

fn deleteTextures(self: *Skybox) void {
    gl.DeleteTextures(1, @ptrCast(&self.handle));
    self._loaded = false;
}

pub fn loaded(self: *const Skybox) bool {
    return self._loaded;
}
