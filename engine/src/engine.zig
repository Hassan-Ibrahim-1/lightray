const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;
const builtin = @import("builtin");

pub const gl = @import("gl");
pub const ig_raw = @import("cimgui");

pub const Actor = @import("Actor.zig");
pub const Billboard = @import("Billboard.zig");
pub const Camera = @import("Camera.zig");
pub const cast = @import("cast.zig");
pub const Color = @import("Color.zig");
pub const ComputeTexture = @import("ComputeTexture.zig");
pub const debug = @import("debug.zig");
const editor = @import("editor/editor.zig");
const Fs = @import("Fs.zig");
pub const ig = @import("imgui.zig");
pub const input = @import("input.zig");
const light = @import("light.zig");
pub const PointLight = light.PointLight;
pub const SpotLight = light.SpotLight;
pub const DirLight = light.DirLight;
const m = @import("mesh.zig");
pub const Mesh = m.Mesh;
pub const DrawCommand = m.DrawCommand;
pub const DrawCommandMode = m.DrawCommandMode;
pub const DrawCommandType = m.DrawCommandType;
pub const Material = @import("Material.zig");
pub const math = @import("math.zig");
const Vec3 = math.Vec3;
const Vec2 = math.Vec2;
pub const Model = @import("Model.zig");
pub const physics = @import("physics/physics.zig");
pub const renderer = @import("renderer/renderer.zig");
pub const RenderItem = @import("renderer/RenderItem.zig");
pub const Scene = @import("Scene.zig");
pub const Shader = @import("Shader.zig");
pub const Skybox = @import("Skybox.zig");
const text = @import("text.zig");
pub const Texture = @import("Texture.zig");
pub const Transform = @import("Transform.zig");
pub const utils = @import("utils.zig");
const Size = utils.Size;
pub const Vertex = @import("vertex.zig");
pub const VertexBuffer = @import("VertexBuffer.zig");
pub const Window = @import("Window.zig");

pub const ComputeShader = if (builtin.os.tag != .macos) val: {
    break :val @import("ComputeShader.zig");
} else val: {
    break :val {};
};
pub const String = ArrayList(u8);
pub const glfw = @cImport({
    @cDefine("GLFW_INCLUDE_NONE", "1");
    @cInclude("GLFW/glfw3.h");
});
pub const ig_backend = @cImport({
    @cInclude("dcimgui_impl_opengl3.h");
    @cInclude("dcimgui_impl_glfw.h");
});

/// use this to get access to engine resources
pub const fs = Fs.init(&.{
    .shader_dir = "engine/shaders/",
    .font_dir = "engine/fonts/",
    .texture_dir = "engine/textures/",
    .model_dir = "engine/models/",
    .save_dir = "engine/save-files/",
});

const log = debug.log.scoped(.engine);
const GPA = std.heap.DebugAllocator(.{ .safety = true });
pub const Application = struct {
    init: *const fn () anyerror!void,
    update: *const fn () anyerror!void,
    deinit: *const fn () void,
};

const EngineInitInfo = struct {
    width: u32,
    height: u32,
    name: [*:0]const u8,
};

const State = struct {
    gpa: GPA = undefined,
    alloc: Allocator = undefined,
    arena: std.heap.ArenaAllocator = undefined,
    frame_arena: std.heap.ArenaAllocator = undefined,

    window: Window = undefined,
    app: *const Application = undefined,
    last_frame_time: f32 = 0.0,
    delta_time: f32 = 0.0,
    camera: Camera = undefined,
    // used for setting a custom camera
    user_camera: ?*Camera = null,
    wireframe_enabled: bool = false,
    shaders: StringHashMap(*Shader) = undefined,
    cursor_enabled: bool = false,
    scene: Scene = undefined,
    imio: *ig_raw.ImGuiIO_t = undefined,
    clear_color: Color = undefined,
    models: ArrayList(*Model) = undefined,
};

var state = State{};

pub fn init(init_info: *const EngineInitInfo) !void {
    initAllocator();
    try initWindow(init_info);
    initCamera();
    state.shaders = StringHashMap(*Shader).init(state.arena.allocator());
    state.clear_color = .from(26);
    initScene();
    initImGui(init_info);
    state.models = .init(state.arena.allocator());

    renderer.init(state.alloc);
    input.init(state.alloc);
    try text.init(state.alloc);
    editor.init();

    // for text rendering
    gl.Enable(gl.BLEND);
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

    gl.Enable(gl.DEPTH_TEST);
}

pub fn deinit() void {
    state.app.deinit();

    editor.saveActorData(fs.savePath("save.json"));
    editor.saveLightData(fs.savePath("light_save.json"));

    input.deinit();
    text.deinit();
    renderer.deinit();
    deinitShaders();
    deinitModels();
    deinitImGui();
    state.scene.deinit();

    deinitWindow();

    state.frame_arena.deinit();
    state.arena.deinit();
    std.debug.assert(state.gpa.deinit() == .ok);
}

