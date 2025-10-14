const std = @import("std");
const math = @import("math.zig");
const Vec3 = math.Vec3;
const Mat4 = math.Mat4;

const Transform = @This();

position: Vec3 = .zero,
scale: Vec3 = .fromValue(1),
/// should be in degrees
rotation: Vec3 = .zero,

///
pub fn initMinimum() Transform {
    return Transform{
        .position = Vec3.init(0, 0, 0),
        .scale = Vec3.init(1, 1, 1),
        .rotation = Vec3.init(0, 0, 0),
    };
}

pub fn init(
    pos: Vec3,
    scale: Vec3,
    rotation: Vec3,
) Transform {
    return Transform{
        .position = pos,
        .scale = scale,
        .rotation = rotation,
    };
}

pub fn mat4(self: *const Transform) Mat4 {
    var mat = Mat4.identity;
    mat = mat.translate(self.position);
    mat = mat.rotateY(math.toRadians(self.rotation.y));
    mat = mat.rotateX(math.toRadians(self.rotation.x));
    mat = mat.rotateZ(math.toRadians(self.rotation.z));
    mat = mat.scale(self.scale);
    return mat;
}

pub fn format(self: *const Transform, w: *std.Io.Writer) std.Io.Writer.Error!void {
    const spaces = "    ";
    try w.print(".{{\n{s}position: {f}\n{s}scale: {f}\n{s}rotation: {f}\n}}", .{
        spaces,
        self.position,
        spaces,
        self.scale,
        spaces,
        self.rotation,
    });
}
