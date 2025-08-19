const engine = @import("../engine.zig");
const Mesh = engine.Mesh;
const std = @import("std");
const ArrayList = std.ArrayList;
const Texture = engine.Texture;
const Material = engine.Material;
const Allocator = std.mem.Allocator;
const Model = engine.Model;

const RenderItem = @This();

allocator: Allocator,
meshes: ArrayList(Mesh),
material: Material,
hidden: bool,

pub fn init(allocator: Allocator) RenderItem {
    return RenderItem{
        .allocator = allocator,
        .material = .init(allocator),
        .meshes = .init(allocator),
        .hidden = false,
    };
}

pub fn deinit(self: *RenderItem) void {
    for (self.meshes.items) |*mesh| {
        mesh.deinit();
    }
    self.meshes.deinit();
    self.material.deinit();
}

pub fn createMesh(self: *RenderItem) *Mesh {
    self.meshes.append(Mesh.init(self.allocator)) catch unreachable;
    return &self.meshes.items[self.meshes.items.len - 1];
}

pub fn meshCount(self: *RenderItem) usize {
    return self.meshes.items.len;
}

/// This function expects that the model's lifetime is greater than or equal to this render item's
pub fn loadModelData(
    self: *RenderItem,
    model: *const Model,
) void {
    for (model.meshes.items) |*mesh| {
        self.meshes.append(
            Mesh.fromVao(
                self.allocator,
                mesh.vertex_buffer.vao.?,
            ),
        ) catch unreachable;
        // assign dc to new mesh
        self.meshes.items[self.meshes.items.len - 1].draw_command = mesh.draw_command;
        // self.meshes.items[self.meshCount() - 1].draw_command.?.type = .draw_arrays;
    }
    for (model.textures.items) |*tex| {
        // engine.debug.log.info("tex path: {s}", .{tex.path});
        if (tex.loaded()) {
            self.material.diffuse_textures.append(
                Texture.fromTexture(tex),
            ) catch unreachable;
        }
    }
}

pub fn jsonStringify(
    self: *const RenderItem,
    jw: anytype,
) !void {
    try jw.beginObject();
    defer jw.endObject() catch unreachable;

    try jw.objectField("material");
    try jw.write(self.material);
    try jw.objectField("hidden");
    try jw.write(self.hidden);
}
