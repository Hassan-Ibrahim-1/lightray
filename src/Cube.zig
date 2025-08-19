const std = @import("std");
const RigidBody = @import("root").RigidBody;

const engine = @import("engine");
const Color = engine.Color;
const math = engine.math;
const Vec3 = math.Vec3;

const Cube = @This();
pub const zero = Cube{
    .rb = .zero,
    .scale = .fromValue(1.0),
    .color = .white,
};

/// center
rb: RigidBody,
scale: Vec3,
color: Color,

pub fn eql(self: *const Cube, other: *const Cube) bool {
    return std.meta.eql(self.*, other.*);
}
