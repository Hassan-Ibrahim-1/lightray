const std = @import("std");
const gl = @import("gl");
const engine = @import("engine.zig");
pub const log = @import("log.zig");
const builtin = @import("builtin");

/// panics when an error is found
/// does nothing on non-debug builds
pub fn checkGlError() void {
    if (builtin.mode != .Debug) return;

    var had_error = false;
    var err: u32 = gl.GetError();
    while (err != gl.NO_ERROR) : (err = gl.GetError()) {
        had_error = true;
        const err_string = switch (err) {
            gl.INVALID_VALUE => "INVALID_VALUE",
            gl.INVALID_OPERATION => "INVALID_OPERATION",
            gl.OUT_OF_MEMORY => "OUT_OF_MEMORY",
            gl.INVALID_FRAMEBUFFER_OPERATION => "INVALID_FRAMEBUFFER_OPERATION",
            else => "unknown opengl error",
        };
        log.err(
            "had gl error {s}",
            .{err_string},
        );
    }
    if (had_error) {
        std.debug.dumpCurrentStackTrace(0);
        @panic("had an opengl error");
    }
}

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
