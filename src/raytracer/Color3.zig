const math = @import("engine").math;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const Interval = @import("../raytracer.zig").Interval;

const Color3 = @This();

pub const red = Color3.init(255, 0, 0);
pub const green = Color3.init(0, 255, 0);
pub const blue = Color3.init(0, 0, 255);
pub const yellow = Color3.init(255, 255, 0);
pub const cyan = Color3.init(0, 255, 255);
pub const magenta = Color3.init(255, 0, 255);
pub const white = Color3.init(255, 255, 255);
pub const black = Color3.init(0, 0, 0);
pub const orange = Color3.init(255, 165, 0);
pub const purple = Color3.init(128, 0, 128);
pub const pink = Color3.init(255, 192, 203);
pub const brown = Color3.init(139, 69, 19);
pub const gray = Color3.init(128, 128, 128);

r: u8,
g: u8,
b: u8,

pub fn init(
    r: u8,
    g: u8,
    b: u8,
) Color3 {
    return Color3{
        .r = r,
        .g = g,
        .b = b,
    };
}

const std = @import("std");

/// expects values from 0 through 1
pub fn initF32(r: f32, g: f32, b: f32) Color3 {
    return .{
        .r = @intFromFloat(clamp01(r) * 255),
        .g = @intFromFloat(clamp01(g) * 255),
        .b = @intFromFloat(clamp01(b) * 255),
    };
}

fn clamp01(v: f32) f32 {
    return std.math.clamp(v, 0.0, 1.0);
}

pub fn from(r: u8) Color3 {
    return Color3.init(r, r, r);
}

pub fn fromVec3(v: Vec3) Color3 {
    return Color3.initF32(v.x, v.y, v.z);
}

pub fn clampedVec3(self: *const Color3) Vec3 {
    return Vec3.init(
        @as(f32, @floatFromInt(self.r)) / 255.0,
        @as(f32, @floatFromInt(self.g)) / 255.0,
        @as(f32, @floatFromInt(self.b)) / 255.0,
    );
}

pub fn random() Color3 {
    return Color3.init(
        math.randomInt(u8, 0, 255),
        math.randomInt(u8, 0, 255),
        math.randomInt(u8, 0, 255),
    );
}

pub fn add(self: Color3, other: Color3) Color3 {
    const fs_r: f32 = @as(f32, @floatFromInt(self.r)) / 256.0;
    const fs_g: f32 = @as(f32, @floatFromInt(self.g)) / 256.0;
    const fs_b: f32 = @as(f32, @floatFromInt(self.b)) / 256.0;
    const fo_r: f32 = @as(f32, @floatFromInt(other.r)) / 256.0;
    const fo_g: f32 = @as(f32, @floatFromInt(other.g)) / 256.0;
    const fo_b: f32 = @as(f32, @floatFromInt(other.b)) / 256.0;
    return Color3.initF32(
        fs_r + fo_r,
        fs_g + fo_g,
        fs_b + fo_b,
    );
}

const cast = @import("engine").cast;

pub fn mul(self: Color3, value: f32) Color3 {
    return Color3.initF32(
        (cast.as(f32, self.r) / 255.00) * value,
        (cast.as(f32, self.g) / 255.00) * value,
        (cast.as(f32, self.b) / 255.00) * value,
    );
}

pub fn mulColor(self: Color3, other: Color3) Color3 {
    const fs_r: f32 = cast.as(f32, self.r) / 255.0;
    const fs_g: f32 = cast.as(f32, self.g) / 255.0;
    const fs_b: f32 = cast.as(f32, self.b) / 255.0;
    const fo_r: f32 = cast.as(f32, other.r) / 255.0;
    const fo_g: f32 = cast.as(f32, other.g) / 255.0;
    const fo_b: f32 = cast.as(f32, other.b) / 255.0;
    return Color3.initF32(
        fs_r * fo_r,
        fs_g * fo_g,
        fs_b * fo_b,
    );
}

pub fn toGamma(self: Color3) Color3 {
    return .initF32(
        @sqrt(cast.as(f32, self.r) / 255.0),
        @sqrt(cast.as(f32, self.g) / 255.0),
        @sqrt(cast.as(f32, self.b) / 255.0),
    );
}
