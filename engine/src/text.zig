const gl = @import("gl");
const std = @import("std");
const freetype = @import("freetype");
const Allocator = std.mem.Allocator;
const HashMap = std.AutoHashMap;
const engine = @import("engine.zig");
const math = engine.math;
const log = @import("log.zig");
const Shader = @import("Shader.zig");
const Mat4 = math.Mat4;
const Vec3 = math.Vec3;
const Vec2 = math.Vec2;
const Color = engine.Color;
const fs = engine.fs;

const IVec2 = struct {
    x: i32,
    y: i32,

    pub fn init(x: i32, y: i32) IVec2 {
        return IVec2{
            .x = x,
            .y = y,
        };
    }
};

const State = struct {
    allocator: Allocator,
    chars: HashMap(u8, Character),
    vao: c_uint,
    vbo: c_uint,
    proj: Mat4,
    shader: Shader,
};

var state: State = undefined;

const char_height: u32 = 48;

const Character = struct {
    handle: c_uint,
    size: IVec2,
    bearing: IVec2,
    advance: u32,
};

pub fn init(allocator: Allocator) !void {
    state.allocator = allocator;
    state.chars = HashMap(u8, Character).init(allocator);
    // try loadChars();
    return;
    // initVao();
    // try initShader();
    //
    // const window_size = engine.windowSize();
    // state.proj = Mat4.ortho(
    //     0.0,
    //     @floatFromInt(window_size.width),
    //     0.0,
    //     @floatFromInt(window_size.height),
    // );
}

pub fn deinit() void {
    state.chars.deinit();
    state.shader.deinit();
    gl.DeleteVertexArrays(1, @ptrCast(&state.vao));
    gl.DeleteBuffers(1, @ptrCast(&state.vbo));
}

/// TODO: This function is really ineffiecient
/// instead of loading 128 textures create an atlas with all textures
/// being combined into one
/// that would make text rendering faster because it'd get rid of
/// all the texture switches
fn loadChars() !void {
    const ft = try freetype.Library.init();
    defer ft.deinit();

    log.info("font path: {s}", .{fs.fontPath("Antonio-Regular.ttf")});
    const cwd = std.fs.cwd().realpathAlloc(state.allocator, ".") catch unreachable;
    defer state.allocator.free(cwd);
    log.info("cwd: {s}", .{cwd});
    const face =
        try ft.createFace(@ptrCast(fs.fontPath("Antonio-Regular.ttf")), 0);
    defer face.deinit();
    try face.setPixelSizes(0, char_height);

    gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1);

    var c: u8 = 0;
    while (c < 128) : (c += 1) {
        face.loadChar(c, .{ .render = true, .no_bitmap = false }) catch |err| {
            log.err(
                "Failed to load glyph '{c}': {s}",
                .{ c, @errorName(err) },
            );
            continue;
        };
        var texture: c_uint = 0;
        gl.GenTextures(1, @ptrCast(&texture));
        gl.BindTexture(gl.TEXTURE_2D, texture);
        gl.TexImage2D(
            gl.TEXTURE_2D,
            0,
            gl.RED,
            @intCast(face.glyph().bitmap().width()),
            @intCast(face.glyph().bitmap().rows()),
            0,
            gl.RED,
            gl.UNSIGNED_BYTE,
            @ptrCast(face.glyph().bitmap().handle.buffer),
        );
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
        // now store character for later use
        const character = Character{
            .handle = texture,
            .size = IVec2.init(
                @intCast(face.glyph().bitmap().width()),
                @intCast(face.glyph().bitmap().rows()),
            ),
            .bearing = IVec2.init(
                @intCast(face.glyph().bitmapLeft()),
                @intCast(face.glyph().bitmapTop()),
            ),
            .advance = @intCast(face.glyph().advance().x),
        };
        try state.chars.put(c, character);
    }
}

fn initVao() void {
    gl.GenVertexArrays(1, @ptrCast(&state.vao));
    gl.BindVertexArray(state.vao);

    gl.GenBuffers(1, @ptrCast(&state.vbo));
    gl.BindBuffer(gl.ARRAY_BUFFER, state.vbo);
    gl.BufferData(
        gl.ARRAY_BUFFER,
        @sizeOf(f32) * 6 * 4,
        null,
        gl.DYNAMIC_DRAW,
    );
    gl.EnableVertexAttribArray(0);
    gl.VertexAttribPointer(
        0,
        4,
        gl.FLOAT,
        gl.FALSE,
        4 * @sizeOf(f32),
        0,
    );
    gl.BindBuffer(gl.ARRAY_BUFFER, 0);
    gl.BindVertexArray(0);
}

