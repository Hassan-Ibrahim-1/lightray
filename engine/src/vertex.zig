const engine = @import("engine.zig");
const Vec3 = engine.math.Vec3;
const Vec2 = engine.math.Vec2;

const Vertex = @This();

position: Vec3,
normal: Vec3,
uv: Vec2,

pub fn init(pos: Vec3, normal: Vec3, uv: Vec2) Vertex {
    return Vertex{
        .position = pos,
        .normal = normal,
        .uv = uv,
    };
}

pub fn fromPos(pos: Vec3) Vertex {
    return Vertex{
        .position = pos,
        .normal = Vec3.zero,
        .uv = Vec2.zero,
    };
}
