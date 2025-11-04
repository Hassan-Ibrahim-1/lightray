const std = @import("std");
const builtin = @import("builtin");
const cimgui = @import("cimgui");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("engine", .{
        .root_source_file = b.path("src/engine.zig"),
        .target = target,
        .optimize = optimize,
    });

    const gldebug = b.option(
        bool,
        "gldebug",
        "enable extra debug check for opengl calls",
    ) orelse switch (optimize) {
        .Debug, .ReleaseSafe => true,
        else => false,
    };

    const src_files = [_][]const u8{
        dependency("stb_image.c"),
        dependency("stb_image_write.c"),
        dependency("stb_perlin.c"),
        dependency("cgltf.c"),
    };

    const flags: []const []const u8 = switch (optimize) {
        .Debug, .ReleaseSafe => &.{"-g"},
        else => &.{"-O3"},
    };

    mod.addCSourceFiles(.{
        .files = &src_files,
        .flags = flags,
    });
    mod.addIncludePath(b.path(dependency("")));

    mod.linkSystemLibrary("glfw", .{});

    const gl_bindings = @import("zigglgen").generateBindingsModule(b, .{
        .api = .gl,
        .version = if (builtin.os.tag == .macos) .@"4.1" else .@"4.6",
        .extra_debug = gldebug,
        .profile = .core,
        .extensions = &.{},
    });

    mod.addImport("gl", gl_bindings);

    mod.addCMacro("GLFW_INCLUDE_NONE", "1");

    const imgui_dep = b.dependency("cimgui", .{
        .target = target,
        .optimize = optimize,
    });
    mod.addImport("cimgui", imgui_dep.module("cimgui"));

    const imgui_config = cimgui.getConfig();
    const imgui_lib = imgui_dep.artifact(imgui_config.clib_name);
    mod.linkLibrary(imgui_lib);

    mod.addIncludePath(imgui_dep.path(imgui_config.include_dir));
    mod.addIncludePath(imgui_dep.path(imgui_config.backend_include_dir));
    addCSourceFiles(
        mod,
        &.{
            imgui_dep.path("backends/imgui_impl_opengl3.cpp"),
            imgui_dep.path("backends/dcimgui_impl_opengl3.cpp"),
            imgui_dep.path("backends/imgui_impl_glfw.cpp"),
            imgui_dep.path("backends/dcimgui_impl_glfw.cpp"),
        },
        flags,
    );

    // check
    const exe_check = b.addExecutable(.{
        .name = "engine",
        .root_module = mod,
    });
    const check = b.step("check", "Check if foo compiles");
    check.dependOn(&exe_check.step);

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });
    const run_exe_tests = b.addRunArtifact(mod_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}

fn addCSourceFiles(
    m: *std.Build.Module,
    paths: []const std.Build.LazyPath,
    flags: []const []const u8,
) void {
    for (paths) |path| {
        m.addCSourceFile(.{ .file = path, .flags = flags });
    }
}

fn dependency(comptime path: []const u8) []const u8 {
    return "dependencies/" ++ path;
}
