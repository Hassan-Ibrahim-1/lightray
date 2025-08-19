const std = @import("std");
const engine = @import("engine.zig");
const ig = engine.ig_raw;
const math = engine.math;
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const Color = engine.Color;
const Material = engine.Material;
const RenderItem = engine.RenderItem;
const Transform = engine.Transform;
const Actor = engine.Actor;
const Allocator = std.mem.Allocator;
const PointLight = engine.PointLight;
const SpotLight = engine.SpotLight;
const DirLight = engine.DirLight;

pub const ImGuiIO_t = ig.ImGuiIO_t;

const State = struct {
    allocator: Allocator,
};

var state: State = undefined;

pub fn init(allocator: Allocator) void {
    state.allocator = allocator;
}

pub fn begin(name: [:0]const u8) void {
    beginEx(name, null, 0);
}

pub fn beginEx(
    name: [:0]const u8,
    open: ?*bool,
    flags: ig.ImGuiWindowFlags,
) void {
    _ = ig.igBegin(@ptrCast(name), open, flags);
}

pub const Size = struct {
    width: f32,
    height: f32,
    pub fn init(width: f32, height: f32) Size {
        return .{
            .width = width,
            .height = height,
        };
    }
};

pub fn setWindowSize(size: Size) void {
    ig.igSetWindowSize(
        .{ .x = size.width, .y = size.height },
        ig.ImGuiCond_Once,
    );
}

pub fn end() void {
    ig.igEnd();
}

pub fn combo(
    name: [:0]const u8,
    selected_item: *i32,
    items: [:0]const u8,
) bool {
    return ig.igCombo(
        name,
        @ptrCast(selected_item),
        @ptrCast(items),
    );
}

pub fn dragInt(name: [:0]const u8, i: *i32) bool {
    return ig.igDragInt(@ptrCast(name), @ptrCast(i));
}

pub fn dragIntEx(
    name: [:0]const u8,
    i: *i32,
    speed: f32,
    vmin: ?i32,
    vmax: ?i32,
) bool {
    const min = blk: {
        if (vmin != null) break :blk vmin.?;
        break :blk std.math.minInt(i32);
    };
    const max = blk: {
        if (vmax != null) break :blk vmax.?;
        break :blk std.math.maxInt(i32);
    };
    return ig.igDragIntEx(
        @ptrCast(name),
        @ptrCast(i),
        speed,
        min,
        max,
        null,
        0,
    );
}

pub fn dragFloat(name: [:0]const u8, f: *f32) bool {
    return ig.igDragFloat(@ptrCast(name), f);
}

pub fn dragFloatEx(
    name: [:0]const u8,
    f: *f32,
    speed: f32,
    vmin: ?f32,
    vmax: ?f32,
) bool {
    const min = blk: {
        if (vmin != null) break :blk vmin.?;
        break :blk std.math.floatMin(f32);
    };
    const max = blk: {
        if (vmax != null) break :blk vmax.?;
        break :blk std.math.floatMax(f32);
    };
    return ig.igDragFloatEx(
        @ptrCast(name),
        @ptrCast(f),
        speed,
        min,
        max,
        null,
        0,
    );
}

pub fn dragFloat2(
    name: [:0]const u8,
    values: [*]f32,
) bool {
    return ig.igDragFloat2(
        @ptrCast(name),
        @ptrCast(values),
    );
}

pub fn dragFloat2Ex(
    name: [:0]const u8,
    values: [*]f32,
    speed: f32,
    vmin: ?f32,
    vmax: ?f32,
) bool {
    const min = blk: {
        if (vmin != null) break :blk vmin.?;
        break :blk std.math.floatMin(f32);
    };
    const max = blk: {
        if (vmax != null) break :blk vmax.?;
        break :blk std.math.floatMax(f32);
    };

    return ig.igDragFloat2Ex(
        @ptrCast(name),
        @ptrCast(values),
        speed,
        max,
        min,
        null,
        0,
    );
}

pub fn dragFloat3(
    name: [:0]const u8,
    values: [*]f32,
) bool {
    return ig.igDragFloat3(
        @ptrCast(name),
        @ptrCast(values),
    );
}

