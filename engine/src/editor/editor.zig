const std = @import("std");
const engine = @import("../engine.zig");
const debug = engine.debug;
const log = debug.log;
const Vec3 = math.Vec3;
const Vec2 = math.Vec2;
const Vec4 = math.Vec4;
const Mat4 = math.Mat4;
const fs = engine.fs;
const Transform = engine.Transform;
const Camera = engine.Camera;
const VertexBuffer = engine.VertexBuffer;
const Color = engine.Color;
const Vertex = engine.Vertex;
const Mesh = engine.Mesh;
const renderer = engine.renderer;
const Texture = engine.Texture;
const Actor = engine.Actor;
const Model = engine.Model;
const ig = engine.ig;
const math = engine.math;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const RenderItem = engine.RenderItem;
const Material = engine.Material;
const Scene = engine.Scene;
const PointLight = engine.PointLight;
const SpotLight = engine.SpotLight;
const DirLight = engine.DirLight;

const State = struct {
    scene: *Scene = undefined,
    allocator: Allocator = undefined,
    actor_buf: [512]u8 = undefined,
    light_buf: [512]u8 = undefined,
    adding_actor: bool = false,
    adding_light: bool = false,
    show_windows: bool = false,
};
var state = State{};

pub fn init() void {
    state.scene = engine.scene();
    state.allocator = engine.allocator();
}

pub fn update() void {
    if (engine.input.keyPressed(.m)) {
        state.show_windows = !state.show_windows;
    }
    if (engine.cursorEnabled() and state.show_windows) {
        createActorListWindow();
        createLightListWindow();
    }
}

fn createActorListWindow() void {
    _ = ig.begin("Actors");
    defer ig.end();

    ig.fpsCounter();

    _ = ig.textInput("actor name", &state.actor_buf);
    if (ig.button("Add actor") and !state.adding_actor) {
        state.adding_actor = true;
    }

    if (state.adding_actor) {
        createAddActorWindow(&state.actor_buf);
    }

    var iter = state.scene.actors.iterator();
    while (iter.next()) |actor| {
        const name = std.fmt.allocPrintZ(
            state.allocator,
            "{s}",
            .{actor.key_ptr.*},
        ) catch unreachable;
        defer state.allocator.free(name);
        _ = ig.actor(name, actor.value_ptr.*);
    }
}

var add_actor_selected_item: i32 = 0;
fn createAddActorWindow(name: []const u8) void {
    const win_name = std.fmt.allocPrintZ(
        state.allocator,
        "Actor - {s}",
        .{name},
    ) catch unreachable;
    defer state.allocator.free(win_name);
    _ = ig.begin(win_name);
    defer ig.end();

    const Size = ig.Size;
    ig.setWindowSize(Size.init(222, 83));

    const items: [:0]const u8 =
        "Cube\x00";
    // "Sphere\x00" ++
    // "Circle\x00" ++
    // "Rect";

    _ = ig.combo(
        "type",
        &add_actor_selected_item,
        items,
    );
    if (ig.button("create")) {
        switch (add_actor_selected_item) {
            // cube. this is just temporary
            // use an enum when adding new stuff
            0 => {
                // remove null term
                const len = std.mem.indexOfScalar(u8, name, 0).?;
                const actor = state.scene.createActor(name[0..len]);
                actor.render_item.loadModelData(renderer.cubeModel());
            },
            else => {
                log.err(
                    "Invalid menu item: {}",
                    .{add_actor_selected_item},
                );
            },
        }
        state.adding_actor = false;
    }
}

fn createLightListWindow() void {
    _ = ig.begin("Lights");
    defer ig.end();

    _ = ig.textInput("light name", &state.light_buf);
    if (ig.button("Add light") and !state.adding_light) {
        state.adding_light = true;
    }

    if (state.adding_light) {
        createAddLightWindow(&state.light_buf);
    }

    {
        var iter = state.scene.point_lights.iterator();
        while (iter.next()) |light| {
            const name = std.fmt.allocPrintZ(
                state.allocator,
                "{s}",
                .{light.key_ptr.*},
            ) catch unreachable;
            defer state.allocator.free(name);
            _ = ig.pointLight(name, light.value_ptr.*);
        }
    }

    {
        var iter = state.scene.spot_lights.iterator();
        while (iter.next()) |light| {
            const name = std.fmt.allocPrintZ(
                state.allocator,
                "{s}",
                .{light.key_ptr.*},
            ) catch unreachable;
            defer state.allocator.free(name);
            _ = ig.spotLight(name, light.value_ptr.*);
        }
    }

    {
        var iter = state.scene.dir_lights.iterator();
        while (iter.next()) |light| {
            const name = std.fmt.allocPrintZ(
                state.allocator,
                "{s}",
                .{light.key_ptr.*},
            ) catch unreachable;
            defer state.allocator.free(name);
            _ = ig.dirLight(name, light.value_ptr.*);
        }
    }
}

