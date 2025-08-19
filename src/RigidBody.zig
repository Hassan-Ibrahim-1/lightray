const engine = @import("engine");
const Color = engine.Color;
const math = engine.math;
const Vec3 = math.Vec3;
const std = @import("std");

const RigidBody = @This();
pub const zero = RigidBody{
    .position = .zero,
    .velocity = .zero,
    .acceleration = .zero,
    .mass = 0,
    .bounce = 0,
    .is_static = false,
};

position: Vec3,
velocity: Vec3,
acceleration: Vec3,
mass: f32,
bounce: f32,
is_static: bool,

pub fn applyForce(self: *RigidBody, force: Vec3) void {
    self.acceleration = self.acceleration.add(force.divValue(self.mass));
}
