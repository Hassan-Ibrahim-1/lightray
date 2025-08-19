const std = @import("std");
const Allocator = std.mem.Allocator;

const Camera = @import("Camera.zig");
const engine = @import("engine.zig");
const Window = engine.Window;
const glfw = engine.glfw;
const ig = engine.ig;
const log = @import("log.zig");
const math = @import("math.zig");
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const Mat4 = math.Mat4;
const Transform = @import("Transform.zig");

const start_key_index: u32 = @intFromEnum(Key.space);
const max_keys: u32 = @as(u32, Key.last()) + 1;

const KeyCallbackFn = *const fn (key: Key, action: Action) void;

pub const Key = enum(i32) {
    invalid = 0,
    space = 32,
    apostrophe = 39,
    comma = 44,
    minus = 45,
    period = 46,
    slash = 47,
    zero = 48,
    one = 49,
    two = 50,
    three = 51,
    four = 52,
    five = 53,
    six = 54,
    seven = 55,
    eight = 56,
    nine = 57,
    semicolon = 59,
    equal = 61,
    a = 65,
    b = 66,
    c = 67,
    d = 68,
    e = 69,
    f = 70,
    g = 71,
    h = 72,
    i = 73,
    j = 74,
    k = 75,
    l = 76,
    m = 77,
    n = 78,
    o = 79,
    p = 80,
    q = 81,
    r = 82,
    s = 83,
    t = 84,
    u = 85,
    v = 86,
    w = 87,
    x = 88,
    y = 89,
    z = 90,
    left_bracket = 91,
    backslash = 92,
    right_bracket = 93,
    grave_accent = 96,
    world_1 = 161,
    world_2 = 162,
    escape = 256,
    enter = 257,
    tab = 258,
    backspace = 259,
    insert = 260,
    delete = 261,
    right = 262,
    left = 263,
    down = 264,
    up = 265,
    page_up = 266,
    page_down = 267,
    home = 268,
    end = 269,
    caps_lock = 280,
    scroll_lock = 281,
    num_lock = 282,
    print_screen = 283,
    pause = 284,
    f1 = 290,
    f2 = 291,
    f3 = 292,
    f4 = 293,
    f5 = 294,
    f6 = 295,
    f7 = 296,
    f8 = 297,
    f9 = 298,
    f10 = 299,
    f11 = 300,
    f12 = 301,
    f13 = 302,
    f14 = 303,
    f15 = 304,
    f16 = 305,
    f17 = 306,
    f18 = 307,
    f19 = 308,
    f20 = 309,
    f21 = 310,
    f22 = 311,
    f23 = 312,
    f24 = 313,
    f25 = 314,
    kp_0 = 320,
    kp_1 = 321,
    kp_2 = 322,
    kp_3 = 323,
    kp_4 = 324,
    kp_5 = 325,
    kp_6 = 326,
    kp_7 = 327,
    kp_8 = 328,
    kp_9 = 329,
    kp_decimal = 330,
    kp_divide = 331,
    kp_multiply = 332,
    kp_subtract = 333,
    kp_add = 334,
    kp_enter = 335,
    kp_equal = 336,
    left_shift = 340,
    left_control = 341,
    left_alt = 342,
    left_super = 343,
    right_shift = 344,
    right_control = 345,
    right_alt = 346,
    right_super = 347,
    menu = 348,

    pub fn last() i32 {
        return @intFromEnum(Key.menu);
    }

    pub fn toCint(self: Key) c_int {
        return @intFromEnum(self);
    }

    pub fn fromCint(k: c_int) Key {
        if (k == -1) return .invalid;
        return @enumFromInt(k);
    }
};

pub const Action = enum(i32) {
    unknown = -1,
    release = 0,
    press = 1,
    repeat = 2,

    pub fn toCint(self: Action) c_int {
        return @intFromEnum(self);
    }

    pub fn fromCint(k: c_int) Action {
        return @enumFromInt(k);
    }
};

// TODO: add support for other mouse buttons that glfw supports
pub const MouseButton = enum(i32) {
    any = -1,
    right = 0,
    left = 1,
    middle = 2,
    last = 7,

    pub fn toCint(self: MouseButton) c_int {
        return @intFromEnum(self);
    }

    pub fn fromCint(k: c_int) MouseButton {
        return @enumFromInt(k);
    }
};

var alloc: Allocator = undefined;

// TODO: wrap this in a state struct

/// stored as normalized device coordinates
var mouse_pos = Vec2.fromValue(0);
var last_mouse_pos = Vec2.fromValue(0);
var first_mouse = true;