var add_light_selected_item: i32 = 0;
fn createAddLightWindow(name: []const u8) void {
    const win_name = std.fmt.allocPrintZ(
        state.allocator,
        "Light - {s}",
        .{name},
    ) catch unreachable;
    defer state.allocator.free(win_name);
    _ = ig.begin(win_name);
    defer ig.end();

    const Size = ig.Size;
    ig.setWindowSize(Size.init(222, 83));

    const LightType = enum(i32) { point, spot, dir };

    const items: [:0]const u8 =
        "Point Light\x00" ++
        "Spot Light\x00" ++
        "Directional Light\x00";

    _ = ig.combo(
        "type",
        &add_light_selected_item,
        items,
    );
    if (ig.button("create")) {
        switch (add_light_selected_item) {
            // cube. this is just temporary
            // use an enum when adding new stuff
            @intFromEnum(LightType.point) => {
                // remove null term
                const len = std.mem.indexOfScalar(u8, name, 0).?;
                _ = state.scene.createPointLight(name[0..len]);
            },
            @intFromEnum(LightType.spot) => {
                // remove null term
                const len = std.mem.indexOfScalar(u8, name, 0).?;
                _ = state.scene.createSpotLight(name[0..len]);
            },
            @intFromEnum(LightType.dir) => {
                // remove null term
                const len = std.mem.indexOfScalar(u8, name, 0).?;
                _ = state.scene.createDirLight(name[0..len]);
            },
            else => {
                log.err(
                    "Invalid menu item: {}",
                    .{add_light_selected_item},
                );
            },
        }
        state.adding_light = false;
    }
}

pub fn loadLightData(path: []const u8) FileLoadError!void {
    const f = std.fs.cwd().openFile(path, .{}) catch |err| {
        log.info(
            "Failed to open file: {s}\nerr: {s}",
            .{ path, @errorName(err) },
        );
        return error.FileNotFound;
    };
    defer f.close();

    const src = f.readToEndAlloc(
        state.allocator,
        std.math.maxInt(usize),
    ) catch unreachable;
    defer state.allocator.free(src);

    const parsed = std.json.parseFromSlice(
        []JsonLight,
        state.allocator,
        src,
        .{},
    ) catch |err| {
        log.err(
            "Failed to parse light data from file: {s}\n{s}",
            .{ path, @errorName(err) },
        );
        if (err == error.UnexpectedEndOfInput) {
            log.err("File was empty", .{});
            return error.EmptyFile;
        }
        return err;
    };
    defer parsed.deinit();

    const lights = parsed.value;
    for (lights) |parsed_light| {
        switch (parsed_light) {
            .point => |*point| {
                if (state.scene.point_lights.get(point.name)) |light| {
                    light.* = point.light;
                } else {
                    const light = state.scene.createPointLight(point.name);
                    light.* = point.light;
                }
            },
            .spot => |*spot| {
                if (state.scene.spot_lights.get(spot.name)) |light| {
                    light.* = spot.light;
                } else {
                    const light = state.scene.createSpotLight(spot.name);
                    light.* = spot.light;
                }
            },
            .dir => |*dir| {
                if (state.scene.dir_lights.get(dir.name)) |light| {
                    light.* = dir.light;
                } else {
                    const light = state.scene.createDirLight(dir.name);
                    light.* = dir.light;
                }
            },
        }
    }
}

const FileLoadError = error{
    FileNotFound,
    EmptyFile,
} || std.json.ParseError(std.json.Scanner);

