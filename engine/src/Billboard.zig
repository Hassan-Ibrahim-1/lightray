const engine = @import("engine.zig");
const Vec3 = engine.math.Vec3;

position: Vec3,
scale: f32,
/// this isn't Color for optimization purposes
/// color data in the gpu is represented as Vec3 so
/// for performance reasons this is stored as a Vec3
color: Vec3,
