const math = @import("engine").math;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const Interval = @import("../raytracer.zig").Interval;

const Color = @This();

pub const red = Color.init(255, 0, 0);
pub const green = Color.init(0, 255, 0);
pub const blue = Color.init(0, 0, 255);
pub const yellow = Color.init(255, 255, 0);
pub const cyan = Color.init(0, 255, 255);
pub const magenta = Color.init(255, 0, 255);
pub const white = Color.init(255, 255, 255);
pub const black = Color.init(0, 0, 0);
pub const orange = Color.init(255, 165, 0);
pub const purple = Color.init(128, 0, 128);
pub const pink = Color.init(255, 192, 203);
pub const brown = Color.init(139, 69, 19);
pub const gray = Color.init(128, 128, 128);

r: u8,
g: u8,
b: u8,

pub fn init(
    r: u8,
    g: u8,
    b: u8,
) Color {
    return Color{
        .r = r,
        .g = g,
        .b = b,
    };
}

const std = @import("std");

/// expects values from 0 through 1
pub fn initF32(r: f32, g: f32, b: f32) Color {
    return .{
        .r = @intFromFloat(clamp01(r) * 255),
        .g = @intFromFloat(clamp01(g) * 255),
        .b = @intFromFloat(clamp01(b) * 255),
    };
}

fn clamp01(v: f32) f32 {
    return std.math.clamp(v, 0.0, 1.0);
}

pub fn from(r: u8) Color {
    return Color.init(r, r, r);
}

pub fn fromVec3(v: Vec3) Color {
    return Color.init(
        @intFromFloat(v.x * 255),
        @intFromFloat(v.y * 255),
        @intFromFloat(v.z * 255),
    );
}

pub fn clampedVec3(self: *const Color) Vec3 {
    return Vec3.init(
        @as(f32, @floatFromInt(self.r)) / 255.0,
        @as(f32, @floatFromInt(self.g)) / 255.0,
        @as(f32, @floatFromInt(self.b)) / 255.0,
    );
}

pub fn random() Color {
    return Color.init(
        math.randomInt(u8, 0, 255),
        math.randomInt(u8, 0, 255),
        math.randomInt(u8, 0, 255),
    );
}

pub fn add(self: Color, other: Color) Color {
    const fs_r: f32 = @as(f32, @floatFromInt(self.r)) / 256.0;
    const fs_g: f32 = @as(f32, @floatFromInt(self.g)) / 256.0;
    const fs_b: f32 = @as(f32, @floatFromInt(self.b)) / 256.0;
    const fo_r: f32 = @as(f32, @floatFromInt(other.r)) / 256.0;
    const fo_g: f32 = @as(f32, @floatFromInt(other.g)) / 256.0;
    const fo_b: f32 = @as(f32, @floatFromInt(other.b)) / 256.0;
    return Color.initF32(
        fs_r + fo_r,
        fs_g + fo_g,
        fs_b + fo_b,
    );
}

pub fn mul(self: Color, value: f32) Color {
    return Color.initF32(
        (@as(f32, @floatFromInt(self.r)) / 256.00) * value,
        (@as(f32, @floatFromInt(self.g)) / 256.00) * value,
        (@as(f32, @floatFromInt(self.b)) / 256.00) * value,
    );
}

pub fn mulColor(self: Color, other: Color) Color {
    const fs_r: f32 = @as(f32, @floatFromInt(self.r)) / 256.0;
    const fs_g: f32 = @as(f32, @floatFromInt(self.g)) / 256.0;
    const fs_b: f32 = @as(f32, @floatFromInt(self.b)) / 256.0;
    const fo_r: f32 = @as(f32, @floatFromInt(other.r)) / 256.0;
    const fo_g: f32 = @as(f32, @floatFromInt(other.g)) / 256.0;
    const fo_b: f32 = @as(f32, @floatFromInt(other.b)) / 256.0;
    return Color.initF32(
        fs_r * fo_r,
        fs_g * fo_g,
        fs_b * fo_b,
    );
}
