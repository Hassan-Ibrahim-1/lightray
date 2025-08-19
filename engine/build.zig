const std = @import("std");
const builtin = @import("builtin");
const cimgui = @import("cimgui");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const name = "engine";
    const root_source_file = b.path("src/engine.zig");

    const engine = b.addModule(name, .{
        .root_source_file = root_source_file,
        .target = target,
        .optimize = optimize,
    });

    const ft_dep = b.dependency("mach_freetype", .{
        .target = target,
        .optimize = optimize,
    });

    const ft_mod = ft_dep.module("mach-freetype");
    engine.addImport("freetype", ft_mod);

    const src_files = [_][]const u8{
        dependency("stb_image.c"),
        dependency("stb_perlin.c"),
        dependency("cgltf.c"),
    };

    const flags: []const []const u8 = switch (optimize) {
        .Debug => &.{"-g"},
        else => &.{"-O3"},
    };

    engine.addCSourceFiles(.{
        .files = &src_files,
        .flags = flags,
    });
    engine.addIncludePath(b.path(dependency("")));

    engine.linkSystemLibrary("glfw", .{});

    // gl
    const gl_bindings = @import("zigglgen").generateBindingsModule(b, .{
        .api = .gl,
        .version = if (builtin.os.tag == .macos) .@"4.1" else .@"4.6",
        .profile = .core,
        .extensions = &.{},
    });

    engine.addImport("gl", gl_bindings);

    engine.addCMacro("GLFW_INCLUDE_NONE", "1");

    const imgui_dep = b.dependency("cimgui", .{
        .target = target,
        .optimize = optimize,
    });
    engine.addImport("cimgui", imgui_dep.module("cimgui"));

    const imgui_config = cimgui.getConfig();
    const imgui_lib = imgui_dep.artifact(imgui_config.clib_name);
    engine.linkLibrary(imgui_lib);

    engine.addIncludePath(imgui_dep.path(imgui_config.include_dir));
    engine.addIncludePath(imgui_dep.path(imgui_config.backend_include_dir));
    addCSourceFiles(
        engine,
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
        .name = name,
        .root_module = engine,
    });
    const check = b.step("check", "Check if foo compiles");
    check.dependOn(&exe_check.step);
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
