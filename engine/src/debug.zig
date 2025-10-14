const std = @import("std");
const gl = @import("gl");
const engine = @import("engine.zig");
pub const log = @import("debug/log.zig");
const builtin = @import("builtin");

pub fn assert(
    b: bool,
    comptime fmt: []const u8,
    args: anytype,
) void {
    if (!b) {
        const alloc = std.heap.page_allocator;
        const err = std.fmt.allocPrint(
            alloc,
            fmt,
            args,
        ) catch unreachable;
        defer alloc.free(err);
        log.err("{s}", .{err});
        std.debug.dumpCurrentStackTrace(0);
        @panic(err);
    }
}
