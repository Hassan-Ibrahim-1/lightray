const std = @import("std");
const engine = @import("engine.zig");
const debug = engine.debug;
const log = debug.log;
const assert = debug.assert;
const Actor = engine.Actor;
const Allocator = std.mem.Allocator;
const HashMap = std.StringHashMap;
const SpotLight = engine.SpotLight;
const DirLight = engine.DirLight;
const PointLight = engine.PointLight;
const Skybox = engine.Skybox;
const fs = engine.fs;
const ArenaAllocator = std.heap.ArenaAllocator;

const Scene = @This();

const max_point_lights = 8;
const max_spot_lights = 8;
const max_dir_lights = 8;

allocator: Allocator,
actors: HashMap(*Actor),
point_lights: HashMap(*PointLight),
spot_lights: HashMap(*SpotLight),
dir_lights: HashMap(*DirLight),
skybox: Skybox = undefined,
_skybox_hidden: bool = false,
name_arena: ArenaAllocator,

pub fn init(allocator: Allocator) Scene {
    return Scene{
        .allocator = allocator,
        .actors = HashMap(*Actor).init(allocator),
        .point_lights = HashMap(*PointLight).init(allocator),
        .spot_lights = HashMap(*SpotLight).init(allocator),
        .dir_lights = HashMap(*DirLight).init(allocator),
        .name_arena = ArenaAllocator.init(allocator),
    };
}

pub fn deinit(self: *Scene) void {
    self.clearActors();
    self.clearLights();
    self.name_arena.deinit();
}

/// you don't have to manually call deinit on actor
/// it will automatically get deleted on scene.deinit
pub fn createActor(self: *Scene, name: []const u8) *Actor {
    const actor = self.allocator.create(Actor) catch unreachable;
    actor.* = Actor.init(self.allocator);
    actor.id = generateId();
    const alloc = self.name_arena.allocator();
    const n = alloc.dupe(u8, name) catch unreachable;
    self.actors.put(n, actor) catch unreachable;
    return actor;
}

pub fn actorCount(self: *const Scene) usize {
    return self.actors.count();
}

pub fn createPointLight(self: *Scene, name: []const u8) *PointLight {
    const light = self.allocator.create(PointLight) catch unreachable;
    light.* = PointLight{};
    assert(
        self.pointLightCount() < max_point_lights,
        "Too many point lights",
        .{},
    );
    const alloc = self.name_arena.allocator();
    const n = alloc.alloc(u8, name.len) catch unreachable;
    @memcpy(n, name);
    self.point_lights.put(n, light) catch unreachable;
    return light;
}

pub fn createSpotLight(self: *Scene, name: []const u8) *SpotLight {
    const light = self.allocator.create(SpotLight) catch unreachable;
    light.* = SpotLight{};
    assert(
        self.spotLightCount() < max_spot_lights,
        "Too many spot lights",
        .{},
    );

    const alloc = self.name_arena.allocator();
    const n = alloc.alloc(u8, name.len) catch unreachable;
    @memcpy(n, name);
    self.spot_lights.put(n, light) catch unreachable;
    return light;
}

pub fn createDirLight(self: *Scene, name: []const u8) *DirLight {
    const light = self.allocator.create(DirLight) catch unreachable;
    light.* = DirLight{};
    assert(
        self.dirLightCount() < max_dir_lights,
        "Too many dir lights",
        .{},
    );
    const alloc = self.name_arena.allocator();
    const n = alloc.alloc(u8, name.len) catch unreachable;
    @memcpy(n, name);
    self.dir_lights.put(n, light) catch unreachable;
    return light;
}

pub fn deleteActor(self: *Scene, actor: *Actor) void {
    if (self.actorCount() == 0) {
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
            self.allocator.destroy(actor);
            break;
        }
    }
}

pub fn deleteActorByName(self: *Scene, name: []const u8) void {
    if (self.actorCount() == 0) {
        log.err(
            "Trying to delete an actor when there are no actors in the scene",
            .{},
        );
    }

    if (self.actors.get(name)) |actor| {
        self.allocator.destroy(actor);
        assert(
            self.actors.remove(name),
            "something went really wrong",
            .{},
        );
    }
}

pub fn pointLightCount(self: *const Scene) usize {
    return self.point_lights.count();
}

pub fn spotLightCount(self: *const Scene) usize {
    return self.spot_lights.count();
}

pub fn dirLightCount(self: *const Scene) usize {
    return self.dir_lights.count();
}

pub fn hasLights(self: *const Scene) bool {
    // zig fmt: off
    return self.pointLightCount() > 0
        or self.spotLightCount() > 0
        or self.dirLightCount() > 0;
}

pub fn clearActors(self: *Scene) void {
    var iter = self.actors.iterator();
    while (iter.next()) |actor| {
        actor.value_ptr.*.deinit();
        self.allocator.destroy(actor.value_ptr.*);
    }
    self.actors.clearAndFree();
}

pub fn clearLights(self: *Scene) void {
    var p_iter = self.point_lights.iterator();
    while (p_iter.next()) |light| {
        self.allocator.destroy(light.value_ptr.*);
    }
    self.point_lights.clearAndFree();

    var s_iter = self.spot_lights.iterator();
    while (s_iter.next()) |light| {
        self.allocator.destroy(light.value_ptr.*);
    }
    self.spot_lights.clearAndFree();

    var d_iter = self.dir_lights.iterator();
    while (d_iter.next()) |light| {
        self.allocator.destroy(light.value_ptr.*);
    }
    self.dir_lights.clearAndFree();
}

pub fn nameTaken(self: *const Scene, name: []const u8) bool {
    if (self.actors.get(name)) |_| {
        return true;
    }

    if (self.point_lights.get(name)) |_| {
        return true;
    }

    if (self.spot_lights.get(name)) |_| {
        return true;
    }

    if (self.dir_lights.get(name)) |_| {
        return true;
    }
    return false;
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

pub fn getActorName(self: *const Scene, actor: *const Actor,) ?[]const u8 {
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
    self._skybox_hidden = hidden;
}

var current_id: usize = 0;
fn generateId() usize {
    current_id += 1;
    return current_id - 1;
}
