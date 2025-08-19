const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const ArrayList = std.ArrayList;
const builtin = @import("builtin");

const engine = @import("engine");
const renderer = engine.renderer;
const Shader = engine.Shader;
const VertexBuffer = engine.VertexBuffer;
const Color = engine.Color;
const math = engine.math;
const Vec3 = math.Vec3;
const gl = engine.gl;
const debug = engine.debug;
const utils = engine.utils;
const Pair = utils.Pair;
const ig = engine.ig;
const input = engine.input;

const log = debug.log.Scoped(.main);

pub const Sphere = @import("Sphere.zig");
pub const Cube = @import("Cube.zig");
pub const RigidBody = @import("RigidBody.zig");
const phys = @import("physics.zig");

const force = 50;

const State = struct {
    arena: std.mem.Allocator,
    spheres: std.MultiArrayList(Pair(Sphere, *engine.Actor)),
    cubes: std.MultiArrayList(Pair(Cube, *engine.Actor)),
    sphere_model: *engine.Model,
    cube_model: *engine.Model,

    pub fn init() !State {
        return State{
            .arena = engine.arena(),
            .spheres = .empty,
            .cubes = .empty,
            .sphere_model = engine.loadModel(
                "engine/models/low_poly_sphere.glb",
            ),
            .cube_model = renderer.cubeModel(),
        };
    }

    fn updateSpheres(self: *State) void {
        const slice = self.spheres.slice();
        for (0..self.spheres.len) |i| {
            const p = slice.get(i);
            const sphere = &p.first;
            const actor = p.second;
            actor.transform.position = sphere.rb.position;
            actor.transform.scale = .fromValue(sphere.radius);
            actor.render_item.material.color = sphere.color;
        }
    }

    fn updateCubes(self: *State) void {
        const slice = self.cubes.slice();
        for (0..self.cubes.len) |i| {
            const p = slice.get(i);
            const cube = &p.first;
            const actor = p.second;
            actor.transform.position = cube.rb.position;
            actor.transform.scale = cube.scale;
            actor.render_item.material.color = cube.color;
        }
    }

    fn update(self: *State) void {
        self.updateSpheres();
        self.updateCubes();
    }

    fn newSphere(self: *State) !*Sphere {
        const name = try std.fmt.allocPrint(
            engine.frameAllocator(),
            "sphere{}",
            .{self.spheres.len},
        );
        const actor = engine.scene().createActor(name);
        actor.render_item.loadModelData(self.sphere_model);
        actor.render_item.material.shininess = 32;
        try self.spheres.append(self.arena, .init(Sphere.zero, actor));
        return &self.spheres.slice().items(.first)[self.spheres.len - 1];
    }

    fn newCube(self: *State) !*Cube {
        const name = try std.fmt.allocPrint(
            engine.frameAllocator(),
            "cube{}",
            .{self.cubes.len},
        );
        const actor = engine.scene().createActor(name);
        actor.render_item.loadModelData(self.cube_model);
        actor.render_item.material.shininess = 32;
        try self.cubes.append(self.arena, .init(Cube.zero, actor));
        return &self.cubes.slice().items(.first)[self.cubes.len - 1];
    }

    fn rigidBodies(self: *State, alloc: Allocator) Allocator.Error![]*RigidBody {
        var rbs = ArrayList(*RigidBody).init(alloc);
        try rbs.ensureTotalCapacityPrecise(self.spheres.len + self.cubes.len);

        const spheres = self.spheres.items(.first);
        for (spheres) |*s| {
            rbs.appendAssumeCapacity(&s.rb);
        }
        const cubes = self.cubes.items(.first);
        for (cubes) |*c| {
            rbs.appendAssumeCapacity(&c.rb);
        }
        return rbs.toOwnedSlice();
    }
};
var state: State = undefined;

fn init() !void {
    state = try .init();
    // engine.scene().setSkyboxHidden(true);
    try phys.init(state.sphere_model);
    const sphere2 = try state.newSphere();
    const sphere = try state.newSphere();

    sphere2.rb.position = .init(-3, 0, 0);
    sphere2.rb.mass = 1.0;
    sphere2.rb.bounce = 0.2;

    sphere.rb.position = .init(3, 0, 0);
    sphere.rb.mass = 1.0;
    sphere.rb.bounce = 0.2;

    // addGroundPlane();

    const cam = engine.camera();
    cam.transform.position.y = -2;
    cam.transform.position.z = 5;
}

fn addGroundPlane() void {
    const rect_mesh = renderer.rectMesh();
    const ground = engine.scene().createActor("ground");
    const m = ground.render_item.createMesh();
    m.* = .fromVao(
        engine.allocator(),
        rect_mesh.vertex_buffer.vao.?,
    );
    m.draw_command = rect_mesh.draw_command;
    ground.transform.scale.x = 100;
    ground.transform.scale.y = 100;
    ground.transform.rotation.x = 90;
    ground.transform.position.y = phys.ground_y;
}

