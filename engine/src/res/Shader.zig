const std = @import("std");
const Allocator = std.mem.Allocator;
const builtin = @import("builtin");

const options = @import("config");

const engine = @import("../engine.zig");
const Texture = engine.Texture;
const gl = engine.gl;
const debug = engine.debug;
const math = engine.math;
const Vec3 = math.Vec3;
const Vec2 = math.Vec2;
const Mat4 = math.Mat4;
const Mat3 = math.Mat3;

const log = debug.log.scoped(.Shader);
const Shader = @This();

pub const Handle = usize;

pub const Spec = struct {
    // TODO: document what thes fields actually mean, how many bind locations they
    // need, what data type they are...

    pub const BindLocation = u4;

    model: ?BindLocation,
    inverse_model: ?BindLocation,
    lighting: ?BindLocation,
    color: ?BindLocation,
    textures: bool,

    pub const none: Spec = .{
        .model = null,
        .inverse_model = null,
        .lighting = null,
        .color = null,
        .textures = false,
    };

    pub fn enabled(self: *const Spec) usize {
        var count: usize = 0;
        const fields = std.meta.fields(Spec);
        for (fields) |field| {
            if (@field(self, field.name) != null) {
                count += 1;
            }
        }
        return count;
    }
};

/// Don't mutate this
handle: c_uint,
vertex_path: []const u8,
fragment_path: []const u8,
/// This field is used by engine.renderer to automatically construct buffers
/// for the user. So for example if spec.model is true then the engine
/// gets the actor's transformation matrix and sends it to the shader
spec: Spec,

pub const Error = error{
    CompileError,
    LinkError,
} || std.fs.File.OpenError || std.Io.Writer.Error || std.Io.Reader.StreamError;

pub fn init(
    allocator: Allocator,
    vertex_path: []const u8,
    fragment_path: []const u8,
    spec: Spec,
) Error!Shader {
    const handle = gl.CreateProgram();
    try loadShader(allocator, handle, vertex_path, gl.VERTEX_SHADER);
    try loadShader(allocator, handle, fragment_path, gl.FRAGMENT_SHADER);
    try linkProgram(handle);

    return Shader{
        .handle = handle,
        .spec = spec,
        .vertex_path = vertex_path,
        .fragment_path = fragment_path,
    };
}

pub fn deinit(self: *Shader) void {
    log.info("releasing a shader with path {s}", .{self.vertex_path});
    gl.DeleteProgram(self.handle);
    self.* = undefined;
}

pub fn use(self: *const Shader) void {
    gl.UseProgram(self.handle);
}

pub fn reload(self: *Shader, alloc: Allocator) !void {
    const ReloadData = struct {
        vertex_path: []const u8,
        fragment_path: []const u8,
        spec: Spec,
    };
    const rd = ReloadData{
        .vertex_path = self.vertex_path,
        .fragment_path = self.vertex_path,
        .spec = self.spec,
    };

    self.deinit();

    self.* = try Shader.init(
        alloc,
        rd.vertex_path,
        rd.fragment_path,
        rd.spec,
    );
}

/// typ is either gl.VERTEX_SHADER or gl.FRAGMENT_SHADER
fn loadShader(
    alloc: Allocator,
    handle: c_uint,
    path: []const u8,
    typ: gl.@"enum",
) Error!void {
    const shader = gl.CreateShader(typ);
    defer gl.DeleteShader(shader);

    var file = std.fs.cwd().openFile(path, .{}) catch |err| {
        log.err("failed to open {s}", .{path});
        return err;
    };
    defer file.close();

    var buf: [64]u8 = undefined;
    var file_reader = file.reader(&buf);
    var reader = &file_reader.interface;

    var src_writer = std.Io.Writer.Allocating.init(alloc);
    defer src_writer.deinit();
    const writer = &src_writer.writer;

    if (builtin.os.tag == .macos) {
        try writer.writeAll("#version 410 core\n");
    } else {
        try writer.writeAll("#version 460 core\n");
    }

    _ = try reader.stream(writer, .unlimited);
    // shader must be null terminated
    try writer.writeByte(0);

    try writer.flush();

    gl.ShaderSource(shader, 1, &.{src_writer.written().ptr}, null);
    gl.CompileShader(shader);
    checkShaderCompilationSuccess(shader) catch |err| {
        log.err("failed to load shader at path: {s}", .{path});
        return err;
    };

    gl.AttachShader(handle, shader);
}