pub fn dragFloat3Ex(
    name: [:0]const u8,
    values: [*]f32,
    speed: f32,
    vmin: ?f32,
    vmax: ?f32,
) bool {
    const min = blk: {
        if (vmin != null) break :blk vmin.?;
        break :blk std.math.floatMin(f32);
    };
    const max = blk: {
        if (vmax != null) break :blk vmax.?;
        break :blk std.math.floatMax(f32);
    };

    return ig.igDragFloat3Ex(
        @ptrCast(name),
        @ptrCast(values),
        speed,
        max,
        min,
        null,
        0,
    );
}

pub fn dragFloat4(
    name: [:0]const u8,
    values: [*]f32,
) bool {
    return ig.igDragFloat4(
        @ptrCast(name),
        @ptrCast(values),
    );
}

pub fn dragFloat4Ex(
    name: [:0]const u8,
    values: [*]f32,
    speed: f32,
    vmin: ?f32,
    vmax: ?f32,
) bool {
    const min = blk: {
        if (vmin != null) break :blk vmin.?;
        break :blk std.math.floatMin(f32);
    };
    const max = blk: {
        if (vmax != null) break :blk vmax.?;
        break :blk std.math.floatMax(f32);
    };

    return ig.igDragFloat4Ex(
        @ptrCast(name),
        @ptrCast(values),
        speed,
        max,
        min,
        null,
        0,
    );
}

pub fn dragVec2(
    name: [:0]const u8,
    v: *Vec2,
) bool {
    return dragFloat2(name, @ptrCast(v));
}

pub fn dragVec2Ex(
    name: [:0]const u8,
    v: *Vec2,
    speed: f32,
    vmin: ?f32,
    vmax: ?f32,
) bool {
    return dragFloat2Ex(
        name,
        @ptrCast(v),
        speed,
        vmin,
        vmax,
    );
}

pub fn dragVec3(
    name: [:0]const u8,
    v: *Vec3,
) bool {
    return dragFloat3(name, @ptrCast(v));
}

pub fn dragVec3Ex(
    name: [:0]const u8,
    v: *Vec3,
    speed: f32,
    vmin: ?f32,
    vmax: ?f32,
) bool {
    return dragFloat3Ex(
        name,
        @ptrCast(v),
        speed,
        vmin,
        vmax,
    );
}

pub fn dragVec4(
    name: [:0]const u8,
    v: *Vec4,
) bool {
    return dragFloat4(name, @ptrCast(v));
}

pub fn dragVec4Ex(
    name: [:0]const u8,
    v: *Vec4,
    speed: f32,
    vmin: ?f32,
    vmax: ?f32,
) bool {
    return dragFloat4Ex(
        name,
        @ptrCast(v),
        speed,
        vmin,
        vmax,
    );
}

pub fn checkBox(name: [:0]const u8, b: *bool) bool {
    return ig.igCheckbox(@ptrCast(name), @ptrCast(b));
}

pub fn textInput(name: [:0]const u8, buf: []u8) bool {
    return ig.igInputText(
        @ptrCast(name),
        @ptrCast(buf),
        buf.len,
        0,
    );
}

pub fn button(name: [:0]const u8) bool {
    return ig.igButton(@ptrCast(name));
}

pub fn color3(name: [:0]const u8, c: *Color) bool {
    var v = c.clampedVec3();
    const res = ig.igColorEdit3(@ptrCast(name), @ptrCast(&v), 0);
    c.* = Color.fromVec3(v);
    return res;
}

pub fn color4(name: [:0]const u8, c: *Color) bool {
    var v = c.clampedVec4();
    const res = ig.igColorEdit4(@ptrCast(name), @ptrCast(&v), 0);
    c.* = Color.fromVec4(v);
    return res;
}

/// only bases the return value on position
pub fn transform(name: [:0]const u8, tf: *Transform) bool {
    var n1 = std.mem.concatWithSentinel(
        state.allocator,
        u8,
        &.{ name, " position" },
        0,
    ) catch unreachable;
    const res = dragVec3Ex(n1, &tf.position, 0.1, null, null);
    state.allocator.free(n1);

    n1 = std.mem.concatWithSentinel(
        state.allocator,
        u8,
        &.{ name, " scale" },
        0,
    ) catch unreachable;
    _ = dragVec3Ex(n1, &tf.scale, 0.1, null, null);
    state.allocator.free(n1);

    n1 = std.mem.concatWithSentinel(
        state.allocator,
        u8,
        &.{ name, " rotation" },
        0,
    ) catch unreachable;
    _ = dragVec3Ex(n1, &tf.rotation, 0.1, null, null);
    state.allocator.free(n1);

    return res;
}