fn update() !void {
    state.update();
    const spheres = state.spheres.items(.first);
    const cubes = state.cubes.items(.first);
    phys.resolveCollisions(spheres, cubes);
    phys.updateRigidBodies(try state.rigidBodies(engine.frameAllocator()));

    if (engine.cursorEnabled()) {
        // try cubeWindow();
        // try sphereWindow();
        try phys.addToImGui(spheres.len);
    }

    if (input.keyDown(.right)) {
        for (spheres) |*s| {
            const rand = engine.math.randomFloat(f32, -1, 1);
            s.rb.applyForce(Vec3.init(1, 0, rand).mulValue(force));
        }
    }
    if (input.keyDown(.left)) {
        for (spheres) |*s| {
            const rand = engine.math.randomFloat(f32, -1, 1);
            s.rb.applyForce(Vec3.init(-1, 0, rand).mulValue(force));
        }
    }
    if (input.keyDown(.up)) {
        for (spheres) |*s| {
            const rand = engine.math.randomFloat(f32, -1, 1);
            s.rb.applyForce(Vec3.init(0, 1, rand).mulValue(force));
        }
    }
    if (input.keyDown(.down)) {
        for (spheres) |*s| {
            const rand = engine.math.randomFloat(f32, -1, 1);
            s.rb.applyForce(Vec3.init(0, -1, rand).mulValue(force));
        }
    }

    if (input.keyPressed(.g)) {
        for (0..20) |_| {
            const sphere = try state.newSphere();
            sphere.rb.mass = 1.0;
            sphere.rb.bounce = 0.2;
            sphere.color = .random();
        }
    }
}

fn cubeWindow() !void {
    ig.begin("cubes");
    defer ig.end();

    const scene = engine.scene();
    var slice = state.cubes.slice();
    for (0..state.cubes.len) |i| {
        var p = slice.get(i);
        try igCube(scene.getActorName(p.second).?, &p.first);
        slice.set(i, p);
        ig.spacing();
    }
}
fn sphereWindow() !void {
    ig.begin("spheres");
    defer ig.end();

    const scene = engine.scene();
    var slice = state.spheres.slice();
    for (0..state.spheres.len) |i| {
        var p = slice.get(i);
        try igSphere(scene.getActorName(p.second).?, &p.first);
        slice.set(i, p);
        ig.spacing();
    }
}

fn deinit() void {}

pub fn main() !void {
    if (builtin.os.tag == .linux) {
        try engine.init(&.{
            .width = 3840,
            .height = 2160,
            .name = "verlet",
        });
    } else {
        try engine.init(&.{
            .width = 1920,
            .height = 1080,
            .name = "verlet",
        });
    }
    defer engine.deinit();
    engine.run(&.{
        .init = init,
        .update = update,
        .deinit = deinit,
    });
}

pub fn igCube(name: []const u8, c: *Cube) !void {
    const alloc = engine.frameAllocator();

    try igRigidBody(name, &c.rb);
    var n = try std.fmt.allocPrintZ(alloc, "{s} scale", .{name});
    _ = ig.dragVec3(n, &c.scale);
    n = try std.fmt.allocPrintZ(alloc, "{s} color", .{name});
    _ = ig.color3(n, &c.color);
}

pub fn igSphere(name: []const u8, s: *Sphere) !void {
    const alloc = engine.frameAllocator();

    try igRigidBody(name, &s.rb);
    var n = try std.fmt.allocPrintZ(alloc, "{s} radius", .{name});
    _ = ig.dragFloatEx(n, &s.radius, 0.01, null, null);
    n = try std.fmt.allocPrintZ(alloc, "{s} color", .{name});
    _ = ig.color3(n, &s.color);
}

fn igRigidBody(name: []const u8, rb: *RigidBody) !void {
    const alloc = engine.frameAllocator();

    var n = try std.fmt.allocPrintZ(alloc, "{s} position", .{name});
    _ = ig.dragVec3(n, &rb.position);
    n = try std.fmt.allocPrintZ(alloc, "{s} velocity", .{name});
    _ = ig.dragVec3(n, &rb.velocity);
    n = try std.fmt.allocPrintZ(alloc, "{s} acceleration", .{name});
    _ = ig.dragVec3(n, &rb.acceleration);
    n = try std.fmt.allocPrintZ(alloc, "{s} mass", .{name});
    _ = ig.dragFloat(n, &rb.mass);
    n = try std.fmt.allocPrintZ(alloc, "{s} bounce", .{name});
    _ = ig.dragFloat(n, &rb.bounce);
    n = try std.fmt.allocPrintZ(alloc, "{s} is_static", .{name});
    _ = ig.checkBox(n, &rb.is_static);
}
