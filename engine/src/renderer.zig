const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;
const HashMap = std.AutoArrayHashMapUnmanaged;
const mem = std.mem;

const engine = @import("engine.zig");
const gl = engine.gl;
const res = engine.res;
const assert = engine.debug.assert;
const Actor = engine.Actor;
const Camera = engine.Camera;
const Material = engine.Material;
const fs = engine.fs;
const math = engine.math;
const Mat3 = math.Mat3;
const Skybox = engine.Skybox;
const Transform = engine.Transform;
const Vertex = engine.Vertex;
const Color = engine.Color;
const Mat4 = math.Mat4;
const Vec3 = math.Vec3;
const Billboard = engine.Billboard;
const VertexBuffer = res.VertexBuffer;
const Mesh = res.Mesh;
const Texture = res.Texture;
const Model = res.Model;
const Shader = res.Shader;
const ResourcePool = res.ResourcePool;
const Buffer = res.Buffer;
const Vec2 = math.Vec2;
const trait = engine.trait;
pub const Shapes = @import("renderer/Shapes.zig");
pub const debug = @import("renderer/debug.zig");
const meta = std.meta;

const log = engine.debug.log.scoped(.renderer);
// When adding a shader
// add it to the Shaders struct
// then to initShaders

pub const Shaders = struct {
    basic_mesh: Shader.Handle,
    basic_textured_mesh: Shader.Handle,
    light_mesh: Shader.Handle,
    light_textured_mesh: Shader.Handle,
    skybox: Shader.Handle,
    billboard: Shader.Handle,
    screen: Shader.Handle,

    pub const ShaderSpec = struct {
        name: []const u8,
        spec: Shader.Spec,
    };

    fn init(
        alloc: Allocator,
        rp: *ResourcePool,
        comptime shader_specs: []const ShaderSpec,
    ) Allocator.Error!Shaders {
        comptime std.debug.assert(shader_specs.len == meta.fields(Shaders).len);
        var ret: Shaders = undefined;

        inline for (shader_specs) |shader| {
            @field(ret, shader.name) = loadShader(
                alloc,
                rp,
                shader.name,
                shader.spec,
            ) catch |err| {
                if (err == error.OutOfMemory) {
                    return error.OutOfMemory;
                }
                log.err("Failed to load shader '{s}', reason: {t}", .{ shader.name, err });
                @panic("Failed to load shader");
            };
        }

        return ret;
    }
};

