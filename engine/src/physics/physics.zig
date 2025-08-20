const std = @import("std");

const engine = @import("../engine.zig");
const math = engine.math;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const Vec2 = math.Vec2;
const Actor = engine.Actor;
const Transform = engine.Transform;
const Ray = math.Ray;

pub const HitInfo = struct {
    hit_point: Vec3,
    distance: f32,
};

pub fn getMouseHit() ?*Actor {
    return raycastHit(engine.input.mouseCastRay());
}

pub const BoundingBox = struct {
    min: Vec3,
    max: Vec3,

    pub fn intersectsWithRay(
        self: *const BoundingBox,
        tf: *const Transform,
        ray: Ray,
    ) ?HitInfo {
        const origin_v4 = Vec4{
            .x = ray.origin.x,
            .y = ray.origin.y,
            .z = ray.origin.z,
            .w = 1.0,
        };
        const inverse_model = tf.mat4().inverse();
        const local_ray = Ray{
            .origin = inverse_model.mulVec4(origin_v4),
            .direction = inverse_model.mulVec4(Vec4.fromVec3(ray.direction)),
        };
        return rayAABoxIntersection(local_ray, self);
    }
};

fn rayAABoxIntersection(r: Ray, bb: *const BoundingBox) ?HitInfo {
    _ = r; // autofix
    _ = bb; // autofix
    return null;
}

pub const RaycastHit = struct {
    actor: *Actor,
    hit_info: HitInfo,
};

pub fn raycastHit(scene: *engine.Scene, ray: Ray) ?RaycastHit {
    var rh: ?RaycastHit = null;

    var iter = scene.actors.valueIterator();
    while (iter.next()) |a| {
        const hit = a.bounding_box.intersectsWithRay(ray);
        if (hit) |h| {
            if (rh == null or h.distance < rh.?.hit_info.distance) {
                rh = RaycastHit{ .actor = a.*, .hit_info = h };
            }
        }
    }
    return rh;
}
