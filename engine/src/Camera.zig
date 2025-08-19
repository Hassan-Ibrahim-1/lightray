const std = @import("std");
const math = @import("math.zig");
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Mat4 = math.Mat4;
const Transform = @import("Transform.zig");

pub const Direction = enum {
    forward,
    backward,
    right,
    left,
    up,
    down,
};

const Camera = @This();

transform: Transform = Transform.init(
    Vec3.fromValue(0),
    Vec3.fromValue(1),
    Vec3.init(0, -90, 0),
),
speed: f32 = 10.0,

world_up: Vec3,
/// Initialized by calling updateVectors
up: Vec3 = Vec3.init(0, 0, 0),
front: Vec3 = Vec3.init(0, 0, -1),
/// Initialized by calling updateVectors
right: Vec3 = Vec3.fromValue(0),
fov: f32 = 45.0,
sensitivity: Vec2 = Vec2.init(0.05, 0.05),
aspect_ratio: f32 = 16.0 / 9.0,

near: f32 = 0.1,
far: f32 = 100.0,

/// Don't mutate this
reset_look_back: bool = false,
/// Don't mutate this
_locked: bool = false,

pub fn init(world_up: Vec3) Camera {
    var camera = Camera{
        .world_up = world_up,
    };
    camera.updateVectors();
    return camera;
}

pub fn getViewMatrix(self: *Camera) Mat4 {
    return Mat4.lookAt(
        self.transform.position,
        self.transform.position.add(self.front),
        self.up,
    );
}

pub fn getPerspectiveMatrix(self: *const Camera) Mat4 {
    return Mat4.perspective(
        math.toRadians(self.fov),
        self.aspect_ratio,
        self.near,
        self.far,
    );
}

pub fn updateVectors(self: *Camera) void {
    var tmp_front: Vec3 = Vec3.fromValue(0);
    tmp_front.x =
        math.cos(math.toRadians(self.transform.rotation.y)) * math.cos(
            math.toRadians(self.transform.rotation.x),
        );
    tmp_front.y = math.sin(math.toRadians(self.transform.rotation.x));
    tmp_front.z =
        math.sin(math.toRadians(self.transform.rotation.y)) * math.cos(
            math.toRadians(self.transform.rotation.x),
        );
    self.front = tmp_front.normalized();
    self.right = self.front.cross(self.world_up).normalized();
    self.up = self.right.cross(self.front).normalized();
}

pub fn processKeyboard(self: *Camera, dir: Direction, delta_time: f32) void {
    if (self._locked) return;
    const vertical_multiplier = 1.0;
    const speed = self.speed * delta_time;

    self.transform.position = switch (dir) {
        .forward => self.transform.position.add(self.front.mulValue(speed)),
        .backward => self.transform.position.sub(self.front.mulValue(speed)),
        .right => self.transform.position.add(self.right.mulValue(speed)),
        .left => self.transform.position.sub(self.right.mulValue(speed)),
        .up => self.transform.position.add(self.world_up.mulValue(speed * vertical_multiplier)),
        .down => self.transform.position.sub(self.world_up.mulValue(speed * vertical_multiplier)),
    };
}

pub fn processMouseMovement(
    self: *Camera,
    x_offset: f32,
    y_offset: f32,
    constrain_pitch: bool,
    invert_pitch: bool,
) void {
    if (self._locked) {
        return;
    }

    self.transform.rotation.x += value: {
        const offset = y_offset * self.sensitivity.y;
        if (invert_pitch) {
            break :value offset;
        } else {
            break :value -offset;
        }
    };
    self.transform.rotation.y += x_offset * self.sensitivity.x;

    if (constrain_pitch) {
        if (self.transform.rotation.x > 89.0) {
            self.transform.rotation.x = 89.0;
        } else if (self.transform.rotation.x < -89.0) {
            self.transform.rotation.x = -89.0;
        }
    }
    self.updateVectors();
}

pub fn processMouseScroll(self: *Camera, y_offset: f32) void {
    self.fov -= y_offset;
    self.fov = std.math.clamp(self.fov, 45.0, 100.0);
}

pub fn lock(self: *Camera) void {
    self._locked = true;
}

pub fn unlock(self: *Camera) void {
    self._locked = false;
}