const Buffers = struct {
    billboard: struct {
        vao: c_uint,
        len: usize,
        position: Buffer.Handle,
        scale: Buffer.Handle,
        color: Buffer.Handle,

        const starting_capacity = 50;

        const Self = @This();

        pub fn init(rp: *res.ResourcePool) Allocator.Error!Self {
            var self: Self = undefined;
            self.len = 0;

            gl.GenVertexArrays(1, @ptrCast(&self.vao));
            gl.BindVertexArray(self.vao);
            defer gl.BindVertexArray(0);

            // center vec3
            var attr_count: u4 = 0;
            const pos_buf, self.position = try rp.createBuffer();
            pos_buf.*, attr_count = Buffer.init(
                Vec3,
                true,
                attr_count,
            );
            pos_buf.bind();
            pos_buf.resize(Vec3, starting_capacity, .dynamic_draw);
            pos_buf.unbind();

            // colors
            const color_buf, self.color = try rp.createBuffer();
            color_buf.*, attr_count = Buffer.init(
                Vec3,
                true,
                attr_count,
            );
            color_buf.bind();
            color_buf.resize(Vec3, starting_capacity, .dynamic_draw);
            color_buf.unbind();

            // scale float
            const scale_buf, self.scale = try rp.createBuffer();
            scale_buf.*, attr_count = Buffer.init(
                f32,
                true,
                attr_count,
            );
            scale_buf.bind();
            scale_buf.resize(f32, starting_capacity, .dynamic_draw);
            scale_buf.unbind();

            return self;
        }

        pub fn deinit(self: *Self) void {
            gl.DeleteVertexArrays(1, @ptrCast(&self.vao));
        }

        /// deletes the existing data and creates new uninitialized buffers
        pub fn resize(self: *Self, len: usize) void {
            self.len = len;
            const pos_buf = state.rp.getBuffer(self.position).?;
            pos_buf.bind();
            pos_buf.resize(Vec3, self.len, .dynamic_draw);
            pos_buf.unbind();

            const color_buf = state.rp.getBuffer(self.color).?;
            color_buf.bind();
            color_buf.resize(Vec3, self.len, .dynamic_draw);
            color_buf.unbind();

            const scale_buf = state.rp.getBuffer(self.scale).?;
            scale_buf.bind();
            scale_buf.resize(f32, self.len, .dynamic_draw);
            scale_buf.unbind();
        }

        pub fn setPositions(self: *Self, values: []const Vec3) void {
            std.debug.assert(values.len > 0 and values.len <= self.len);

            const pos_buf = state.rp.getBuffer(self.position).?;
            gl.BindBuffer(gl.ARRAY_BUFFER, pos_buf.handle);
            defer gl.BindBuffer(gl.ARRAY_BUFFER, 0);

            gl.BufferSubData(
                gl.ARRAY_BUFFER,
                0,
                pos_buf.capacity,
                @ptrCast(values),
            );
        }

        pub fn setColors(self: *Self, values: []const Vec3) void {
            std.debug.assert(values.len > 0 and values.len <= self.len);

            const color_buf = state.rp.getBuffer(self.color).?;
            gl.BindBuffer(gl.ARRAY_BUFFER, color_buf.handle);
            defer gl.BindBuffer(gl.ARRAY_BUFFER, 0);

            gl.BufferSubData(
                gl.ARRAY_BUFFER,
                0,
                color_buf.capacity,
                @ptrCast(values),
            );
        }

        pub fn setScales(self: *Self, values: []const f32) void {
            std.debug.assert(values.len > 0 and values.len <= self.len);

            const scale_buf = state.rp.getBuffer(self.scale).?;
            gl.BindBuffer(gl.ARRAY_BUFFER, scale_buf.handle);
            defer gl.BindBuffer(gl.ARRAY_BUFFER, 0);

            gl.BufferSubData(
                gl.ARRAY_BUFFER,
                0,
                scale_buf.capacity,
                @ptrCast(values),
            );
        }
    },
};

pub const RenderGroup = struct {
    mesh: *Mesh,
    shader: Shader.Handle,
    buffer: Buffer.Handle,
    diffuse_texture: ?Texture.Handle,
    specular_texture: ?Texture.Handle,

    /// `vb` is the VertexBuffer that contains `self.buffer`
    pub fn deinit(self: *RenderGroup, rp: *ResourcePool, vb: *VertexBuffer) void {
        rp.freeBuffer(self.buffer);
        // reload the vao to remove the attributes associated with the now deleted vbo
        vb.reloadVao();
    }
};

/// value is how many actors use InstanceInfo
const RenderGroups = HashMap(RenderGroup, ArrayList(*Actor));

const State = struct {
    alloc: Allocator,
    rp: *ResourcePool,
    shaders: Shaders,
    buffers: Buffers,
    fixed_buffer: [1024]u8,
    fba: std.heap.FixedBufferAllocator,

    billboards: std.MultiArrayList(Billboard),

    shapes: Shapes,

    /// cleared every frame
    render_arena: std.heap.ArenaAllocator,

    /// If this is set by the user then this is drawn to the display framebuffer
    render_texture_handle: ?usize,
    render_passes: ArrayList(RenderPass),
};

var state: State = undefined;

