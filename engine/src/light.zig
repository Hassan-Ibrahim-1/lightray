const engine = @import("engine.zig");
const math = engine.math;
const Vec3 = math.Vec3;
const Color = engine.Color;
const Shader = engine.Shader;
const std = @import("std");
const Allocator = std.mem.Allocator;

pub const PointLight = struct {
    ambient: Color = Color.white,
    diffuse: Color = Color.white,
    specular: Color = Color.white,

    position: Vec3 = Vec3.zero,
    hidden: bool = false,

    pub fn sendToShader(
        self: *PointLight,
        allocator: Allocator,
        name: [*:0]const u8,
        shader: *Shader,
    ) void {
        shader.use();
        var str = std.fmt.allocPrintZ(
            allocator,
            "{s}.ambient",
            .{name},
        ) catch unreachable;
        shader.setVec3(
            str,
            self.ambient.clampedVec3(),
        );
        allocator.free(str);
        str = std.fmt.allocPrintZ(
            allocator,
            "{s}.diffuse",
            .{name},
        ) catch unreachable;
        shader.setVec3(
            str,
            self.diffuse.clampedVec3(),
        );
        allocator.free(str);
        str = std.fmt.allocPrintZ(
            allocator,
            "{s}.specular",
            .{name},
        ) catch unreachable;
        shader.setVec3(
            str,
            self.specular.clampedVec3(),
        );
        allocator.free(str);
        str = std.fmt.allocPrintZ(
            allocator,
            "{s}.position",
            .{name},
        ) catch unreachable;
        shader.setVec3(
            str,
            self.position,
        );
        allocator.free(str);
    }
};

pub const SpotLight = struct {
    ambient: Color = Color.white,
    diffuse: Color = Color.white,
    specular: Color = Color.white,

    position: Vec3 = Vec3.zero,
    direction: Vec3 = Vec3.init(0, 1, 0),
    hidden: bool = false,

    inner_cutoff: f32 = 45.0,
    outer_cutoff: f32 = 55.0,

    pub fn sendToShader(
        self: *SpotLight,
        allocator: Allocator,
        name: [*:0]const u8,
        shader: *Shader,
    ) void {
        shader.use();
        var str = std.fmt.allocPrintZ(
            allocator,
            "{s}.ambient",
            .{name},
        ) catch unreachable;
        shader.setVec3(
            str,
            self.ambient.clampedVec3(),
        );
        allocator.free(str);
        str = std.fmt.allocPrintZ(
            allocator,
            "{s}.diffuse",
            .{name},
        ) catch unreachable;
        shader.setVec3(
            str,
            self.diffuse.clampedVec3(),
        );
        allocator.free(str);
        str = std.fmt.allocPrintZ(
            allocator,
            "{s}.specular",
            .{name},
        ) catch unreachable;
        shader.setVec3(
            str,
            self.specular.clampedVec3(),
        );
        allocator.free(str);
        str = std.fmt.allocPrintZ(
            allocator,
            "{s}.position",
            .{name},
        ) catch unreachable;
        shader.setVec3(
            str,
            self.position,
        );
        allocator.free(str);
        str = std.fmt.allocPrintZ(
            allocator,
            "{s}.direction",
            .{name},
        ) catch unreachable;
        shader.setVec3(
            str,
            self.direction,
        );
        allocator.free(str);
        str = std.fmt.allocPrintZ(
            allocator,
            "{s}.inner_cutoff",
            .{name},
        ) catch unreachable;
        shader.setFloat(
            str,
            self.inner_cutoff,
        );
        allocator.free(str);
        str = std.fmt.allocPrintZ(
            allocator,
            "{s}.outer_cutoff",
            .{name},
        ) catch unreachable;
        shader.setFloat(
            str,
            self.outer_cutoff,
        );
        allocator.free(str);
    }
};

pub const DirLight = struct {
    ambient: Color = Color.white,
    diffuse: Color = Color.white,
    specular: Color = Color.white,

    position: Vec3 = Vec3.zero,
    direction: Vec3 = Vec3.init(0, 1, 0),
    hidden: bool = false,

    pub fn sendToShader(
        self: *DirLight,
        allocator: Allocator,
        name: [*:0]const u8,
        shader: *Shader,
    ) void {
        shader.use();
        var str = std.fmt.allocPrintZ(
            allocator,
            "{s}.ambient",
            .{name},
        ) catch unreachable;
        shader.setVec3(
            str,
            self.ambient.clampedVec3(),
        );
        allocator.free(str);
        str = std.fmt.allocPrintZ(
            allocator,
            "{s}.diffuse",
            .{name},
        ) catch unreachable;
        shader.setVec3(
            str,
            self.diffuse.clampedVec3(),
        );
        allocator.free(str);
        str = std.fmt.allocPrintZ(
            allocator,
            "{s}.specular",
            .{name},
        ) catch unreachable;
        shader.setVec3(
            str,
            self.specular.clampedVec3(),
        );
        allocator.free(str);
        str = std.fmt.allocPrintZ(
            allocator,
            "{s}.position",
            .{name},
        ) catch unreachable;
        shader.setVec3(
            str,
            self.position,
        );
        allocator.free(str);
        str = std.fmt.allocPrintZ(
            allocator,
            "{s}.direction",
            .{name},
        ) catch unreachable;
        shader.setVec3(
            str,
            self.direction,
        );
        allocator.free(str);
    }
};