/// return value is based on whether color changed
pub fn material(name: [:0]const u8, mat: *Material) bool {
    var n1 = std.mem.concatWithSentinel(
        state.allocator,
        u8,
        &.{ name, " color" },
        0,
    ) catch unreachable;
    const res = color3(n1, &mat.color);
    state.allocator.free(n1);

    n1 = std.mem.concatWithSentinel(
        state.allocator,
        u8,
        &.{ name, " shininess" },
        0,
    ) catch unreachable;
    _ = dragFloat(n1, &mat.shininess);
    state.allocator.free(n1);

    return res;
}

pub fn renderItem(name: [:0]const u8, ri: *RenderItem) bool {
    const res = material(name, &ri.material);
    const n1 = std.mem.concatWithSentinel(
        state.allocator,
        u8,
        &.{ name, " hidden" },
        0,
    ) catch unreachable;
    _ = checkBox(n1, &ri.hidden);
    state.allocator.free(n1);

    return res;
}

pub fn spacing() void {
    ig.igSpacing();
}

/// returns result of transform
pub fn actor(name: [:0]const u8, actr: *Actor) bool {
    const res = transform(name, &actr.transform);
    _ = renderItem(name, &actr.render_item);
    spacing();
    return res;
}

fn lightColor(
    name: [:0]const u8,
    ambient: *Color,
    diffuse: *Color,
    specular: *Color,
) void {
    {
        const n1 = std.fmt.allocPrintZ(
            state.allocator,
            "{s} ambient",
            .{name},
        ) catch unreachable;
        defer state.allocator.free(n1);
        _ = color3(n1, ambient);
    }

    {
        const n1 = std.fmt.allocPrintZ(
            state.allocator,
            "{s} diffuse",
            .{name},
        ) catch unreachable;
        defer state.allocator.free(n1);
        _ = color3(n1, diffuse);
    }

    {
        const n1 = std.fmt.allocPrintZ(
            state.allocator,
            "{s} specular",
            .{name},
        ) catch unreachable;
        defer state.allocator.free(n1);
        _ = color3(n1, specular);
    }
}

pub fn pointLight(
    name: [:0]const u8,
    light: *PointLight,
) bool {
    var res = false;
    {
        const n1 = std.fmt.allocPrintZ(
            state.allocator,
            "{s} pos",
            .{name},
        ) catch unreachable;
        defer state.allocator.free(n1);
        res = dragVec3Ex(n1, &light.position, 0.1, null, null);
    }
    lightColor(
        name,
        &light.ambient,
        &light.diffuse,
        &light.specular,
    );
    {
        const n1 = std.fmt.allocPrintZ(
            state.allocator,
            "{s} hidden",
            .{name},
        ) catch unreachable;
        defer state.allocator.free(n1);
        _ = checkBox(n1, &light.hidden);
    }

    spacing();
    return res;
}

pub fn dirLight(name: [:0]const u8, light: *DirLight) bool {
    var res = false;
    {
        const n1 = std.fmt.allocPrintZ(
            state.allocator,
            "{s} pos",
            .{name},
        ) catch unreachable;
        defer state.allocator.free(n1);
        res = dragVec3Ex(n1, &light.position, 0.1, null, null);
    }
    {
        const n1 = std.fmt.allocPrintZ(
            state.allocator,
            "{s} dir",
            .{name},
        ) catch unreachable;
        defer state.allocator.free(n1);
        _ = dragVec3Ex(n1, &light.direction, 0.1, null, null);
    }
    lightColor(
        name,
        &light.ambient,
        &light.diffuse,
        &light.specular,
    );
    {
        const n1 = std.fmt.allocPrintZ(
            state.allocator,
            "{s} hidden",
            .{name},
        ) catch unreachable;
        defer state.allocator.free(n1);
        _ = checkBox(n1, &light.hidden);
    }

    spacing();
    return res;
}