fn checkShaderCompilationSuccess(
    shader: c_uint,
) Error!void {
    var success: c_int = 0;
    gl.GetShaderiv(shader, gl.COMPILE_STATUS, @ptrCast(&success));
    if (success == gl.FALSE) {
        var err_log: [1024]u8 = undefined;
        gl.GetShaderInfoLog(shader, err_log.len, null, &err_log);
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
    gl.GetProgramiv(shader, gl.LINK_STATUS, @ptrCast(&success));
    if (success == gl.FALSE) {
        var err_log: [512]u8 = undefined;
        gl.GetProgramInfoLog(shader, err_log.len, null, &err_log);
        log.err(
            "Shader program link error: {s}",
            .{std.mem.sliceTo(&err_log, 0)},
        );
        return error.LinkError;
    }
}

pub fn setFloat(
    self: *Shader,
    name: [:0]const u8,
    f: f32,
) void {
    const loc = gl.GetUniformLocation(self.handle, name);
    if (self.ensureValidLoc(loc, name)) {
        gl.Uniform1f(loc, f);
    }
}

pub fn setVec3(
    self: *Shader,
    name: [:0]const u8,
    v: Vec3,
) void {
    const loc = gl.GetUniformLocation(self.handle, name);
    if (self.ensureValidLoc(loc, name)) {
        gl.Uniform3f(loc, v.x, v.y, v.z);
    }
}

pub fn setVec2(
    self: *Shader,
    name: [:0]const u8,
    v: Vec2,
) void {
    const loc = gl.GetUniformLocation(self.handle, name);
    if (self.ensureValidLoc(loc, name)) {
        gl.Uniform2f(loc, v.x, v.y);
    }
}

pub fn setMat3(
    self: *Shader,
    name: [:0]const u8,
    mat: *const Mat3,
) void {
    const loc = gl.GetUniformLocation(self.handle, name);
    if (self.ensureValidLoc(loc, name)) {
        gl.UniformMatrix3fv(loc, 1, gl.FALSE, @ptrCast(&mat.data));
    }
}

pub fn setMat4(
    self: *Shader,
    name: [:0]const u8,
    mat: *const Mat4,
) void {
    const loc = gl.GetUniformLocation(self.handle, name);
    if (self.ensureValidLoc(loc, name)) {
        gl.UniformMatrix4fv(loc, 1, gl.FALSE, @ptrCast(&mat.data));
    }
}

pub fn setInt(
    self: *Shader,
    name: [*:0]const u8,
    x: i32,
) void {
    const loc = gl.GetUniformLocation(self.handle, name);
    if (self.ensureValidLoc(loc, name)) {
        gl.Uniform1i(loc, @intCast(x));
    }
}

pub fn setUint(
    self: *Shader,
    name: [*:0]const u8,
    x: u32,
) void {
    const loc = gl.GetUniformLocation(self.handle, name);
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
    const loc = gl.GetUniformLocation(self.handle, name);

    if (self.ensureValidLoc(loc, @ptrCast(name))) {
        gl.Uniform1i(loc, @intCast(slot));
    }
}

fn ensureValidLoc(
    self: *Shader,
    loc: c_int,
    uniform_name: [*:0]const u8,
) bool {
    _ = self; // autofix
    _ = uniform_name; // autofix
    if (loc == -1) {
        // log.err(
        //     "Uniform {s} does not exist on shader with paths:\n{s}\n{s}",
        //     .{ uniform_name, self.vertex_path, self.fragment_path },
        // );
    }
    return true;
}

pub fn hasUniform(
    self: *const Shader,
    name: [*:0]const u8,
) bool {
    const loc = gl.GetUniformLocation(self.handle, name);
    return loc != -1;
}
