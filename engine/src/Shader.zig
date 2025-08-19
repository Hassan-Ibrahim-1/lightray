const std = @import("std");
const gl = @import("gl");
const debug = @import("debug.zig");
const log = debug.log.Scoped(.Shader);
const Allocator = std.mem.Allocator;
const math = @import("math.zig");
const Vec3 = math.Vec3;
const Vec2 = math.Vec2;
const Mat4 = math.Mat4;
const Mat3 = math.Mat3;
const engine = @import("engine.zig");
const Texture = engine.Texture;
const builtin = @import("builtin");

const Shader = @This();

allocator: Allocator,
/// Don't mutate this
id: c_uint,
vertex_path: []const u8,
fragment_path: []const u8,

pub const Error = error{
    CompileError,
    LinkError,
} || std.fs.File.OpenError;

pub fn init(
    allocator: Allocator,
    vertex_path: []const u8,
    fragment_path: []const u8,
) Error!Shader {
    const id = gl.CreateProgram();
    try loadShader(allocator, id, vertex_path, gl.VERTEX_SHADER);
    try loadShader(allocator, id, fragment_path, gl.FRAGMENT_SHADER);
    try linkProgram(id);

    return Shader{
        .allocator = allocator,
        .id = id,
        .vertex_path = vertex_path,
        .fragment_path = fragment_path,
    };
}

pub fn deinit(self: *Shader) void {
    gl.DeleteProgram(self.id);
}

pub fn use(self: *const Shader) void {
    gl.UseProgram(self.id);
}

pub fn reload(self: *Shader) !void {
    self.deinit();
    self.* = try Shader.init(
        self.allocator,
        self.vertex_path,
        self.fragment_path,
    );
}

/// typ is either gl.VERTEX_SHADER or gl.FRAGMENT_SHADER
fn loadShader(
    allocator: Allocator,
    id: c_uint,
    path: []const u8,
    typ: comptime_int,
) Error!void {
    const shader = gl.CreateShader(typ);
    defer gl.DeleteShader(shader);

    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var reader = buf_reader.reader();

    var src = std.ArrayList(u8).init(allocator);
    defer src.deinit();

    if (builtin.os.tag == .macos) {
        src.appendSlice("#version 410 core\n") catch unreachable;
    } else {
        src.appendSlice("#version 460 core\n") catch unreachable;
    }

    reader.readAllArrayList(&src, 100000) catch unreachable;
    // shader must be null terminated
    src.append(0) catch unreachable;

    gl.ShaderSource(shader, 1, @ptrCast(&src), null);
    gl.CompileShader(shader);
    checkShaderCompilationSuccess(shader) catch |err| {
        log.err("failed to load shader at path: {s}", .{path});
        return err;
    };

    gl.AttachShader(id, shader);
}

fn checkShaderCompilationSuccess(
    shader: c_uint,
) Error!void {
    var success: c_int = 0;
    gl.GetShaderiv(shader, gl.COMPILE_STATUS, &success);
    if (success == gl.FALSE) {
        var err_log: [512]u8 = undefined;
        gl.GetShaderInfoLog(shader, 512, null, &err_log);
        log.err(
            "Shader compilation error: {s}",
            .{std.mem.sliceTo(&err_log, 0)},
        );
        return error.CompileError;
    }
}

fn linkProgram(shader: c_uint) Error!void {
    gl.LinkProgram(shader);
    var success: c_int = 0;
    gl.GetProgramiv(shader, gl.LINK_STATUS, &success);
    if (success == gl.FALSE) {
        var err_log: [512]u8 = undefined;
        gl.GetProgramInfoLog(shader, err_log.len, null, &err_log);
        log.err(
            "Shader program link error: {s}",
            .{std.mem.sliceTo(&err_log, 0)},
        );
        debug.checkGlError();
        return error.LinkError;
    }
}

pub fn setFloat(
    self: *Shader,
    name: [:0]const u8,
    f: f32,
) void {
    const loc = gl.GetUniformLocation(self.id, name);
    if (self.ensureValidLoc(loc, name)) {
        gl.Uniform1f(loc, f);
    }
}

pub fn setVec3(
    self: *Shader,
    name: [:0]const u8,
    v: Vec3,
) void {
    const loc = gl.GetUniformLocation(self.id, name);
    if (self.ensureValidLoc(loc, name)) {
        gl.Uniform3f(loc, v.x, v.y, v.z);
    }
}

pub fn setVec2(
    self: *Shader,
    name: [:0]const u8,
    v: Vec2,
) void {
    const loc = gl.GetUniformLocation(self.id, name);
    if (self.ensureValidLoc(loc, name)) {
        gl.Uniform2f(loc, v.x, v.y);
    }
}

pub fn setMat3(
    self: *Shader,
    name: [:0]const u8,
    mat: *const Mat3,
) void {
    const loc = gl.GetUniformLocation(self.id, name);
    if (self.ensureValidLoc(loc, name)) {
        gl.UniformMatrix3fv(loc, 1, gl.FALSE, &mat.data);
    }
}

pub fn setMat4(
    self: *Shader,
    name: [:0]const u8,
    mat: *const Mat4,
) void {
    const loc = gl.GetUniformLocation(self.id, name);
    if (self.ensureValidLoc(loc, name)) {
        gl.UniformMatrix4fv(loc, 1, gl.FALSE, &mat.data);
    }
}

pub fn setInt(
    self: *Shader,
    name: [*:0]const u8,
    x: i32,
) void {
    debug.checkGlError();
    const loc = gl.GetUniformLocation(self.id, name);
    if (self.ensureValidLoc(loc, name)) {
        gl.Uniform1i(loc, @intCast(x));
    }
}

pub fn setUint(
    self: *Shader,
    name: [*:0]const u8,
    x: u32,
) void {
    const loc = gl.GetUniformLocation(self.id, name);
    if (self.ensureValidLoc(loc, name)) {
        gl.Uniform1ui(loc, @intCast(x));
    }
}

/// same as setInt
/// DO NOT PASS IN THE TEXTURE HANDLE
/// rather pass in the slot that the texture is bound to
pub fn setSampler(
    self: *Shader,
    name: [*:0]const u8,
    slot: usize,
) void {
    const loc = gl.GetUniformLocation(self.id, name);

    if (self.ensureValidLoc(loc, @ptrCast(name))) {
        gl.Uniform1i(loc, @intCast(slot));
    }
}

fn ensureValidLoc(
    self: *Shader,
    loc: c_int,
    uniform_name: [*:0]const u8,
) bool {
    if (loc == -1) {
        log.err(
            "Uniform {s} does not exist on shader with paths:\n{s}\n{s}",
            .{ uniform_name, self.vertex_path, self.fragment_path },
        );
        return false;
        // @panic("Bad uniform name");
    }
    return true;
}

pub fn hasUniform(
    self: *const Shader,
    name: [*:0]const u8,
) bool {
    const loc = gl.GetUniformLocation(self.id, name);
    return loc != -1;
}