var scroll_delta = Vec2.fromValue(0);

var lmb_down = false;
var lmb_clicked = false;
var lmb_released = false;
var rmb_down = false;
var rmb_clicked = false;
var rmb_released = false;

var key_pressed = [_]bool{false} ** max_keys;
var key_released = [_]bool{false} ** max_keys;
var key_down = [_]bool{false} ** max_keys;

var user_key_callbacks: std.ArrayList(KeyCallbackFn) = undefined;

var camera: *Camera = undefined;

var window: *Window = undefined;
var imio: *ig.ImGuiIO_t = undefined;

pub fn init(allocator: Allocator) void {
    alloc = allocator;
    user_key_callbacks = std.ArrayList(KeyCallbackFn).init(alloc);
    window = engine.window();
    imio = engine.imGuiIo();

    camera = engine.camera();
    setCallbacks();

    // keys appear to be set to true initially?
    // thats why this is here
    updateKeys();
}

pub fn deinit() void {
    user_key_callbacks.deinit();
}

fn setCallbacks() void {
    const win = window.glfw_window;
    _ = glfw.glfwSetKeyCallback(win, keyCallback);
    _ = glfw.glfwSetCursorPosCallback(win, mouseMovementCallback);
    _ = glfw.glfwSetScrollCallback(win, mouseScrollCallback);
    _ = glfw.glfwSetMouseButtonCallback(win, mouseButtonCallback);
}

pub fn startFrame() void {
    glfw.glfwPollEvents();

    const dt = engine.deltaTime();

    if (imio.WantTextInput) return;
    updateKeys();
    camera = engine.camera();

    if (window.getKey(.w) == .press) {
        camera.processKeyboard(.forward, dt);
    }
    if (window.getKey(.a) == .press) {
        camera.processKeyboard(.left, dt);
    }
    if (window.getKey(.s) == .press) {
        camera.processKeyboard(.backward, dt);
    }
    if (window.getKey(.d) == .press) {
        camera.processKeyboard(.right, dt);
    }
    if (window.getKey(.q) == .press) {
        camera.processKeyboard(.down, dt);
    }
    if (window.getKey(.e) == .press) {
        camera.processKeyboard(.up, dt);
    }
}

pub fn endFrame() void {
    updateMouseButtons();
}

/// normalized between 0.0 and 1.0
pub fn getNdcMousePos() Vec2 {
    return mouse_pos;
}

pub fn getScrollDelta() Vec2 {
    return scroll_delta;
}

/// mouse pos in screen space
pub fn getMousePos() Vec2 {
    // convert ndc mouse coords to world space
    const mouse_ndc = Vec4.init(mouse_pos.x, mouse_pos.y, 0.0, 1.0);
    const inverse_view = camera.getViewMatrix().inverse();
    const world_space = inverse_view.mulVec4(mouse_ndc);
    return Vec2.fromVec4(world_space);
}

pub fn mouseButtonDown(button: MouseButton) bool {
    if (button == .any) {
        return lmb_down or rmb_down;
    } else if (button == .left) {
        return lmb_down;
    } else if (button == .right) {
        return rmb_down;
    }
    return false;
}

pub fn mouseButtonClicked(button: MouseButton) bool {
    if (button == .any) {
        return lmb_clicked or rmb_clicked;
    } else if (button == .left) {
        return lmb_clicked;
    } else if (button == .right) {
        return rmb_clicked;
    }
    return false;
}

pub fn mouseButtonReleased(button: MouseButton) bool {
    if (button == .any) {
        return lmb_released or rmb_released;
    } else if (button == .left) {
        return lmb_released;
    } else if (button == .right) {
        return rmb_released;
    }
    return false;
}

pub fn addKeyCallback(callback: KeyCallbackFn) void {
    user_key_callbacks.append(callback) catch @panic("allocation failed");
}

pub fn keyPressed(key: Key) bool {
    return key_pressed[@intCast(@intFromEnum(key))];
}

pub fn keyReleased(key: Key) bool {
    return key_released[@intCast(@intFromEnum(key))];
}

pub fn keyDown(key: Key) bool {
    return key_down[@intCast(@intFromEnum(key))];
}

fn updateMouseButtons() void {
    lmb_clicked = false;
    lmb_released = false;
    rmb_clicked = false;
    rmb_released = false;
}

