const std = @import("std");

const FsInfo = struct {
    font_dir: []const u8,
    shader_dir: []const u8,
    texture_dir: []const u8,
    model_dir: []const u8,
    save_dir: []const u8,
};

const Fs = @This();

info: FsInfo,

/// you must place forward slashes at the end of directory names
pub fn init(comptime fs_info: *const FsInfo) Fs {
    return Fs{
        .info = fs_info.*,
    };
}

pub fn fontPath(
    comptime self: *const Fs,
    comptime font: []const u8,
) []const u8 {
    return self.info.font_dir ++ font;
}

pub fn shaderPath(
    comptime self: *const Fs,
    comptime shader: []const u8,
) []const u8 {
    return self.info.shader_dir ++ shader;
}

pub fn texturePath(
    comptime self: *const Fs,
    comptime texture: []const u8,
) []const u8 {
    return self.info.texture_dir ++ texture ++ &[_]u8{0};
}

pub fn modelPath(
    comptime self: *const Fs,
    comptime model: []const u8,
) []const u8 {
    return self.info.model_dir ++ model;
}

pub fn savePath(
    comptime self: *const Fs,
    comptime s: []const u8,
) []const u8 {
    return self.info.save_dir ++ s;
}

test Fs {
    const expect = std.testing.expect;
    comptime {
        const fs = Fs.init(&.{
            .shader_dir = "shaders/",
            .font_dir = "fonts/",
            .texture_dir = "textures/",
            .model_dir = "models/",
            .save_dir = "save-files/",
        });
        try expect(std.mem.eql(
            u8,
            fs.shaderPath("test.vert"),
            "shaders/test.vert",
        ));
        try expect(std.mem.eql(
            u8,
            fs.fontPath("roboto.ttf"),
            "fonts/roboto.ttf",
        ));
        try expect(std.mem.eql(
            u8,
            fs.texturePath("test.jpeg"),
            "textures/test.jpeg",
        ));
        try expect(std.mem.eql(
            u8,
            fs.modelPath("model.obj"),
            "models/model.obj",
        ));
        try expect(std.mem.eql(
            u8,
            fs.savePath("save.json"),
            "save-files/save.json",
        ));
    }
}
