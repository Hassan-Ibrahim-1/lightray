const std = @import("std");
const engine = @import("engine.zig");
const debug = engine.debug;
const log = debug.log;
const assert = debug.assert;
const Actor = engine.Actor;
const Allocator = std.mem.Allocator;

const SpotLight = engine.SpotLight;
const DirLight = engine.DirLight;
const PointLight = engine.PointLight;
const Skybox = engine.Skybox;
const fs = engine.fs;
const ArenaAllocator = std.heap.ArenaAllocator;

const Scene = @This();

fn HashMap(V: type) type {
    return std.ArrayHashMapUnmanaged([]const u8, V, std.array_hash_map.StringContext, true);
}

const max_point_lights = 8;
const max_spot_lights = 8;
const max_dir_lights = 8;

arena: *ArenaAllocator,
arena_alloc: Allocator,
actors: HashMap(Actor),
point_lights: HashMap(PointLight),
spot_lights: HashMap(SpotLight),
dir_lights: HashMap(DirLight),
skybox: Skybox = undefined,
skybox_hidden: bool = false,

pub fn init(alloc: Allocator) Allocator.Error!Scene {
    const arena = try alloc.create(std.heap.ArenaAllocator);
    arena.* = .init(alloc);
    const arena_alloc = arena.allocator();

    return .{
        .arena = arena,
        .arena_alloc = arena_alloc,
        .actors = try .init(arena_alloc, &.{}, &.{}),
        .point_lights = try .init(arena_alloc, &.{}, &.{}),
        .spot_lights = try .init(arena_alloc, &.{}, &.{}),
        .dir_lights = try .init(arena_alloc, &.{}, &.{}),
    };
}

pub fn deinit(self: *Scene) void {
    const alloc = self.arena.child_allocator;
    self.arena.deinit();
    alloc.destroy(self.arena);
}

/// you don't have to manually call deinit on actor
/// it will automatically get deleted on scene.deinit
pub fn createActor(self: *Scene, name: []const u8) *Actor {
    std.debug.assert(!self.actors.contains(name));
    const alloc = self.arena_alloc;
    const n = alloc.dupe(u8, name) catch unreachable;
    const kv = self.actors.getOrPut(alloc, n) catch unreachable;
    kv.value_ptr.* = Actor.init(
        alloc,
        generateId(),
    );
    return kv.value_ptr;
}

pub fn createPointLight(self: *Scene, name: []const u8) *PointLight {
    assert(
        self.point_lights.count() < max_point_lights,
        "Too many point lights",
        .{},
    );

    const alloc = self.arena_alloc;
    const n = alloc.dupe(u8, name) catch unreachable;
    const kv = self.point_lights.getOrPut(alloc, n) catch unreachable;
    kv.value_ptr.* = .{};
    return kv.value_ptr;
}

pub fn createSpotLight(self: *Scene, name: []const u8) *SpotLight {
    assert(
        self.spot_lights.count() < max_spot_lights,
        "Too many spot lights",
        .{},
    );

    const alloc = self.arena_alloc;
    const n = alloc.dupe(u8, name) catch unreachable;
    const kv = self.spot_lights.getOrPut(alloc, n) catch unreachable;
    kv.value_ptr.* = .{};
    return kv.value_ptr;
}

pub fn createDirLight(self: *Scene, name: []const u8) *DirLight {
    assert(
        self.dir_lights.count() < max_dir_lights,
        "Too many dir lights",
        .{},
    );

    const alloc = self.arena_alloc;
    const n = alloc.dupe(u8, name) catch unreachable;
    const kv = self.dir_lights.getOrPut(alloc, n) catch unreachable;
    kv.value_ptr.* = .{};
    return kv.value_ptr;
}

pub fn deleteActor(self: *Scene, actor: *Actor) void {
    if (self.actors.count() == 0) {
        log.err(
            "Trying to delete an actor when there are no actors in the scene",
            .{},
        );
    }
    var iter = self.actors.iterator();
    while (iter.next()) |actr| {
        if (actr.value_ptr.id == actor.id) {
            assert(
                self.actors.remove(actr.key_ptr.*),
                "something went really wrong",
                .{},
            );
            self.alloc.destroy(actor);
            break;
        }
    }
}

pub fn deleteActorByName(self: *Scene, name: []const u8) void {
    if (self.actors.count() == 0) {
        log.err(
            "Trying to delete an actor when there are no actors in the scene",
            .{},
        );
    }

    if (self.actors.get(name)) |actor| {
        self.alloc.destroy(actor);
        assert(
            self.actors.remove(name),
            "something went really wrong",
            .{},
        );
    }
}

pub fn hasLights(self: *const Scene) bool {
    return self.point_lights.count() > 0 or
        self.spot_lights.count() > 0 or
        self.dir_lights.count() > 0;
}

pub fn loadDefaultSkybox(self: *Scene) void {
    self.setSkybox(.{
        fs.texturePath("skybox-sky/right.png"),
        fs.texturePath("skybox-sky/left.png"),
        fs.texturePath("skybox-sky/top.png"),
        fs.texturePath("skybox-sky/bottom.png"),
        fs.texturePath("skybox-sky/front.png"),
        fs.texturePath("skybox-sky/back.png"),
    });
}

pub fn getActorName(self: *const Scene, actor: *const Actor) ?[]const u8 {
    const id = actor.id;
    var iter = self.actors.iterator();
    while (iter.next()) |kv| {
        if (kv.value_ptr.*.id == id) {
            return kv.key_ptr.*;
        }
    }
    return null;
}

pub fn setSkybox(self: *Scene, paths: [6][]const u8) void {
    if (self.skybox.loaded()) {
        self.skybox.deinit();
    }
    self.skybox = Skybox.init(paths);
}

pub fn setSkyboxHidden(self: *Scene, hidden: bool) void {
    self.skybox_hidden = hidden;
}

var current_id: usize = 0;
fn generateId() usize {
    defer current_id += 1;
    return current_id;
}