fn initShader() !void {
    state.shader = try Shader.init(
        state.allocator,
        fs.shaderPath("text.vert"),
        fs.shaderPath("text.frag"),
    );
}

/// (0, 0) is bottom left
/// (window width, window height) is top right
/// this function enables gl.BLEND
/// make sure gl.DEPTH_TEST is enabled
pub fn renderText(
    text: []const u8,
    position: Vec2,
    scale: f32,
    color: Color,
) !void {
    gl.Enable(gl.DEPTH_TEST);
    var pos = position;

    state.shader.use();
    state.shader.setMat4("projection", &state.proj);
    state.shader.setVec3("color", color.clampedVec3());
    gl.ActiveTexture(gl.TEXTURE0);
    gl.BindVertexArray(state.vao);

    if (engine.wireframeEnabled()) {
        gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL);
    }

    for (text) |char| {
        const ch: Character = state.chars.get(char) orelse {
            log.err("unrecognized character: {c}", .{char});
            continue;
        };

        if (char == '\n') {
            pos.y -= @floatFromInt(char_height);
            continue;
        }
        defer pos.x += @as(f32, @floatFromInt((ch.advance >> 6))) * scale;

        const xpos =
            pos.x + @as(f32, @floatFromInt(ch.bearing.x)) * scale;
        const ypos =
            pos.y - @as(f32, @floatFromInt((ch.size.y - ch.bearing.y))) * scale;
        const w = @as(f32, @floatFromInt(ch.size.x)) * scale;
        const h = @as(f32, @floatFromInt(ch.size.y)) * scale;
        // update VBO for each character
        const vertices = [6][4]f32{
            [_]f32{ xpos, ypos + h, 0.0, 0.0 },
            [_]f32{ xpos, ypos, 0.0, 1.0 },
            [_]f32{ xpos + w, ypos, 1.0, 1.0 },
            [_]f32{ xpos, ypos + h, 0.0, 0.0 },
            [_]f32{ xpos + w, ypos, 1.0, 1.0 },
            [_]f32{ xpos + w, ypos + h, 1.0, 0.0 },
        };
        gl.BindTexture(gl.TEXTURE_2D, ch.handle);
        gl.BindBuffer(gl.ARRAY_BUFFER, state.vbo);
        gl.BufferSubData(
            gl.ARRAY_BUFFER,
            0,
            @sizeOf(@TypeOf(vertices)),
            &vertices,
        );
        gl.BindBuffer(gl.ARRAY_BUFFER, 0);
        gl.DrawArrays(gl.TRIANGLES, 0, 6);
    }
    gl.BindVertexArray(0);

    if (engine.wireframeEnabled()) {
        gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE);
    }
}

const Size = struct {
    width: f32,
    height: f32,
};

/// returns how many pixels the text will take up
fn textLen(str: []const u8, scale: f32) Size {
    var pos = Vec2.zero;
    for (str) |char| {
        const ch: Character = state.chars.get(char) orelse {
            log.err("unrecognized character: {c}", .{char});
            continue;
        };
        if (char == '\n') {
            pos.y -= @floatFromInt(char_height);
            continue;
        }
        pos.x += @as(f32, @floatFromInt((ch.advance >> 6))) * scale;
    }
    // const xpos =
    //     pos.x + @as(f32, @floatFromInt(ch.bearing.x)) * scale;
    // const ypos =
    //     pos.y - @as(f32, @floatFromInt((ch.size.y - ch.bearing.y))) * scale;
    return Size{
        .width = pos.x,
        .height = pos.y,
    };
}

pub fn renderTextCentered(
    text: []const u8,
    position: Vec2,
    scale: f32,
    color: Color,
) !void {
    const size = textLen(text, scale);
    const center_pos = Vec2.init(
        position.x - size.width / 8.0,
        (position.y + size.height / 2.0),
        //     f32,
        //     @floatFromInt(char_height),
        // ),
    );
    try renderText(text, center_pos, scale, color);
}

pub fn getShader() *Shader {
    return &state.shader;
}