pub fn spotLight(
    name: [:0]const u8,
    light: *SpotLight,
) bool {
    var res = false;
    {
        const n1 = std.fmt.allocPrintZ(
            state.allocator,
            "{s} pos",
            .{name},
        ) catch unreachable;
        defer state.allocator.free(n1);
        res = dragVec3Ex(n1, &light.position, 0.1, null, null);
    }
    {
        const n1 = std.fmt.allocPrintZ(
            state.allocator,
            "{s} dir",
            .{name},
        ) catch unreachable;
        defer state.allocator.free(n1);
        _ = dragVec3Ex(n1, &light.direction, 0.1, null, null);
    }
    {
        const n1 = std.fmt.allocPrintZ(
            state.allocator,
            "{s} inner cutoff",
            .{name},
        ) catch unreachable;
        defer state.allocator.free(n1);
        _ = dragFloatEx(n1, &light.inner_cutoff, 0.1, null, null);
    }
    {
        const n1 = std.fmt.allocPrintZ(
            state.allocator,
            "{s} outer cutoff",
            .{name},
        ) catch unreachable;
        defer state.allocator.free(n1);
        _ = dragFloatEx(n1, &light.outer_cutoff, 0.1, null, null);
    }
    lightColor(
        name,
        &light.ambient,
        &light.diffuse,
        &light.specular,
    );
    {
        const n1 = std.fmt.allocPrintZ(
            state.allocator,
            "{s} hidden",
            .{name},
        ) catch unreachable;
        defer state.allocator.free(n1);
        _ = checkBox(n1, &light.hidden);
    }

    spacing();
    return res;
}

pub fn text(str: [:0]const u8) void {
    ig.igText(str);
}

pub fn fpsCounter() void {
    const fps = engine.imGuiIo().Framerate;
    ig.igText(
        "Application average %.3f ms/frame (%.1f FPS)",
        1000.0 / fps,
        fps,
    );
}

// TODO: lights

fn initImVec4(r: f32, g: f32, b: f32, a: f32) ig.ImVec4 {
    return .{
        .x = r,
        .y = g,
        .z = b,
        .w = a,
    };
}

pub fn initImVec2(r: f32, g: f32) ig.ImVec2 {
    return .{
        .x = r,
        .y = g,
    };
}

