const std = @import("std");
const engine = @import("engine");
const Color = engine.Color;
const math = engine.math;
const Vec3 = math.Vec3;
const RigidBody = @import("root").RigidBody;

const Sphere = @This();
pub const zero = Sphere{
    .rb = .zero,
    .radius = 1,
    .color = .white,
};

/// center
rb: RigidBody,
radius: f32,
color: Color,

pub fn eql(self: *const Sphere, other: *const Sphere) bool {
    return std.meta.eql(self.*, other.*);
}
