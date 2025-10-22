const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const engine = @import("../engine.zig");
const res = engine.res;
const Texture = engine.Texture;
const Material = engine.Material;
const Model = engine.Model;
const log = engine.debug.log.scoped(.RenderItem);
const Mesh = res.Mesh;

const RenderItem = @This();

alloc: Allocator,
meshes: ArrayList(Mesh),
material: Material,
hidden: bool,

pub fn init(alloc: Allocator) RenderItem {
    return RenderItem{
        .alloc = alloc,
        .material = .init(),
        .meshes = .empty,
        .hidden = false,
    };
}

pub fn deinit(self: *RenderItem) void {
    self.meshes.deinit(self.alloc);
    self.material.deinit(self.alloc);
}

pub fn addMesh(
    self: *RenderItem,
    mesh: Mesh,
) Allocator.Error!void {
    try self.meshes.append(self.alloc, mesh);
}

pub fn meshCount(self: *RenderItem) usize {
    return self.meshes.items.len;
}

/// This function expects that the model's lifetime is greater than or equal to this render item's
pub fn loadModelData(
    self: *RenderItem,
    model: *const res.Model,
) Allocator.Error!void {
    try self.meshes.appendSlice(self.alloc, model.meshes.items);
    // TODO: figure out difference between diffuse and specular textures
    try self.material.diffuse_textures.appendSlice(
        self.alloc,
        model.textures.items,
    );
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