pub fn setMaterialYouTheme() void {
    const style = ig.igGetStyle();
    var colors = style.*.Colors;

    // Base colors inspired by Material You (dark mode)
    colors[ig.ImGuiCol_Text] = initImVec4(0.93, 0.93, 0.94, 1.00);
    colors[ig.ImGuiCol_TextDisabled] = initImVec4(0.50, 0.50, 0.50, 1.00);
    colors[ig.ImGuiCol_WindowBg] = initImVec4(0.12, 0.12, 0.12, 1.00);
    colors[ig.ImGuiCol_ChildBg] = initImVec4(0.12, 0.12, 0.12, 1.00);
    colors[ig.ImGuiCol_PopupBg] = initImVec4(0.15, 0.15, 0.15, 1.00);
    colors[ig.ImGuiCol_Border] = initImVec4(0.25, 0.25, 0.28, 1.00);
    colors[ig.ImGuiCol_BorderShadow] = initImVec4(0.00, 0.00, 0.00, 0.00);
    colors[ig.ImGuiCol_FrameBg] = initImVec4(0.18, 0.18, 0.18, 1.00);
    colors[ig.ImGuiCol_FrameBgHovered] = initImVec4(0.22, 0.22, 0.22, 1.00);
    colors[ig.ImGuiCol_FrameBgActive] = initImVec4(0.24, 0.24, 0.24, 1.00);
    colors[ig.ImGuiCol_TitleBg] = initImVec4(0.14, 0.14, 0.14, 1.00);
    colors[ig.ImGuiCol_TitleBgActive] = initImVec4(0.16, 0.16, 0.16, 1.00);
    colors[ig.ImGuiCol_TitleBgCollapsed] = initImVec4(0.14, 0.14, 0.14, 1.00);
    colors[ig.ImGuiCol_MenuBarBg] = initImVec4(0.14, 0.14, 0.14, 1.00);
    colors[ig.ImGuiCol_ScrollbarBg] = initImVec4(0.14, 0.14, 0.14, 1.00);
    colors[ig.ImGuiCol_ScrollbarGrab] = initImVec4(0.18, 0.18, 0.18, 1.00);
    colors[ig.ImGuiCol_ScrollbarGrabHovered] = initImVec4(0.20, 0.20, 0.20, 1.00);
    colors[ig.ImGuiCol_ScrollbarGrabActive] = initImVec4(0.24, 0.24, 0.24, 1.00);
    colors[ig.ImGuiCol_CheckMark] = initImVec4(0.45, 0.76, 0.29, 1.00);
    colors[ig.ImGuiCol_SliderGrab] = initImVec4(0.29, 0.62, 0.91, 1.00);
    colors[ig.ImGuiCol_SliderGrabActive] = initImVec4(0.29, 0.66, 0.91, 1.00);
    colors[ig.ImGuiCol_Button] = initImVec4(0.18, 0.47, 0.91, 1.00);
    colors[ig.ImGuiCol_ButtonHovered] = initImVec4(0.29, 0.62, 0.91, 1.00);
    colors[ig.ImGuiCol_ButtonActive] = initImVec4(0.22, 0.52, 0.91, 1.00);
    colors[ig.ImGuiCol_Header] = initImVec4(0.18, 0.47, 0.91, 1.00);
    colors[ig.ImGuiCol_HeaderHovered] = initImVec4(0.29, 0.62, 0.91, 1.00);
    colors[ig.ImGuiCol_HeaderActive] = initImVec4(0.29, 0.66, 0.91, 1.00);
    colors[ig.ImGuiCol_Separator] = initImVec4(0.22, 0.22, 0.22, 1.00);
    colors[ig.ImGuiCol_SeparatorHovered] = initImVec4(0.29, 0.62, 0.91, 1.00);
    colors[ig.ImGuiCol_SeparatorActive] = initImVec4(0.29, 0.66, 0.91, 1.00);
    colors[ig.ImGuiCol_ResizeGrip] = initImVec4(0.29, 0.62, 0.91, 1.00);
    colors[ig.ImGuiCol_ResizeGripHovered] = initImVec4(0.29, 0.66, 0.91, 1.00);
    colors[ig.ImGuiCol_ResizeGripActive] = initImVec4(0.29, 0.70, 0.91, 1.00);
    colors[ig.ImGuiCol_Tab] = initImVec4(0.18, 0.18, 0.18, 1.00);
    colors[ig.ImGuiCol_TabHovered] = initImVec4(0.29, 0.62, 0.91, 1.00);
    colors[ig.ImGuiCol_TabActive] = initImVec4(0.18, 0.47, 0.91, 1.00);
    colors[ig.ImGuiCol_TabUnfocused] = initImVec4(0.14, 0.14, 0.14, 1.00);
    colors[ig.ImGuiCol_TabUnfocusedActive] = initImVec4(0.18, 0.47, 0.91, 1.00);
    colors[ig.ImGuiCol_PlotLines] = initImVec4(0.61, 0.61, 0.61, 1.00);
    colors[ig.ImGuiCol_PlotLinesHovered] = initImVec4(0.29, 0.66, 0.91, 1.00);
    colors[ig.ImGuiCol_PlotHistogram] = initImVec4(0.90, 0.70, 0.00, 1.00);
    colors[ig.ImGuiCol_PlotHistogramHovered] = initImVec4(1.00, 0.60, 0.00, 1.00);
    colors[ig.ImGuiCol_TableHeaderBg] = initImVec4(0.19, 0.19, 0.19, 1.00);
    colors[ig.ImGuiCol_TableBorderStrong] = initImVec4(0.31, 0.31, 0.35, 1.00);
    colors[ig.ImGuiCol_TableBorderLight] = initImVec4(0.23, 0.23, 0.25, 1.00);
    colors[ig.ImGuiCol_TableRowBg] = initImVec4(0.00, 0.00, 0.00, 0.00);
    colors[ig.ImGuiCol_TableRowBgAlt] = initImVec4(1.00, 1.00, 1.00, 0.06);
    colors[ig.ImGuiCol_TextSelectedBg] = initImVec4(0.29, 0.62, 0.91, 0.35);
    colors[ig.ImGuiCol_DragDropTarget] = initImVec4(0.29, 0.62, 0.91, 0.90);
    colors[ig.ImGuiCol_NavHighlight] = initImVec4(0.29, 0.62, 0.91, 1.00);
    colors[ig.ImGuiCol_NavWindowingHighlight] = initImVec4(1.00, 1.00, 1.00, 0.70);
    colors[ig.ImGuiCol_NavWindowingDimBg] = initImVec4(0.80, 0.80, 0.80, 0.20);
    colors[ig.ImGuiCol_ModalWindowDimBg] = initImVec4(0.80, 0.80, 0.80, 0.35);

    // Style adjustments
    style.*.WindowRounding = 8.0;
    style.*.FrameRounding = 4.0;
    style.*.ScrollbarRounding = 6.0;
    style.*.GrabRounding = 4.0;
    style.*.ChildRounding = 4.0;

    style.*.WindowTitleAlign = initImVec2(0.50, 0.50);
    style.*.WindowPadding = initImVec2(10.0, 10.0);
    style.*.FramePadding = initImVec2(8.0, 4.0);
    style.*.ItemSpacing = initImVec2(8.0, 8.0);
    style.*.ItemInnerSpacing = initImVec2(8.0, 6.0);
    style.*.IndentSpacing = 22.0;

    style.*.ScrollbarSize = 16.0;
    style.*.GrabMinSize = 10.0;

    style.*.AntiAliasedLines = true;
    style.*.AntiAliasedFill = true;
}

