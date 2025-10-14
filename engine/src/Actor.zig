const std = @import("std");
const Allocator = std.mem.Allocator;
const engine = @import("engine.zig");
const Mesh = engine.Mesh;
const RenderItem = engine.RenderItem;
const Transform = engine.Transform;

const Actor = @This();

transform: Transform = .{},
render_item: RenderItem,
/// don't mutate this yourself
id: usize,

pub fn init(allocator: Allocator, id: usize) Actor {
    return Actor{
        .render_item = RenderItem.init(allocator),
        .id = id,
    };
}

pub fn deinit(self: *Actor) void {
    self.render_item.deinit();
}

pub fn jsonStringify(
    self: *const Actor,
    jw: anytype,
) !void {
    try jw.beginObject();
    defer jw.endObject() catch unreachable;

    const scene = engine.scene();
    const name = scene.getActorName(self).?;

    try jw.objectField("name");
    try jw.write(name);

    try jw.objectField("render_item");
    try jw.write(self.render_item);

    try jw.objectField("transform");
    try jw.write(self.transform);
}
