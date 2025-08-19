const std = @import("std");
const Allocator = std.mem.Allocator;
const engine = @import("engine.zig");
const gl = @import("gl");
const glfw = engine.glfw;
const input = engine.input;
const Key = input.Key;
const Action = input.Action;
const log = engine.debug.log.Scoped(.Window);
const builtin = @import("builtin");

const Window = @This();

const WindowError = error{
    GlfwInitfailed,
    GlInitFailed,
};

allocator: Allocator,
/// don't mutate this
width: u32,
/// don't mutate this
height: u32,
name: [*:0]const u8,
/// don't mutate this. you can call functions on this. but don't
/// assign it to something else
glfw_window: *glfw.GLFWwindow,
/// don't touch this
gl_procs: *gl.ProcTable,
/// dont mutate this manually
cursor_enabled: bool = false,

/// Assumes that glfw.init has already been called
/// this will just create a window and load gl functions
/// nothing more
pub fn init(
    allocator: Allocator,
    width: u32,
    height: u32,
    name: [*:0]const u8,
) !Window {
    // fullscreen on linux
    // windowed on macos
    const window = win: {
        if (builtin.os.tag == .macos) {
            break :win glfw.glfwCreateWindow(
                @intCast(width),
                @intCast(height),
                @ptrCast(name),
                null,
                null,
            );
        } else {
            const monitor = glfw.glfwGetPrimaryMonitor();
            var xscale: f32 = 0;
            var yscale: f32 = 0;
            glfw.glfwGetMonitorContentScale(
                monitor,
                @ptrCast(&xscale),
                @ptrCast(&yscale),
            );
            break :win glfw.glfwCreateWindow(
                @intFromFloat(@as(f32, @floatFromInt(width)) * xscale),
                @intFromFloat(@as(f32, @floatFromInt(height)) * yscale),
                @ptrCast(name),
                monitor,
                null,
            ) orelse return error.GlfwInitfailed;
        }
    };

    glfw.glfwMakeContextCurrent(window);
    // glfw.makeContextCurrent(glfw_window);
    var gl_procs = try allocator.create(gl.ProcTable);
    if (!gl_procs.init(glfw.glfwGetProcAddress)) {
        return error.GlInitFailed;
    }

    gl.makeProcTableCurrent(gl_procs);

    _ = glfw.glfwSetFramebufferSizeCallback(window, framebufferSizeCallback);

    glfw.glfwFocusWindow(window);

    var major: c_int = 0;
    var minor: c_int = 0;
    var rev: c_int = 0;
    glfw.glfwGetVersion(&major, &minor, &rev);
    log.info("glfw version {}.{}.{}", .{ major, minor, rev });

    log.info(
        "creating window of size: {}, {}",
        .{ width, height },
    );
    if (builtin.os.tag == .linux) {
        gl.Viewport(0, 0, @intCast(width), @intCast(height));
    }

    if (builtin.os.tag == .macos) {
        return .{
            .allocator = allocator,
            .width = width,
            .height = height,
            .name = name,
            .glfw_window = window.?,
            .gl_procs = gl_procs,
        };
    } else {
        return .{
            .allocator = allocator,
            .width = width,
            .height = height,
            .name = name,
            .glfw_window = window,
            .gl_procs = gl_procs,
        };
    }
}

pub fn deinit(self: *Window) void {
    self.allocator.destroy(self.gl_procs);
    glfw.glfwDestroyWindow(self.glfw_window);
    glfw.glfwMakeContextCurrent(null);
    gl.makeProcTableCurrent(null);
}

fn framebufferSizeCallback(
    window: ?*glfw.GLFWwindow,
    width: c_int,
    height: c_int,
) callconv(.C) void {
    _ = window;
    gl.Viewport(0, 0, @intCast(width), @intCast(height));
}

pub fn swapBuffers(self: *Window) void {
    glfw.glfwGetWindowSize(
        self.glfw_window,
        @ptrCast(&self.width),
        @ptrCast(&self.height),
    );
    glfw.glfwSwapBuffers(self.glfw_window);
}

pub fn shouldClose(self: *Window) bool {
    return if (glfw.glfwWindowShouldClose(self.glfw_window) != 0) ret: {
        break :ret true;
    } else ret: {
        break :ret false;
    };
}

pub fn setShouldClose(self: *Window, value: bool) void {
    glfw.glfwSetWindowShouldClose(self.glfw_window, if (value) 1 else 0);
    // self.glfw_window.setShouldClose(value);
}

pub fn getKey(self: *Window, key: Key) Action {
    return @enumFromInt(glfw.glfwGetKey(
        self.glfw_window,
        key.toCint(),
    ));
}

pub fn enableCursor(self: *Window, b: bool) void {
    self.cursor_enabled = b;

    if (self.cursor_enabled) {
        glfw.glfwSetInputMode(
            self.glfw_window,
            glfw.GLFW_CURSOR,
            glfw.GLFW_CURSOR_NORMAL,
        );
    } else {
        glfw.glfwSetInputMode(
            self.glfw_window,
            glfw.GLFW_CURSOR,
            glfw.GLFW_CURSOR_DISABLED,
        );
    }
}
