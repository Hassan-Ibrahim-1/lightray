const std = @import("std");
const root = @import("engine.zig");
const log = root.debug.log;
const math = root.math;
const Vec3 = math.Vec3;
const Vec2 = math.Vec2;
const Mat4 = math.Mat4;
const Vertex = root.Vertex;
const Allocator = std.mem.Allocator;

pub fn Pair(T: type, V: type) type {
    return struct {
        first: T,
        second: V,

        const Self = @This();

        pub fn init(f: T, s: V) Self {
            return .{
                .first = f,
                .second = s,
            };
        }
    };
}

pub fn Size(T: type) type {
    const info = @typeInfo(T);
    switch (info) {
        .int, .comptime_int, .float, .comptime_float => {},
        else => @compileError("T must be an integer or a float"),
    }

    return struct {
        width: T,
        height: T,

        const Self = @This();

        pub fn init(width: T, height: T) Size {
            return .{
                .width = width,
                .height = height,
            };
        }

        pub fn vec2(self: Self) Vec2 {
            return .init(self.width, self.height);
        }

        pub fn as(self: Self, CastType: type) Size(CastType) {
            return switch (@typeInfo(T)) {
                .int, .comptime_int => switch (@typeInfo(CastType)) {
                    .int, .comptime_int => .{
                        .width = @intCast(self.width),
                        .height = @intCast(self.height),
                    },
                    .float, .comptime_float => .{
                        .width = @floatFromInt(self.width),
                        .height = @floatFromInt(self.height),
                    },
                    else => @compileError("CastType must be an integer or a float"),
                },
                .float, .comptime_float => switch (@typeInfo(CastType)) {
                    .int, .comptime_int => .{
                        .width = @intFromFloat(self.width),
                        .height = @intFromFloat(self.height),
                    },
                    .float, .comptime_float => .{
                        .width = @floatCast(self.width),
                        .height = @floatCast(self.height),
                    },
                    else => @compileError("CastType must be an integer or a float"),
                },
                else => @compileError("T must be an integer or a float"),
            };
        }
    };
}

/// returns indices of the found occurences
pub fn findAll(
    T: type,
    alloc: Allocator,
    slice: []const T,
    x: T,
) Allocator.Error![]usize {
    var al = std.ArrayList(usize).init(alloc);
    for (slice, 0..) |el, i| {
        if (el == x) {
            try al.append(i);
        }
    }
    return al.toOwnedSlice();
}

pub fn toNdc(screen_space: Vec2) Vec2 {
    const win_size = root.windowSize().as(f32);
    return .init(
        2.0 * screen_space.x / win_size.width - 1.0,
        1.0 - 2.0 * screen_space.y / win_size.height,
    );
}

pub fn pointInCircle(
    p: Vec2,
    circle_center: Vec2,
    radius: f32,
) bool {
    const dx = @abs(p.x - circle_center.x);
    if (dx > radius) {
        return false;
    }
    const dy = @abs(p.y - circle_center.y);
    if (dy > radius) {
        return false;
    }
    if (dx + dy <= radius) {
        return true;
    }

    return dx * dx + dy * dy <= radius * radius;
}

/// Holds a bounded value of type T between the specified max and min values inclusive.
/// All 'set' functions assert that the new value is within the specified bounds.
/// T must be an integer or float
pub fn Interval(
    T: type,
    minimum: T,
    maximum: T,
) type {
    return struct {
        const Self = @This();

        pub const max = if (minimum < maximum)
            maximum
        else
            @compileError("(Interval) expected minimum value to be smaller than the provided maximum value");

        pub const min = minimum;

        /// Don't tamper with _value yourself
        /// access it using the get() and set() functions
        _value: T,

        pub fn init(x: T) Self {
            root.debug.assert(
                inBounds(x),
                "(Interval) expected a value in the range [{d}, {d}] got {d}",
                .{ min, max, x },
            );
            return .{
                ._value = x,
            };
        }

        /// asserts that x is in the specified range
        pub fn set(self: Self, x: T) void {
            root.debug.assert(
                inBounds(x),
                "(Interval) expected a value in the range [{d}, {d}] got {d}",
                .{ min, max, x },
            );
            self._value = x;
        }

        pub fn get(self: Self) T {
            return self._value;
        }

        fn inBounds(x: T) bool {
            return x >= min and x <= max;
        }
    };
}