fn updateKeys() void {
    // where keys start?
    var i: usize = 32;
    while (i < max_keys) : (i += 1) {
        key_pressed[i] = false;
        key_released[i] = false;

        // weird hack. had to modify mach-glfw to make the c functions accessible
        // window.getKey(@enumFromtInt(i)) wasn't working
        const action = Action.fromCint(
            glfw.glfwGetKey(
                window.glfw_window,
                @intCast(i),
            ),
        );
        const down = action == .press;
        if (!key_down[i] and down) {
            key_pressed[i] = true;
        } else if (key_down[i] and !down) {
            key_released[i] = true;
        }
        key_down[i] = down;
    }
}

fn keyCallback(
    win: ?*glfw.GLFWwindow,
    c_key: c_int,
    c_scancode: c_int,
    c_action: c_int,
    c_mods: c_int,
) callconv(.C) void {
    //
    ig.setKeyCallback(
        @ptrCast(win),
        c_key,
        c_scancode,
        c_action,
        c_mods,
    );

    const key = Key.fromCint(c_key);
    const action = Action.fromCint(c_action);
    if ((key == .escape) and action == .press) {
        if (engine.cursorEnabled()) {
            engine.setCursorEnabled(false);
        } else {
            window.setShouldClose(true);
        }
    }

    if (imio.WantTextInput) return;

    for (user_key_callbacks.items) |callback| {
        const key_action: Action = value: {
            if (keyPressed(key)) break :value .press;
            if (keyReleased(key)) break :value .release;
            unreachable;
        };
        callback(key, key_action);
    }

    // else if ((key == .o) and action == .press) {
    // log.info("reloading shaders", .{});
    // shader.reload() catch |err| {
    //     log.err(
    //         "failed to reload shader with paths: \n{s}\n{s} error: {}",
    //         .{ shader.vertex_path, shader.fragment_path, err },
    //     );
    // };
    // }
}

fn mouseMovementCallback(
    win: ?*glfw.GLFWwindow,
    posx: f64,
    posy: f64,
) callconv(.C) void {
    ig.setMousemovementCallback(@ptrCast(win), posx, posy);
    var width: c_int = 0;
    var height: c_int = 0;
    glfw.glfwGetWindowSize(win.?, &width, &height);
    const viewport = Vec4.init(
        0,
        0,
        @floatFromInt(width),
        @floatFromInt(height),
    );
    const w = Vec3.init(@floatCast(posx), @floatCast(posy), 0);
    const real_pos = math.unProject(
        w,
        &Mat4.identity,
        &Mat4.identity,
        viewport,
    );
    mouse_pos.x = real_pos.x;
    mouse_pos.y = -real_pos.y;
    if (first_mouse) {
        last_mouse_pos.x = @floatCast(posx);
        last_mouse_pos.y = @floatCast(posy);
        first_mouse = false;
    }

    if (!engine.cursorEnabled()) {
        const x_offset = @as(f32, @floatCast(posx)) - last_mouse_pos.x;
        const y_offset = @as(f32, @floatCast(posy)) - last_mouse_pos.y;
        camera.processMouseMovement(x_offset, y_offset, true, false);
    }

    last_mouse_pos.x = @floatCast(posx);
    last_mouse_pos.y = @floatCast(posy);
}

fn mouseScrollCallback(
    win: ?*glfw.GLFWwindow,
    xoffset: f64,
    yoffset: f64,
) callconv(.C) void {
    ig.setMouseScrollCallback(@ptrCast(win), xoffset, yoffset);
    scroll_delta = Vec2.init(
        @floatCast(xoffset),
        @floatCast(yoffset),
    );
    if (imio.WantCaptureMouse) return;
    camera.processMouseScroll(@floatCast(yoffset));
}

fn mouseButtonCallback(
    win: ?*glfw.GLFWwindow,
    c_button: c_int,
    c_action: c_int,
    mods: c_int,
) callconv(.C) void {
    ig.setMouseButtonCallback(
        @ptrCast(win),
        c_button,
        c_action,
        mods,
    );

    if (imio.WantCaptureMouse) return;

    const button = MouseButton.fromCint(c_button);
    const action = Action.fromCint(c_action);
    if (button == .left) {
        if (action == .press) {
            lmb_down = true;
            lmb_clicked = true;
            lmb_released = false;
        } else if (action == .release) {
            lmb_down = false;
            lmb_clicked = false;
            lmb_released = true;
        }
    } else if (button == .right) {
        if (action == .press) {
            rmb_down = true;
            rmb_clicked = true;
            rmb_released = false;
        } else if (action == .release) {
            rmb_down = false;
            rmb_clicked = false;
            rmb_released = true;
        }
    }
}
