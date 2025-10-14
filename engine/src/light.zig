const std = @import("std");
const Allocator = std.mem.Allocator;

const engine = @import("engine.zig");
const math = engine.math;
const Vec3 = math.Vec3;
const Color = engine.Color;
const res = engine.res;

pub const PointLight = struct {
    ambient: Color = Color.white,
    diffuse: Color = Color.white,
    specular: Color = Color.white,

    position: Vec3 = Vec3.zero,
    hidden: bool = false,

    pub fn sendToShader(
        self: *PointLight,
        alloc: Allocator,
        name: [*:0]const u8,
        shader: *res.Shader,
    ) Allocator.Error!void {
        shader.use();
        var str = try std.fmt.allocPrintSentinel(
            alloc,
            "{s}.ambient",
            .{name},
            0,
        );
        shader.setVec3(
            str,
            self.ambient.clampedVec3(),
        );
        alloc.free(str);
        str = try std.fmt.allocPrintSentinel(
            alloc,
            "{s}.diffuse",
            .{name},
            0,
        );
        shader.setVec3(
            str,
            self.diffuse.clampedVec3(),
        );
        alloc.free(str);
        str = try std.fmt.allocPrintSentinel(
            alloc,
            "{s}.specular",
            .{name},
            0,
        );
        shader.setVec3(
            str,
            self.specular.clampedVec3(),
        );
        alloc.free(str);
        str = try std.fmt.allocPrintSentinel(
            alloc,
            "{s}.position",
            .{name},
            0,
        );
        shader.setVec3(
            str,
            self.position,
        );
        alloc.free(str);
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
        alloc: Allocator,
        name: [*:0]const u8,
        shader: *res.Shader,
    ) Allocator.Error!void {
        shader.use();
        var str = try std.fmt.allocPrintSentinel(
            alloc,
            "{s}.ambient",
            .{name},
            0,
        );
        shader.setVec3(
            str,
            self.ambient.clampedVec3(),
        );
        alloc.free(str);
        str = try std.fmt.allocPrintSentinel(
            alloc,
            "{s}.diffuse",
            .{name},
            0,
        );
        shader.setVec3(
            str,
            self.diffuse.clampedVec3(),
        );
        alloc.free(str);
        str = try std.fmt.allocPrintSentinel(
            alloc,
            "{s}.specular",
            .{name},
            0,
        );
        shader.setVec3(
            str,
            self.specular.clampedVec3(),
        );
        alloc.free(str);
        str = try std.fmt.allocPrintSentinel(
            alloc,
            "{s}.position",
            .{name},
            0,
        );
        shader.setVec3(
            str,
            self.position,
        );
        alloc.free(str);
        str = try std.fmt.allocPrintSentinel(
            alloc,
            "{s}.direction",
            .{name},
            0,
        );
        shader.setVec3(
            str,
            self.direction,
        );
        alloc.free(str);
        str = try std.fmt.allocPrintSentinel(
            alloc,
            "{s}.inner_cutoff",
            .{name},
            0,
        );
        shader.setFloat(
            str,
            self.inner_cutoff,
        );
        alloc.free(str);
        str = try std.fmt.allocPrintSentinel(
            alloc,
            "{s}.outer_cutoff",
            .{name},
            0,
        );
        shader.setFloat(
            str,
            self.outer_cutoff,
        );
        alloc.free(str);
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
        alloc: Allocator,
        name: [*:0]const u8,
        shader: *res.Shader,
    ) Allocator.Error!void {
        shader.use();
        var str = try std.fmt.allocPrintSentinel(
            alloc,
            "{s}.ambient",
            .{name},
            0,
        );
        shader.setVec3(
            str,
            self.ambient.clampedVec3(),
        );
        alloc.free(str);
        str = try std.fmt.allocPrintSentinel(
            alloc,
            "{s}.diffuse",
            .{name},
            0,
        );
        shader.setVec3(
            str,
            self.diffuse.clampedVec3(),
        );
        alloc.free(str);
        str = try std.fmt.allocPrintSentinel(
            alloc,
            "{s}.specular",
            .{name},
            0,
        );
        shader.setVec3(
            str,
            self.specular.clampedVec3(),
        );
        alloc.free(str);
        str = try std.fmt.allocPrintSentinel(
            alloc,
            "{s}.position",
            .{name},
            0,
        );
        shader.setVec3(
            str,
            self.position,
        );
        alloc.free(str);
        str = try std.fmt.allocPrintSentinel(
            alloc,
            "{s}.direction",
            .{name},
            0,
        );
        shader.setVec3(
            str,
            self.direction,
        );
        alloc.free(str);
    }
};