pub fn init(
    allocator: Allocator,
    frame_arena: Allocator,
    rp: *ResourcePool,
) !void {
    state = .{
        .alloc = allocator,
        .rp = rp,
        .render_arena = .init(state.alloc),
        .shapes = try .init(state.rp),
        .render_texture_handle = null,
        .billboards = .empty,
        .shaders = try .init(allocator, rp, &.{
            .{
                .name = "basic_mesh",
                .spec = .{
                    .model = 3,
                    .inverse_model = null,
                    .color = 7,
                    .lighting = null,
                    .textures = false,
                },
            },
            .{
                .name = "light_mesh",
                .spec = .{
                    .model = 3,
                    .inverse_model = 7,
                    .color = 10,
                    .lighting = 11,
                    .textures = false,
                },
            },
            .{
                .name = "basic_textured_mesh",
                .spec = .{
                    .model = 3,
                    .inverse_model = null,
                    .color = 7,
                    .lighting = null,
                    .textures = true,
                },
            },
            .{
                .name = "light_textured_mesh",
                .spec = .{
                    .model = 3,
                    .inverse_model = 7,
                    .color = 10,
                    .lighting = 11,
                    .textures = true,
                },
            },
            .{ .name = "skybox", .spec = .none },
            .{ .name = "screen", .spec = .none },
            .{ .name = "billboard", .spec = .none },
        }),
        .buffers = .{
            .billboard = try .init(rp),
        },
        .fixed_buffer = undefined,
        .fba = .init(&state.fixed_buffer),
        .render_passes = .empty,
    };

    // Why?
    gl.PointSize(10);

    try debug.init(frame_arena, rp);
}

pub fn deinit() void {
    deinitBuffers();
    state.billboards.deinit(state.alloc);
}

/// update buffers before rendering
fn updateBuffers() void {
    const bb_slice = state.billboards.slice();
    if (bb_slice.len > 0) {
        const bb = &state.buffers.billboard;
        if (bb_slice.len != bb.len) {
            bb.resize(bb_slice.len);
        }
        bb.setPositions(bb_slice.items(.position));
        bb.setColors(bb_slice.items(.color));
        bb.setScales(bb_slice.items(.scale));
    }
}

fn deinitBuffers() void {
    state.buffers.billboard.deinit();
    state.render_arena.deinit();
}

const LoadShaderError = Shader.Error || Allocator.Error;

fn loadShader(
    alloc: Allocator,
    rp: *ResourcePool,
    comptime name: []const u8,
    spec: Shader.Spec,
) LoadShaderError!Shader.Handle {
    const shader, const handle = try rp.createShader();
    shader.* = try .init(
        alloc,
        fs.shaderPath(name ++ ".vert"),
        fs.shaderPath(name ++ ".frag"),
        spec,
    );
    try engine.addShader(name, handle);
    return handle;
}

pub fn shaders() *Shaders {
    return &state.shaders;
}

pub fn startFrame() Allocator.Error!void {
    state.render_passes = .empty;

    const v = comptime Color.from(26).clampedVec3();
    gl.ClearColor(v.x, v.y, v.z, 1);
    gl.Clear(gl.COLOR_BUFFER_BIT);
    gl.Clear(gl.DEPTH_BUFFER_BIT);

    debug.startFrame();
}

pub fn endFrame() void {
    state.billboards.clearRetainingCapacity();
    _ = state.render_arena.reset(.retain_capacity);
    debug.endFrame();
}

const Framebuffer = res.Framebuffer;

pub const RenderPass = struct {
    pub const Spec = packed struct {
        render_actors: bool,
        render_billboards: bool,
        render_debug_shapes: bool,
        render_skybox: bool,
    };

    spec: Spec,
    actors: []Actor,
    framebuffer: Framebuffer.Handle,
    clear_color: Color,
};

pub fn render(camera: *const Camera) Allocator.Error!void {
    const view = camera.getViewMatrix();
    const proj = camera.getPerspectiveMatrix();
    setCameraMatrices(&view, &proj);

    const scene = engine.scene();

    debug.uploadDebugShapeData();
    drawLights(scene);
    updateBuffers();

    const alloc = state.render_arena.allocator();
    for (state.render_passes.items) |*pass| {
        const fb = state.rp.getFramebuffer(pass.framebuffer).?;
        fb.bind();
        defer fb.unbind();

        var render_groups = try buildRenderGroups(
            alloc,
            pass.actors,
            scene.hasLights(),
        );
        defer render_groups.deinit(alloc);
        var render_groups_iter = render_groups.iterator();

        try renderFrame(
            scene,
            null,
            &render_groups_iter,
        );
    }

    if (state.render_texture_handle) |render_texture_handle| {
        engine.disableWireframe();
        defer engine.enableWireframe();

        gl.ActiveTexture(gl.TEXTURE0);
        gl.BindTexture(gl.TEXTURE_2D, @intCast(render_texture_handle));
        const shader = state.rp.getShader(state.shaders.screen).?;

        shader.use();
        shader.setSampler("screen_texture", 0);
        const screen_mesh = state.shapes.screen;
        const vb = state.rp.getVertexBuffer(screen_mesh.vertex_buffer).?;

        vb.bind();
        renderMesh(screen_mesh.draw_mode, .{
            .draw_elements = .{
                .index_count = vb.indices.items.len,
            },
        });
    } else {
        var scene_render_groups = try buildRenderGroups(
            alloc,
            scene.actors.entries.items(.value),
            scene.hasLights(),
        );
        defer scene_render_groups.deinit(alloc);
        var render_groups_iter = scene_render_groups.iterator();
        try renderFrame(
            scene,
            null,
            &render_groups_iter,
        );
    }
}

