const std = @import("std");
const engine = @import("engine.zig");
const Color = engine.Color;
const Texture = engine.Texture;
const ArrayList = std.ArrayList;
const Shader = engine.Shader;
const Allocator = std.mem.Allocator;

const Material = @This();

color: Color = Color.white,
diffuse_textures: ArrayList(Texture),
specular_textures: ArrayList(Texture),
shader: ?*Shader = null,
shininess: f32 = 1000.0,

pub fn init(allocator: Allocator) Material {
    return Material{
        .diffuse_textures = ArrayList(Texture).init(allocator),
        .specular_textures = ArrayList(Texture).init(allocator),
    };
}

/// doesn't deallocate texture gpu memory
pub fn deinit(self: *Material) void {
    self.diffuse_textures.deinit();
    self.specular_textures.deinit();
}

pub fn createDiffuseTexture(self: *Material, path: []const u8) void {
    self.diffuse_textures.append(
        Texture.init(path),
    ) catch unreachable;
}

pub fn createSpecularTexture(self: *Material, path: []const u8) *Texture {
    return self.specular_textures.append(
        Texture.init(path),
    ) catch unreachable;
}

pub fn hasDiffuseTextures(self: *const Material) bool {
    return self.diffuse_textures.items.len > 0;
}

pub fn hasSpecularTextures(self: *const Material) bool {
    return self.specular_textures.items.len > 0;
}

pub fn diffuseTextureCount(self: *const Material) usize {
    return self.diffuse_textures.items.len;
}

pub fn specularTextureCount(self: *const Material) usize {
    return self.specular_textures.items.len;
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
