//! Some helpful comptime functions to determine a type's capabilities

const std = @import("std");

pub inline fn isInt(T: type) bool {
    return switch (@typeInfo(T)) {
        .int, .comptime_int => true,
        else => false,
    };
}

pub inline fn isFloat(T: type) bool {
    return switch (@typeInfo(T)) {
        .float, .comptime_float => true,
        else => false,
    };
}

pub inline fn isEnumLiteral(x: anytype) bool {
    return @typeInfo(x) == .enum_literal;
}