const Scene = engine.Scene;

fn renderFrame(
    scene: *const Scene,
    spec: ?RenderPass.Spec,
    render_groups: *RenderGroups.Iterator,
) Allocator.Error!void {
    if (spec) |s| {
        _ = s; // autofix
    } else {
        try renderRenderGroups(render_groups);
        renderBillboards();

        try debug.renderDebugShapes(&state.shaders);

        if (!scene.skybox_hidden) {
            renderSkybox(&scene.skybox);
        }
    }
}

/// `alloc` is used to add to `out` render groups
fn buildRenderGroups(
    alloc: Allocator,
    actors: []Actor,
    has_lights: bool,
) Allocator.Error!RenderGroups {
    var out = RenderGroups.empty;

    for (actors) |*actor| {
        const shader = findBestShader(has_lights, &actor.render_item.material);
        for (actor.render_item.meshes.items) |*mesh| {
            const rg = RenderGroup{
                .mesh = mesh,
                .shader = shader,
                .buffer = undefined,
                .diffuse_texture = t: {
                    const dt = actor.render_item.material.diffuse_textures.items;
                    if (dt.len > 0) {
                        break :t dt[0];
                    }
                    break :t null;
                },
                .specular_texture = t: {
                    const st = actor.render_item.material.specular_textures.items;
                    if (st.len > 0) {
                        break :t st[0];
                    }
                    break :t null;
                },
            };
            const gop = try out.getOrPut(alloc, rg);
            if (!gop.found_existing) {
                gop.value_ptr.* = .empty;
            }
            try gop.value_ptr.append(alloc, actor);
        }
    }

    var iter = out.iterator();
    while (iter.next()) |kv| {
        const rg = kv.key_ptr;
        const rg_actors = kv.value_ptr.items;
        const spec = state.rp.getShader(rg.shader).?.spec;
        const buffer, const handle = try state.rp.createBuffer();

        const vb = state.rp.getVertexBuffer(rg.mesh.vertex_buffer).?;
        vb.bind();
        defer vb.unbind();

        rg.buffer = handle;
        try applyShaderSpec(alloc, &spec, rg_actors, buffer);
    }
    return out;
}

fn applyShaderSpec(
    alloc: Allocator,
    spec: *const Shader.Spec,
    actors: []const *Actor,
    buf: *Buffer,
) Allocator.Error!void {
    if (std.meta.eql(spec.*, Shader.Spec.none)) {
        return;
    }

    const size = determineSpecSize(spec);
    var data = std.ArrayList(u8).empty;
    defer data.deinit(alloc);
    try data.ensureTotalCapacityPrecise(alloc, size * actors.len);

    buf.* = .initTypeless(size);

    buf.bind();
    defer buf.unbind();

    setSpecAttributes(buf, spec);

    for (actors) |actor| {
        if (spec.model != null) {
            data.appendSliceAssumeCapacity(&mem.toBytes(actor.transform.mat4()));
        }
        if (spec.inverse_model != null) {
            const inverse = actor.transform.mat4().inverse().transpose().toMat3();
            data.appendSliceAssumeCapacity(&mem.toBytes(inverse));
        }
        if (spec.lighting != null) {
            data.appendSliceAssumeCapacity(
                &mem.toBytes(actor.render_item.material.shininess),
            );
        }
        if (spec.color != null) {
            data.appendSliceAssumeCapacity(
                &mem.toBytes(actor.render_item.material.color.clampedVec3()),
            );
        }
    }
    buf.resizeBytes(data.items.len, .dynamic_draw);
    buf.setData(u8, data.items);
}