pub fn windowSize() Size {
    return Size{
        .width = state.window.width,
        .height = state.window.height,
    };
}

pub fn window() *Window {
    return &state.window;
}

pub fn allocator() Allocator {
    return state.alloc;
}

pub fn frameAllocator() Allocator {
    return state.frame_arena.allocator();
}

pub fn arena() Allocator {
    return state.arena.allocator();
}

pub fn deltaTime() f32 {
    return state.delta_time;
}

/// in seconds
pub fn time() f32 {
    return @floatCast(glfw.glfwGetTime());
}

pub fn camera() *Camera {
    if (state.user_camera) |cam| return cam;
    return &state.camera;
}

pub fn userShaders() *StringHashMap(*Shader) {
    return &state.shaders;
}

pub fn scene() *Scene {
    return &state.scene;
}

pub fn loadModel(path: []const u8) *Model {
    const model = state.arena.allocator().create(Model) catch unreachable;
    model.* = Model.init(state.alloc, path) catch unreachable;
    state.models.append(model) catch unreachable;
    return state.models.items[state.models.items.len - 1];
}

fn deinitModels() void {
    for (state.models.items) |model| {
        model.deinit();
    }
}

fn deinitShaders() void {
    var iter = state.shaders.valueIterator();
    while (iter.next()) |shader| {
        shader.*.deinit();
    }
}

pub fn wireframeEnabled() bool {
    return state.wireframe_enabled;
}

fn updateDeltaTime() void {
    const current_frame: f32 = @floatCast(glfw.glfwGetTime());
    state.delta_time = current_frame - state.last_frame_time;
    state.last_frame_time = current_frame;
}

fn startFrame() void {
    const v = state.clear_color.clampedVec3();
    gl.ClearColor(v.x, v.y, v.z, 1);
    gl.Clear(gl.COLOR_BUFFER_BIT);
    gl.Clear(gl.DEPTH_BUFFER_BIT);
    updateDeltaTime();

    imGuiStartFrame();
    input.startFrame();
    renderer.startFrame();
    processInput();
    // scene().skybox_hidden = true;
    // createLayout();
}

fn endFrame() void {
    input.endFrame();
    renderer.endFrame();
    imGuiEndFrame();

    state.window.swapBuffers();
    _ = state.frame_arena.reset(.retain_capacity);
}

/// added shaders will be reloaded when 'o' is pressed
/// they will be deinitalized at engine.deinit by renderer
/// DON'T deinitialize the shader yourself
pub fn addShader(name: []const u8, shader: *Shader) void {
    state.shaders.put(name, shader) catch unreachable;
}

fn update() void {
    startFrame();
    defer endFrame();

    editor.update();

    state.app.update() catch unreachable;

    renderer.render();

    updateImGui();

    debug.checkGlError();
}

pub fn run(user_app: *const Application) void {
    state.app = user_app;

    // TODO:
    // add a configuration option per actor for whether an actor created
    // in Application.init should save its data in the save file
    // editor.loadActorData(
    //     fs.savePath("save.json"),
    // ) catch |err| switch (err) {
    //     error.EmptyFile, error.FileNotFound => {},
    //     else => unreachable,
    // };
    editor.loadLightData(
        fs.savePath("light_save.json"),
    ) catch |err| switch (err) {
        error.EmptyFile, error.FileNotFound => {},
        else => unreachable,
    };

    state.app.init() catch unreachable;

    while (!state.window.shouldClose()) {
        update();
    }
}

fn initAllocator() void {
    state.gpa = .init;
    state.alloc = state.gpa.allocator();
    state.arena = .init(state.alloc);
    state.frame_arena = .init(state.alloc);
}

fn glfwErrorCallback(
    code: c_int,
    desc: [*c]const u8,
) callconv(.C) void {
    log.info("GLFW error: {} - {s}", .{ code, desc });
}

fn initWindow(init_info: *const EngineInitInfo) !void {
    if (glfw.glfwInit() == 0) return error.GlfwInitfailed;
    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MAJOR, 4);
    if (builtin.os.tag == .macos) {
        glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MINOR, 1);
    } else {
        glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MINOR, 6);
    }
    glfw.glfwWindowHint(glfw.GLFW_OPENGL_PROFILE, glfw.GLFW_OPENGL_CORE_PROFILE);
    if (builtin.os.tag == .macos) {
        glfw.glfwWindowHint(glfw.GLFW_OPENGL_FORWARD_COMPAT, 1);
    } else if (builtin.os.tag == .linux) {
        glfw.glfwWindowHint(glfw.GLFW_PLATFORM, glfw.GLFW_PLATFORM_WAYLAND);
        glfw.glfwWindowHint(glfw.GLFW_SCALE_TO_MONITOR, glfw.GLFW_TRUE);
    }

    state.window = try Window.init(
        state.alloc,
        init_info.width,
        init_info.height,
        init_info.name,
    );

    _ = glfw.glfwSetErrorCallback(glfwErrorCallback);
    state.window.enableCursor(false);
    glfw.glfwSwapInterval(0);
    // state.window.glfw_window.setInputModeCursor(.disabled);
}