const glfw = engine.glfw;
const ig_backend = engine.ig_backend;
pub fn setMouseScrollCallback(
    win: ?*glfw.GLFWwindow,
    xoffset: f64,
    yoffset: f64,
) void {
    ig_backend.cImGui_ImplGlfw_ScrollCallback(@ptrCast(win), xoffset, yoffset);
}

pub fn setMouseButtonCallback(
    win: ?*glfw.GLFWwindow,
    c_button: c_int,
    c_action: c_int,
    mods: c_int,
) void {
    ig_backend.cImGui_ImplGlfw_MouseButtonCallback(
        @ptrCast(win),
        c_button,
        c_action,
        mods,
    );
}

pub fn setMousemovementCallback(
    win: ?*glfw.GLFWwindow,
    posx: f64,
    posy: f64,
) void {
    ig_backend.cImGui_ImplGlfw_CursorPosCallback(@ptrCast(win), posx, posy);
}

pub fn setKeyCallback(
    win: ?*glfw.GLFWwindow,
    c_key: c_int,
    c_scancode: c_int,
    c_action: c_int,
    c_mods: c_int,
) void {
    //
    ig_backend.cImGui_ImplGlfw_KeyCallback(
        @ptrCast(win),
        c_key,
        c_scancode,
        c_action,
        c_mods,
    );
}

pub fn drawCommand(name: []const u8, dc: *engine.DrawCommand) void {
    const mode_combo = comptime mode: {
        var cmb: [:0]const u8 = "";
        const fields = std.meta.fields(engine.DrawCommandMode);
        for (fields) |field| {
            cmb = cmb ++ field.name ++ "\x00";
        }
        break :mode cmb;
    };

    const type_combo = comptime typ: {
        var cmb: [:0]const u8 = "";
        const fields = std.meta.fields(engine.DrawCommandType);
        for (fields) |field| {
            cmb = cmb ++ field.name ++ "\x00";
        }
        break :typ cmb;
    };

    const alloc = engine.frameAllocator();

    var n = std.fmt.allocPrintZ(alloc, "{s} mode", .{name}) catch unreachable;
    var selected: i32 = @intFromEnum(dc.mode);
    _ = combo(n, &selected, mode_combo);
    dc.mode = @enumFromInt(selected);

    n = std.fmt.allocPrintZ(alloc, "{s} type", .{name}) catch unreachable;
    selected = @intFromEnum(dc.type);
    _ = combo(n, &selected, type_combo);
    dc.type = @enumFromInt(selected);
}