fn setSpecAttributes(buf: *Buffer, spec: *const Shader.Spec) void {
    const offsets = determineSpecOffsets(spec);
    if (spec.model) |attr| {
        _ = buf.setAttribute(Mat4, attr, offsets.model, true);
    }
    if (spec.inverse_model) |attr| {
        _ = buf.setAttribute(Mat3, attr, offsets.inverse_model, true);
    }
    if (spec.lighting) |attr| {
        _ = buf.setAttribute(f32, attr, offsets.lighting, true);
    }
    if (spec.color) |attr| {
        _ = buf.setAttribute(Vec3, attr, offsets.color, true);
    }
}

const Offsets = struct {
    model: usize = 0,
    inverse_model: usize = 0,
    lighting: usize = 0,
    color: usize = 0,
};

/// Offsets are defined in order of fields being defined in Shader.Spec
fn determineSpecOffsets(spec: *const Shader.Spec) Offsets {
    var offsets: Offsets = .{};
    if (spec.model != null) {
        const offset = @sizeOf(Mat4);
        offsets.inverse_model += offset;
        offsets.lighting += offset;
        offsets.color += offset;
    }
    if (spec.inverse_model != null) {
        const offset = @sizeOf(Mat3);
        offsets.lighting += offset;
        offsets.color += offset;
    }
    if (spec.lighting != null) {
        const offset = @sizeOf(f32);
        offsets.color += offset;
    }
    return offsets;
}

/// returns size in bytes
fn determineSpecSize(spec: *const Shader.Spec) usize {
    var size: usize = 0;
    if (spec.model != null) {
        size += @sizeOf(Mat4);
    }
    if (spec.inverse_model != null) {
        size += @sizeOf(Mat3);
    }
    if (spec.lighting != null) {
        size += @sizeOf(f32);
    }
    if (spec.color != null) {
        size += @sizeOf(Vec3);
    }
    return size;
}

fn findBestShader(has_lights: bool, mat: *const Material) Shader.Handle {
    if (mat.shader) |s| return s;

    if (has_lights) {
        if (mat.diffuse_textures.items.len > 0) {
            return state.shaders.light_textured_mesh;
        }
        return state.shaders.light_mesh;
    }
    if (mat.diffuse_textures.items.len > 0) {
        return state.shaders.basic_textured_mesh;
    }
    return state.shaders.basic_mesh;
}

fn setCameraMatrices(view: *const Mat4, proj: *const Mat4) void {
    var iter = engine.shaders();
    while (iter.next()) |en| {
        const shader = state.rp.getShader(en.value_ptr.*).?;
        shader.use();
        // TODO: figure out a better way to do this
        // maybe another ArrayList of shaders that need camera matrices?
        if (shader.hasUniform("view")) {
            shader.setMat4("view", view);
        }
        if (shader.hasUniform("projection")) {
            shader.setMat4("projection", proj);
        }
    }
}

fn renderRenderGroups(render_groups: *RenderGroups.Iterator) Allocator.Error!void {
    while (render_groups.next()) |kv| {
        const render_group = kv.key_ptr;
        const mesh_vb = state.rp.getVertexBuffer(
            render_group.mesh.vertex_buffer,
        ).?;
        defer render_group.deinit(state.rp, mesh_vb);
        const instance_count = kv.value_ptr.items.len;
        try renderRenderGroup(render_group, instance_count, mesh_vb);
    }
}

/// `mesh_vb` should be `render_group.mesh.vertex_buffer`
pub fn renderRenderGroup(
    render_group: *const RenderGroup,
    instance_count: usize,
    mesh_vb: *VertexBuffer,
) Allocator.Error!void {
    const shader = state.rp.getShader(render_group.shader).?;
    const mesh = render_group.mesh;

    shader.use();

    if (shader.spec.lighting != null) {
        try sendLightData(shader);
    }

    if (shader.spec.textures) {
        if (render_group.diffuse_texture) |handle| {
            const t = state.rp.getTexture(handle).?;
            t.bindSlot(0);
            shader.setSampler("texture_diffuse1", 0);
        }
        if (render_group.specular_texture) |handle| {
            const t = state.rp.getTexture(handle).?;
            t.bindSlot(1);
            shader.setSampler("texture_specular1", 1);
        }
    }

    const vertex_count = mesh_vb.vertices.items.len;
    const index_count = mesh_vb.indices.items.len;

    mesh_vb.bind();

    const mode = mesh.draw_mode.as(c_uint);
    if (index_count == 0) {
        gl.DrawArraysInstanced(
            mode,
            0,
            @intCast(vertex_count),
            @intCast(instance_count),
        );
    } else {
        gl.DrawElementsInstanced(
            mode,
            @intCast(index_count),
            gl.UNSIGNED_INT,
            0,
            @intCast(instance_count),
        );
    }
}