fn deinitWindow() void {
    state.window.deinit();
    glfw.glfwTerminate();
}

fn initCamera() void {
    state.camera = Camera.init(Vec3.init(0, 1, 0));
}

fn initScene() void {
    state.scene = Scene.init(state.alloc);
    state.scene.loadDefaultSkybox();
}

fn initImGui(init_info: *const EngineInitInfo) void {
    log.info("loading imgui", .{});
    _ = ig_raw.igCreateContext(null);

    state.imio = @ptrCast(ig_raw.igGetIO());
    state.imio.ConfigFlags |= ig_backend.ImGuiConfigFlags_NavEnableKeyboard;
    state.imio.ConfigFlags |= ig_backend.ImGuiConfigFlags_NoMouseCursorChange;

    ig_raw.igStyleColorsDark(null);

    _ = ig_backend
        .cImGui_ImplGlfw_InitForOpenGL(@ptrCast(state.window.glfw_window), true);

    const glsl_version = if (builtin.os.tag == .macos) "#version 410" else "#version 460";
    _ = ig_backend.cImGui_ImplOpenGL3_InitEx(glsl_version);

    ig.init(state.alloc);
    ig.setMaterialYouTheme();

    // wayland scaling stuff
    if (builtin.os.tag == .linux) {
        state.imio.DisplaySize = .{
            .x = @floatFromInt(init_info.width),
            .y = @floatFromInt(init_info.height),
        };
        // ig_raw.ImGuiStyle_ScaleAllSizes(ig_raw.igGetStyle(), 1.5);
        // state.imio.FontGlobalScale = 1.5;
    }
}

fn imGuiStartFrame() void {
    ig_backend.cImGui_ImplOpenGL3_NewFrame();
    ig_backend.cImGui_ImplGlfw_NewFrame();
    ig_raw.igNewFrame();
}

fn imGuiEndFrame() void {
    ig_raw.igRender();
    ig_backend.cImGui_ImplOpenGL3_RenderDrawData(@ptrCast(ig_raw.igGetDrawData()));
}

// var f_arr = [_]f32{ 1.1, 1.2 };
// var v_test = Vec2.init(69, 420);
// var tf = Transform.initMinimum();
fn updateImGui() void {
    if (state.cursor_enabled) {
        // ig_raw.ImGui_ShowDemoWindow(null);

        // ig.begin("Hey");
        // _ = ig.dragFloat2("hey", @ptrCast(&f_arr));
        // _ = ig.dragVec2Ex("vec2", &v_test, 0.01, 0, 100);
        // _ = ig.color3("clear color", &state.clear_color);
        // _ = ig.transform("player", &tf);
        // ig.end();
    }
}

fn deinitImGui() void {
    ig_backend
        .cImGui_ImplOpenGL3_Shutdown();
    ig_backend.cImGui_ImplGlfw_Shutdown();
    ig_raw.igDestroyContext(null);
}

pub fn imGuiIo() *ig_raw.ImGuiIO_t {
    return state.imio;
}

fn enableWireframe() void {
    if (state.wireframe_enabled) return;
    gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE);
    state.wireframe_enabled = true;
}

fn disableWireframe() void {
    if (!state.wireframe_enabled) return;
    gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL);
    state.wireframe_enabled = false;
}

fn processInput() void {
    if (input.keyPressed(.one)) {
        // log.info("pressed one", .{});
        if (state.wireframe_enabled) {
            disableWireframe();
        } else {
            enableWireframe();
        }
    }
    if (input.keyPressed(.o)) {
        log.info("Reloading shaders", .{});
        text.getShader().reload() catch |err| {
            log.err(
                "Failed to reload shader: {s}",
                .{@errorName(err)},
            );
        };
        var iter = state.shaders.iterator();
        while (iter.next()) |kv| {
            const shader = kv.value_ptr.*;
            shader.reload() catch |err| {
                const name = kv.key_ptr.*;
                log.err(
                    "Failed to reload shader {s}: {s}",
                    .{ name, @errorName(err) },
                );
            };
        }
    }
    if (input.keyPressed(.two)) {
        state.cursor_enabled = !state.cursor_enabled;
        state.window.enableCursor(state.cursor_enabled);
    }
}

pub fn cursorEnabled() bool {
    return state.cursor_enabled;
}

pub fn setCursorEnabled(b: bool) void {
    state.cursor_enabled = b;
    state.window.enableCursor(b);
}

/// pass in null if you want to switch to the default engine camera
pub fn setCamera(cam: ?*Camera) void {
    state.user_camera = cam;
}

test {
    std.testing.refAllDeclsRecursive(@This());
}