pub fn loadActorData(path: []const u8) FileLoadError!void {
    const f = std.fs.cwd().openFile(path, .{}) catch |err| {
        log.info(
            "Failed to open file: {s}\nerr: {s}",
            .{ path, @errorName(err) },
        );
        return error.FileNotFound;
    };
    defer f.close();

    const src = f.readToEndAlloc(
        state.allocator,
        std.math.maxInt(usize),
    ) catch unreachable;
    defer state.allocator.free(src);

    // these structs are just placeholders to represent values
    // that are actually going to be stored in the json file
    // can't use the actual structs because of some null pointer stuff
    // in Material and some other fields that don't matter (like id)
    const ParsedMaterial = struct {
        color: Color,
        shininess: f32,
    };

    const ParsedRenderItem = struct {
        material: ParsedMaterial,
        hidden: bool,
    };

    const ParsedActor = struct {
        name: []const u8,
        render_item: ParsedRenderItem,
        transform: Transform,

        const Self = @This();

        pub fn copyToActor(self: *const Self, actor: *Actor) void {
            const ri = self.render_item;
            actor.render_item.hidden = ri.hidden;
            actor.render_item.material.shininess = ri.material.shininess;
            actor.render_item.material.color = ri.material.color;
            actor.transform = self.transform;
        }
    };

    const parsed = std.json.parseFromSlice(
        []ParsedActor,
        state.allocator,
        src,
        .{},
    ) catch |err| {
        log.err(
            "Failed to parse actor data from file: {s}\n{s}",
            .{ path, @errorName(err) },
        );
        if (err == error.UnexpectedEndOfInput) {
            log.err("File was empty", .{});
            return error.EmptyFile;
        }
        return err;
    };
    defer parsed.deinit();

    const actors = parsed.value;
    for (actors) |parsed_actor| {
        if (state.scene.actors.get(parsed_actor.name)) |actor| {
            parsed_actor.copyToActor(actor);
        } else {
            const actor = state.scene.createActor(parsed_actor.name);
            parsed_actor.copyToActor(actor);

            // Temporary hack to load stuff
            // currently only supports cubes so thats all that this will
            // load. there should be something like model path added later
            actor.render_item.loadModelData(renderer.cubeModel());
        }
    }
}

/// creates the file if it doesn't already exist
/// if it does exist it overwrites it
pub fn saveActorData(path: []const u8) void {
    const f = std.fs.cwd().createFile(path, .{}) catch unreachable;
    defer f.close();
    const writer = f.writer();

    // this is horribly inefficient
    // creating an allocated ArrayList of actors just to copy stuff
    var actors = ArrayList(*Actor).init(state.allocator);
    defer actors.deinit();
    var iter = state.scene.actors.valueIterator();
    while (iter.next()) |actor| {
        actors.append(actor.*) catch unreachable;
    }

    std.json.stringify(
        actors.items,
        .{ .whitespace = .indent_4 },
        writer,
    ) catch unreachable;
}

const JsonLight = union(enum) {
    point: struct {
        name: []const u8,
        light: PointLight,
    },
    spot: struct {
        name: []const u8,
        light: SpotLight,
    },
    dir: struct {
        name: []const u8,
        light: DirLight,
    },
};

/// creates the file if it doesn't already exist
/// if it does exist it overwrites it
pub fn saveLightData(path: []const u8) void {
    const f = std.fs.cwd().createFile(path, .{}) catch unreachable;
    defer f.close();
    const writer = f.writer();

    // this is horribly inefficient
    // creating an allocated ArrayList of lights just to copy stuff

    var lights = ArrayList(JsonLight).init(state.allocator);
    defer lights.deinit();

    // point lights
    {
        var iter = state.scene.point_lights.iterator();
        while (iter.next()) |kv| {
            const light = kv.value_ptr.*;
            const name = kv.key_ptr.*;
            lights.append(.{
                .point = .{
                    .name = name,
                    .light = light.*,
                },
            }) catch unreachable;
        }
    }

    // spot lights
    {
        var iter = state.scene.spot_lights.iterator();
        while (iter.next()) |kv| {
            const light = kv.value_ptr.*;
            const name = kv.key_ptr.*;
            lights.append(.{
                .spot = .{
                    .name = name,
                    .light = light.*,
                },
            }) catch unreachable;
        }
    }

    // dir lights
    {
        var iter = state.scene.dir_lights.iterator();
        while (iter.next()) |kv| {
            const light = kv.value_ptr.*;
            const name = kv.key_ptr.*;
            lights.append(.{
                .dir = .{
                    .name = name,
                    .light = light.*,
                },
            }) catch unreachable;
        }
    }

    std.json.stringify(
        lights.items,
        .{ .whitespace = .indent_4 },
        writer,
    ) catch unreachable;
}