fn renderBillboards() void {
    if (state.billboards.len == 0) return;
    const buffers = &state.buffers.billboard;
    gl.BindVertexArray(buffers.vao);
    defer gl.BindVertexArray(0);

    const shader = state.rp.getShader(state.shaders.billboard).?;
    shader.use();

    const cam = engine.camera();
    shader.setVec3("cam_right", cam.right);
    shader.setVec3("cam_up", cam.up);

    gl.DrawArraysInstanced(
        gl.TRIANGLES,
        0,
        @intCast(6 * buffers.len),
        @intCast(buffers.len),
    ); // 6 vertices per quad (two tris)
}

/// assumes `shader` is in use
fn sendTextureData(mat: *const Material, shader: *res.Shader) Allocator.Error!void {
    const fixed_alloc = state.fba.allocator();
    var i: usize = 0;
    while (i < mat.diffuse_textures.items.len) : (i += 1) {
        defer state.fba.reset();

        const texture =
            state.rp.getTexture(mat.diffuse_textures.items[i]).?;
        texture.bindSlot(i);
        const str = try std.fmt.allocPrintSentinel(
            fixed_alloc,
            "material.texture_diffuse{}",
            .{i + 1},
            0,
        );
        shader.setSampler(@ptrCast(str), i);
    }
    i = 0;
    while (i < mat.specular_textures.items.len) : (i += 1) {
        defer state.fba.reset();

        const texture =
            state.rp.getTexture(mat.specular_textures.items[i]).?;
        texture.bindSlot(i);
        const str = try std.fmt.allocPrintSentinel(
            fixed_alloc,
            "material.texture_specular{}",
            .{i + 1},
            0,
        );
        shader.setSampler(@ptrCast(str), i);
    }
}

/// assumes `shader` is in use
pub fn sendLightData(shader: *res.Shader) Allocator.Error!void {
    const scene = engine.scene();
    shader.setVec3("view_pos", engine.camera().transform.position);
    shader.setInt("n_point_lights_used", @intCast(scene.point_lights.count()));
    shader.setInt("n_spot_lights_used", @intCast(scene.spot_lights.count()));
    shader.setInt("n_dir_lights_used", @intCast(scene.dir_lights.count()));

    const fixed_alloc = state.fba.allocator();

    var p_iter = scene.point_lights.iterator();
    var i: usize = 0;
    while (p_iter.next()) |light| : (i += 1) {
        defer state.fba.reset();
        const name = try std.fmt.allocPrintSentinel(fixed_alloc, "point_lights[{}]", .{i}, 0);
        try light.value_ptr.*.sendToShader(fixed_alloc, name, shader);
    }

    var s_iter = scene.spot_lights.iterator();
    i = 0;
    while (s_iter.next()) |light| : (i += 1) {
        defer state.fba.reset();
        const name = try std.fmt.allocPrintSentinel(fixed_alloc, "spot_lights[{}]", .{i}, 0);
        try light.value_ptr.*.sendToShader(fixed_alloc, name, shader);
    }

    var d_iter = scene.dir_lights.iterator();
    i = 0;
    while (d_iter.next()) |light| : (i += 1) {
        defer state.fba.reset();
        const name = try std.fmt.allocPrintSentinel(fixed_alloc, "dir_lights[{}]", .{i}, 0);
        try light.value_ptr.*.sendToShader(fixed_alloc, name, shader);
    }
}

