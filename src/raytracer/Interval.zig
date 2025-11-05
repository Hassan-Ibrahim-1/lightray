const engine = @import("engine");
const math = engine.math;

const Interval = @This();

min: f32,
max: f32,

pub const empty: Interval = .{
    .min = math.infinity,
    .max = -math.infinity,
};

pub const universe: Interval = .{
    .min = -math.infinity,
    .max = math.infinity,
};

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
