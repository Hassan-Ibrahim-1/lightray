const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const engine = @import("../engine.zig");
const res = engine.res;
const Color = engine.Color;
const Mesh = res.Mesh;
const renderer = engine.renderer;
const Transform = engine.Transform;
const math = engine.math;
const Mat4 = math.Mat4;
const Vec3 = math.Vec3;
const RenderGroup = renderer.RenderGroup;
const Shapes = renderer.Shapes;
const Buffer = res.Buffer;

const log = engine.debug.log.scoped(.@"renderer.debug");

const State = struct {
    rp: *res.ResourcePool,
    alloc: Allocator,

    /// cleared every frame
    cubes: ArrayList(CubeBufferData),
    cube_buffer: Buffer.Handle,

    arrows: ArrayList(ArrowBufferData),
    arrow_buffer: Buffer.Handle,

    // `debug` has its own shapes so that it doesn't have to reset
    // renderer's vaos
    shapes: Shapes,
};
var state: State = undefined;

/// renderer.debug doesn't free its memory. it assumes that
/// the given allocator frees memory every frame
pub fn init(
    frame_arena: Allocator,
    rp: *res.ResourcePool,
) res.Model.LoadMeshError!void {
    const shapes = try Shapes.init(rp);

    const cube_buf, const cube_buf_handle = try rp.createBuffer();
    const cube_vb = rp.getVertexBuffer(shapes.cube.vertex_buffer).?;
    cube_vb.bind();
    cube_buf.*, _ = Buffer.init(
        CubeBufferData,
        true,
        Buffer.vertex_attribute_end + 1,
    );

    const arrow_buf, const arrow_buf_handle = try rp.createBuffer();
    const arrow_vb = rp.getVertexBuffer(shapes.arrow.vertex_buffer).?;
    arrow_vb.bind();
    arrow_buf.*, _ = Buffer.init(
        ArrowBufferData,
        true,
        Buffer.vertex_attribute_end + 1,
    );

    state = .{
        .rp = rp,
        .alloc = frame_arena,

        .cubes = .empty,
        .cube_buffer = cube_buf_handle,

        .arrows = .empty,
        .arrow_buffer = arrow_buf_handle,

        .shapes = shapes,
    };
}

pub fn startFrame() void {}

pub fn endFrame() void {
    state.cubes = .empty;
    state.arrows = .empty;
}

const Scene = engine.Scene;

pub fn renderDebugShapes(
    scene: *const Scene,
    shaders: *const renderer.Shaders,
) Allocator.Error!void {
    _ = scene; // autofix
    // TODO: configure lighting data
    const shader = shaders.basic_mesh;

    try renderDebugCubes(shader);
    try renderDebugArrows(shader);
}

const Shader = res.Shader;

fn renderDebugCubes(shader: Shader.Handle) Allocator.Error!void {
    const instance_count = state.cubes.items.len;
    // log.info("instance_count: {}", .{instance_count});
    if (instance_count == 0) return;

    const vb = state.rp.getVertexBuffer(state.shapes.cube.vertex_buffer).?;
    const buf = state.rp.getBuffer(state.cube_buffer).?;
    uploadCubeData(buf);

    const render_group: RenderGroup = .{
        .shader = shader,
        .mesh = &state.shapes.cube,
        .buffer = undefined,
        .diffuse_texture = null,
        .specular_texture = null,
    };

    try renderer.renderRenderGroup(
        &render_group,
        instance_count,
        vb,
    );
}

fn renderDebugArrows(shader: Shader.Handle) Allocator.Error!void {
    const instance_count = state.arrows.items.len;
    // log.info("instance_count: {}", .{instance_count});
    if (instance_count == 0) return;

    const vb = state.rp.getVertexBuffer(state.shapes.arrow.vertex_buffer).?;
    const buf = state.rp.getBuffer(state.arrow_buffer).?;
    uploadArrowData(buf);

    const render_group: RenderGroup = .{
        .shader = shader,
        .mesh = &state.shapes.arrow,
        .buffer = undefined,
        .diffuse_texture = null,
        .specular_texture = null,
    };

    try renderer.renderRenderGroup(
        &render_group,
        instance_count,
        vb,
    );
}

fn uploadCubeData(buf: *res.Buffer) void {
    buf.bind();
    buf.resize(CubeBufferData, state.cubes.items.len, .dynamic_draw);
    buf.setData(CubeBufferData, state.cubes.items);
}

fn uploadArrowData(buf: *res.Buffer) void {
    buf.bind();
    buf.resize(ArrowBufferData, state.arrows.items.len, .dynamic_draw);
    buf.setData(ArrowBufferData, state.arrows.items);
}

pub const DrawCubeSpec = struct {
    transform: Transform,
    color: Color,
};

const CubeBufferData = extern struct {
    model: Mat4,
    color: Vec3,
};

pub const DrawArrowSpec = struct {
    start: Vec3,
    end: Vec3,
    thickness: f32,
    color: Color,
};

pub const ArrowBufferData = extern struct {
    model: Mat4,
    color: Vec3,
};

pub fn drawCube(spec: DrawCubeSpec) void {
    state.cubes.append(state.alloc, .{
        .model = spec.transform.mat4(),
        .color = spec.color.clampedVec3(),
    }) catch unreachable;
}

pub fn drawCubes(specs: []const DrawCubeSpec) void {
    state.cubes.ensureUnusedCapacity(state.alloc, specs.len) catch unreachable;
    for (specs) |spec| {
        drawCube(spec);
    }
}

pub fn drawArrow(spec: DrawArrowSpec) void {
    if (spec.start.eql(spec.end)) return;

    const arrow_vec = spec.end.sub(spec.start);
    const dir = arrow_vec.normalized();
    const length = arrow_vec.length();

    const tf: Transform = .{
        .position = spec.start.add(spec.end).divValue(2.0),
        .scale = Vec3.init(spec.thickness, spec.thickness, length / 2),
        .rotation = rotation: {
            const yaw = std.math.atan2(dir.x, dir.z);

            const horizontal_length = @sqrt(dir.x * dir.x + dir.z * dir.z);
            const pitch = -std.math.atan2(dir.y, horizontal_length);

            break :rotation Vec3.init(
                math.toDegrees(pitch),
                math.toDegrees(yaw),
                0,
            );
        },
    };

    state.arrows.append(state.alloc, .{
        .model = tf.mat4(),
        .color = spec.color.clampedVec3(),
    }) catch unreachable;
}

pub fn drawArrows(specs: []const DrawArrowSpec) void {
    state.arrows.ensureUnusedCapacity(state.alloc, specs.len) catch unreachable;
    for (specs) |spec| {
        drawArrow(spec);
    }
}

pub fn setDrawMode(mode: Mesh.DrawMode) void {
    state.shapes.setDrawMode(mode);
}