pub const DrawCommand = union(enum) {
    draw_arrays: struct {
        vertex_count: usize,
    },
    draw_arrays_instanced: struct {
        vertex_count: usize,
        instance_count: usize,
    },
    draw_elements: struct {
        index_count: usize,
    },
    draw_elements_instanced: struct {
        index_count: usize,
        instance_count: usize,
    },
};

/// assumes a vertex buffer is bound
/// assumes a shader is in use
/// doesn't set any shader uniforms
pub fn renderMesh(draw_mode: Mesh.DrawMode, command: DrawCommand) void {
    const mode = draw_mode.as(c_uint);
    switch (command) {
        .draw_arrays => |dc| {
            gl.DrawArrays(
                mode,
                0,
                @intCast(dc.vertex_count),
            );
        },
        .draw_elements => |dc| {
            gl.DrawElements(
                mode,
                @intCast(dc.index_count),
                gl.UNSIGNED_INT,
                0,
            );
        },
        .draw_arrays_instanced => |dc| {
            gl.DrawArraysInstanced(
                mode,
                0,
                @intCast(dc.vertex_count),
                @intCast(dc.instance_count),
            );
        },
        .draw_elements_instanced => |dc| {
            gl.DrawElementsInstanced(
                mode,
                @intCast(dc.index_count),
                gl.UNSIGNED_INT,
                0,
                @intCast(dc.instance_count),
            );
        },
    }
}

fn renderSkybox(skybox: *const Skybox) void {
    assert(skybox.loaded(), "skybox not loaded", .{});

    if (engine.wireframeEnabled()) {
        gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL);
    }

    const shader = state.rp.getShader(state.shaders.skybox).?;
    shader.use();

    skybox.bindSlot(0);
    shader.setInt("skybox", 0);

    shader.setMat4(
        "view",
        &engine
            .camera()
            .getViewMatrix()
            .toMat3()
            .toMat4(),
    );

    gl.DepthFunc(gl.LEQUAL);
    defer gl.DepthFunc(gl.LESS);

    const cube_mesh = state.shapes.cube;

    const vertex_buffer = state.rp.getVertexBuffer(cube_mesh.vertex_buffer).?;
    vertex_buffer.bind();
    defer vertex_buffer.unbind();

    renderMesh(cube_mesh.draw_mode, .{
        .draw_elements = .{
            .index_count = vertex_buffer.indices.items.len,
        },
    });

    if (engine.wireframeEnabled()) {
        gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE);
    }
}

pub fn shapes() *Shapes {
    return &state.shapes;
}

fn drawLights(scene: *const engine.Scene) void {
    const light_scale = 0.3;

    var point_iter = scene.point_lights.iterator();
    while (point_iter.next()) |kv| {
        const light = kv.value_ptr.*;

        if (!light.hidden) {
            drawBillboard(.{
                .position = light.position,
                .color = light.diffuse.clampedVec3(),
                .scale = light_scale,
            });
        }
    }

    var spot_iter = scene.spot_lights.iterator();
    while (spot_iter.next()) |kv| {
        const light = kv.value_ptr.*;
        if (!light.hidden) {
            drawBillboard(.{
                .position = light.position,
                .color = light.diffuse.clampedVec3(),
                .scale = light_scale,
            });
        }
    }

    var dir_iter = scene.dir_lights.iterator();
    while (dir_iter.next()) |kv| {
        const light = kv.value_ptr.*;
        if (!light.hidden) {
            drawBillboard(.{
                .position = light.position,
                .color = light.diffuse.clampedVec3(),
                .scale = light_scale,
            });
        }
    }
}

pub fn drawBillboard(bb: Billboard) void {
    state.billboards.append(state.alloc, bb) catch unreachable;
}

pub fn drawBillboards(billboards: []const Billboard) void {
    state.billboards.ensureTotalCapacity(
        state.alloc,
        billboards.len + state.billboards.len,
    ) catch unreachable;
    for (billboards) |bb| {
        state.billboards.appendAssumeCapacity(bb);
    }
}

pub fn addRenderPass(pass: *const RenderPass) Allocator.Error!void {
    try state.render_passes.append(state.render_arena.allocator(), pass.*);
}

/// `rt` must be the opengl handle for a texture
pub fn setRenderTexture(rt: ?usize) void {
    state.render_texture_handle = rt;
}
