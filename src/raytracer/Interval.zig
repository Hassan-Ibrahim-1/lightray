const engine = @import("engine");
const math = engine.math;

const Interval = @This();

min: f32 = 0,
max: f32 = 0,

pub fn init(min: f32, max: f32) Interval {
    return .{ .min = min, .max = max };
}

pub fn size(self: *const Interval) f32 {
    return self.max - self.min;
}

/// inclusive
pub fn contains(self: *const Interval, x: f32) bool {
    return self.min <= x and self.max >= x;
}

/// exclusive
pub fn surrounds(self: *const Interval, x: f32) bool {
    return self.min < x and self.max > x;
}

pub fn clamp(self: *const Interval, x: f32) f32 {
    if (x < self.min) return self.min;
    if (x > self.max) return self.max;
    return x;
}

pub fn empty() Interval {
    return .{
        .min = math.infinity,
        .max = -math.infinity,
    };
}

pub fn universe() Interval {
    return .{
        .min = -math.infinity,
        .max = math.infinity,
    };
}
