const math = @import("engine.zig").math;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;

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
a: u8 = 255,

pub fn init(
    r: u8,
    g: u8,
    b: u8,
) Color {
    return Color{
        .r = r,
        .g = g,
        .b = b,
        .a = 255,
    };
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

pub fn fromVec4(v: Vec4) Color {
    return Color.initAll(
        @intFromFloat(v.x * 255),
        @intFromFloat(v.y * 255),
        @intFromFloat(v.z * 255),
        @intFromFloat(v.w * 255),
    );
}

pub fn initAll(
    r: u8,
    g: u8,
    b: u8,
    a: u8,
) Color {
    return Color{
        .r = r,
        .g = g,
        .b = b,
        .a = a,
    };
}

pub fn clampedVec3(self: *const Color) Vec3 {
    return Vec3.init(
        @as(f32, @floatFromInt(self.r)) / 255.0,
        @as(f32, @floatFromInt(self.g)) / 255.0,
        @as(f32, @floatFromInt(self.b)) / 255.0,
    );
}
pub fn clampedVec4(self: *const Color) Vec4 {
    return Vec4.init(
        @as(f32, @floatFromInt(self.r)) / 255.0,
        @as(f32, @floatFromInt(self.g)) / 255.0,
        @as(f32, @floatFromInt(self.b)) / 255.0,
        @as(f32, @floatFromInt(self.a)) / 255.0,
    );
}

pub fn random() Color {
    return Color.init(
        math.randomInt(u8, 0, 255),
        math.randomInt(u8, 0, 255),
        math.randomInt(u8, 0, 255),
    );
}
