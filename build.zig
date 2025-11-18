const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const engine_dep = b.dependency("engine", .{
        .target = target,
        .optimize = optimize,
        .gldebug = true,
    });
    const engine_mod = engine_dep.module("engine");

    const mod = b.createModule(
        .{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{
                    .name = "engine",
                    .module = engine_mod,
                },
            },
        },
    );

    const use_llvm = b.option(
        bool,
        "llvm",
        "force compilation using llvm",
    ) orelse true;

    const use_engine = b.option(
        bool,
        "engine",
        "open raytraced image in engine, otherwise saved to render_out",
    ) orelse true;

    const render_out = b.option(
        []const u8,
        "render_out",
        "output of raytracer if use_engine is disabled. default is <render.png>",
    ) orelse "render.png";

    const emit_bin = b.option(
        bool,
        "emit_bin",
        "emit a binary",
    ) orelse true;

    const opts = b.addOptions();
    opts.addOption(bool, "use_engine", use_engine);
    opts.addOption([]const u8, "render_out", render_out);

    mod.addOptions("opts", opts);

    const exe = b.addExecutable(.{
        .name = "lightray",
        .root_module = mod,
        .use_llvm = use_llvm,
    });

    if (emit_bin) {
        b.installArtifact(exe);
    } else {
        b.getInstallStep().dependOn(&exe.step);
    }

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}
