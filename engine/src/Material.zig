const std = @import("std");
const engine = @import("engine.zig");
const res = engine.res;
const Color = engine.Color;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const Material = @This();

color: Color = .white,
diffuse_textures: ArrayList(res.Texture.Handle),
specular_textures: ArrayList(res.Texture.Handle),
shader: ?res.Shader.Handle = null,
shininess: f32 = 1000.0,

pub fn init() Material {
    return Material{
        .diffuse_textures = .empty,
        .specular_textures = .empty,
    };
}

/// doesn't deallocate texture gpu memory
pub fn deinit(self: *Material, alloc: Allocator) void {
    self.diffuse_textures.deinit(alloc);
    self.specular_textures.deinit(alloc);
}

pub fn jsonStringify(
    self: *const Material,
    jw: anytype,
) !void {
    try jw.beginObject();
    defer jw.endObject() catch unreachable;

    try jw.objectField("color");
    try jw.write(self.color);
    try jw.objectField("shininess");
    try jw.write(self.shininess);
}
