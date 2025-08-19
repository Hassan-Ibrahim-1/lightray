const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;

const engine = @import("../engine.zig");
const gl = engine.gl;
const log = engine.debug.log;
const debug = engine.debug;
const Mesh = engine.Mesh;
const assert = debug.assert;
const Actor = engine.Actor;
const Camera = engine.Camera;
const Shader = engine.Shader;
const VertexBuffer = engine.VertexBuffer;
const Material = engine.Material;
const fs = engine.fs;
const String = engine.String;
const math = engine.math;
const Mat3 = math.Mat3;
const Skybox = engine.Skybox;
const Model = engine.Model;
const Transform = engine.Transform;
const Vertex = engine.Vertex;
const Color = engine.Color;
const Mat4 = math.Mat4;
const Vec3 = math.Vec3;
const Billboard = engine.Billboard;

// When adding a shader
// add it to the Shaders struct
// then to initShaders

const Shaders = struct {
    basic_mesh: Shader,
    basic_textured_mesh: Shader,
    light_mesh: Shader,
    light_textured_mesh: Shader,
    skybox: Shader,
    wireframe: Shader,
    line: Shader,
    billboard: Shader,
};

const State = struct {
    const Buffers = struct {
        const Buffer = struct {
            handle: c_uint,

            /// how many items the buffer can hold
            capacity: isize,

            pub fn resize(self: *Buffer, cap: usize, usage: gl.@"enum") void {
                self.capacity = @intCast(cap);
                gl.BindBuffer(gl.ARRAY_BUFFER, self.handle);
                gl.BufferData(gl.ARRAY_BUFFER, self.capacity, null, usage);
            }
        };

        billboard: struct {
            vao: c_uint,
            len: usize,
            position: Buffer,
            scale: Buffer,
            color: Buffer,

            const starting_capacity = 50;

            const Self = @This();

            pub fn init(self: *Self) void {
                self.len = 0;

                gl.GenVertexArrays(1, @ptrCast(&self.vao));
                gl.BindVertexArray(self.vao);
                defer gl.BindVertexArray(0);

                // center vec3
                gl.GenBuffers(1, @ptrCast(&self.position.handle));
                gl.BindBuffer(gl.ARRAY_BUFFER, self.position.handle);

                gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, @sizeOf(Vec3), 0);
                gl.EnableVertexAttribArray(0);
                gl.VertexAttribDivisor(0, 1);

                self.position.capacity = @intCast(starting_capacity * @sizeOf(Vec3));

                gl.BufferData(
                    gl.ARRAY_BUFFER,
                    self.position.capacity,
                    null,
                    gl.DYNAMIC_DRAW,
                );

                // color vec3
                gl.GenBuffers(1, @ptrCast(&self.color.handle));
                gl.BindBuffer(gl.ARRAY_BUFFER, self.color.handle);

                gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, @sizeOf(Vec3), 0);
                gl.EnableVertexAttribArray(1);
                gl.VertexAttribDivisor(1, 1);

                self.color.capacity = @intCast(starting_capacity * @sizeOf(Vec3));

                gl.BufferData(
                    gl.ARRAY_BUFFER,
                    self.color.capacity,
                    null,
                    gl.DYNAMIC_DRAW,
                );

                // scale float
                gl.GenBuffers(1, @ptrCast(&self.scale.handle));
                gl.BindBuffer(gl.ARRAY_BUFFER, self.scale.handle);

                gl.VertexAttribPointer(2, 1, gl.FLOAT, gl.FALSE, @sizeOf(f32), 0);
                gl.EnableVertexAttribArray(2);
                gl.VertexAttribDivisor(2, 1);

                self.scale.capacity = @intCast(starting_capacity * @sizeOf(f32));

                gl.BufferData(
                    gl.ARRAY_BUFFER,
                    self.scale.capacity,
                    null,
                    gl.DYNAMIC_DRAW,
                );
            }

            pub fn deinit(self: *Self) void {
                gl.DeleteVertexArrays(1, @ptrCast(&self.vao));

                gl.DeleteBuffers(1, @ptrCast(&self.position));
                gl.DeleteBuffers(1, @ptrCast(&self.color));
                gl.DeleteBuffers(1, @ptrCast(&self.scale));
            }

            /// deletes the existing data and creates new uninitialized buffers
            pub fn resize(self: *Self, len: usize) void {
                self.len = len;
                self.position.resize(self.len * @sizeOf(Vec3), gl.DYNAMIC_DRAW);
                self.color.resize(self.len * @sizeOf(Vec3), gl.DYNAMIC_DRAW);
                self.scale.resize(self.len * @sizeOf(f32), gl.DYNAMIC_DRAW);
            }

            pub fn setPositions(self: *Self, values: []const Vec3) void {
                std.debug.assert(values.len > 0 and values.len <= self.len);

                gl.BindBuffer(gl.ARRAY_BUFFER, self.position.handle);
                defer gl.BindBuffer(gl.ARRAY_BUFFER, 0);

                gl.BufferSubData(
                    gl.ARRAY_BUFFER,
                    0,
                    self.position.capacity,
                    @ptrCast(values),
                );
            }

            pub fn setColors(self: *Self, values: []const Vec3) void {
                std.debug.assert(values.len > 0 and values.len <= self.len);

                gl.BindBuffer(gl.ARRAY_BUFFER, self.color.handle);
                defer gl.BindBuffer(gl.ARRAY_BUFFER, 0);

                gl.BufferSubData(
                    gl.ARRAY_BUFFER,
                    0,
                    self.color.capacity,
                    @ptrCast(values),
                );
            }

            pub fn setScales(self: *Self, values: []const f32) void {
                std.debug.assert(values.len > 0 and values.len <= self.len);

                gl.BindBuffer(gl.ARRAY_BUFFER, self.scale.handle);
                defer gl.BindBuffer(gl.ARRAY_BUFFER, 0);

                gl.BufferSubData(
                    gl.ARRAY_BUFFER,
                    0,
                    self.scale.capacity,
                    @ptrCast(values),
                );
            }
        },
    };
    alloc: Allocator,
    shaders: Shaders,
    camera: *Camera,
    user_shaders: *StringHashMap(*Shader),
    rect_mesh: Mesh,
    cube_model: *Model,

    buffers: Buffers,
    billboards: std.MultiArrayList(Billboard),
};

var state: State = undefined;

pub fn init(allocator: Allocator) void {
    state.alloc = allocator;
    state.billboards = .empty;
    initShaders();
    initModels();
    initBuffers();
    gl.PointSize(10);
    state.user_shaders = engine.userShaders();
}

pub fn deinit() void {
    deinitModels();
    deinitShaders();
    deinitBuffers();
    state.billboards.deinit(state.alloc);
}

pub fn initModels() void {
    state.cube_model = engine.loadModel(fs.modelPath("cube.glb"));
    initRect();
}

fn initBuffers() void {
    state.buffers.billboard.init();
}

/// update buffers before rendering
fn updateBuffers() void {
    const slice = state.billboards.slice();
    if (slice.len > 0) {
        const bb = &state.buffers.billboard;
        if (slice.len != bb.len) {
            bb.resize(slice.len);
        }
        bb.setPositions(slice.items(.position));
        bb.setColors(slice.items(.color));
        bb.setScales(slice.items(.scale));
    }
}

fn deinitBuffers() void {
    state.buffers.billboard.deinit();
}

fn initRect() void {
    const vertices = [_]Vertex{
        .fromPos(.init(0.5, 0.5, 0)),
        .fromPos(.init(0.5, -0.5, 0)),
        .fromPos(.init(-0.5, -0.5, 0)),
        .fromPos(.init(-0.5, 0.5, 0)),
    };

    const indices = [_]u32{
        0, 1, 3,
        1, 2, 3,
    };

    state.rect_mesh = .init(state.alloc);
    state
        .rect_mesh
        .vertex_buffer
        .vertices
        .appendSlice(vertices[0..]) catch unreachable;
    state
        .rect_mesh
        .vertex_buffer
        .indices
        .appendSlice(indices[0..]) catch unreachable;
    state.rect_mesh.createDrawCommand();
    state.rect_mesh.sendData();
}

fn deinitModels() void {
    state.rect_mesh.deinit();
}

fn initShaders() void {
    state.shaders.basic_mesh = Shader.init(
        state.alloc,
        fs.shaderPath("basic_mesh.vert"),
        fs.shaderPath("basic_mesh.frag"),
    ) catch {
        @panic("failed to load shader");
    };
    engine.addShader("basic_mesh", &state.shaders.basic_mesh);
    state.shaders.basic_textured_mesh = Shader.init(
        state.alloc,
        fs.shaderPath("basic_textured_mesh.vert"),
        fs.shaderPath("basic_textured_mesh.frag"),
    ) catch {
        @panic("failed to load shader");
    };
    engine.addShader("basic_textured_mesh", &state.shaders.basic_textured_mesh);

    state.shaders.light_mesh = Shader.init(
        state.alloc,
        fs.shaderPath("light_mesh.vert"),
        fs.shaderPath("light_mesh.frag"),
    ) catch {
        @panic("failed to load shader");
    };
    engine.addShader("light_mesh", &state.shaders.light_mesh);

    state.shaders.light_textured_mesh = Shader.init(
        state.alloc,
        fs.shaderPath("light_textured_mesh.vert"),
        fs.shaderPath("light_textured_mesh.frag"),
    ) catch {
        @panic("failed to load shader");
    };
    engine.addShader("light_textured_mesh", &state.shaders.light_textured_mesh);

    state.shaders.skybox = Shader.init(
        state.alloc,
        fs.shaderPath("skybox.vert"),
        fs.shaderPath("skybox.frag"),
    ) catch {
        @panic("failed to load shader");
    };
    engine.addShader("skybox", &state.shaders.skybox);

    state.shaders.wireframe = Shader.init(
        state.alloc,
        fs.shaderPath("wireframe.vert"),
        fs.shaderPath("wireframe.frag"),
    ) catch {
        @panic("failed to load shader");
    };
    engine.addShader("wireframe", &state.shaders.wireframe);

    state.shaders.line = Shader.init(
        state.alloc,
        fs.shaderPath("line.vert"),
        fs.shaderPath("line.frag"),
    ) catch {
        @panic("failed to load shader");
    };
    engine.addShader("line", &state.shaders.wireframe);

    state.shaders.billboard = Shader.init(
        state.alloc,
        fs.shaderPath("billboard.vert"),
        fs.shaderPath("billboard.frag"),
    ) catch {
        @panic("failed to load shader");
    };
    engine.addShader("billboard", &state.shaders.billboard);
}

pub fn deinitShaders() void {
    var iter = state.user_shaders.valueIterator();
    while (iter.next()) |v| {
        v.*.deinit();
    }
}

pub fn startFrame() void {}

pub fn endFrame() void {
    state.billboards.clearRetainingCapacity();
}

pub fn render() void {
    state.camera = engine.camera();

    const view = state.camera.getViewMatrix();
    const proj = state.camera.getPerspectiveMatrix();
    setCameraMatrices(&view, &proj);

    renderLights(engine.scene());

    updateBuffers();
    renderActors();
    renderBillboards();

    if (!engine.scene()._skybox_hidden) {
        renderSkybox(&engine.scene().skybox);
    }
}

fn setCameraMatrices(view: *const Mat4, proj: *const Mat4) void {
    // all renderer shaders get added to user_shaders in initShaders
    var iter = state.user_shaders.iterator();
    while (iter.next()) |en| {
        const v = en.value_ptr;
        const k = en.key_ptr.*;
        _ = k; // autofix

        const shader = v.*;
        shader.use();
        // TODO: figure out a better way to do this
        // maybe another ArrayList of shaders that need camera matrices?
        // log.info("current shader: {s}", .{k});
        if (shader.hasUniform("view")) {
            shader.setMat4("view", view);
            debug.checkGlError();
        }
        if (shader.hasUniform("projection")) {
            shader.setMat4("projection", proj);
            debug.checkGlError();
        }
    }
}

fn renderActors() void {
    const scene = engine.scene();
    var iter = scene.actors.iterator();
    if (scene.hasLights()) {
        sendLightData(&state.shaders.light_mesh);
        // sendLightData(&state.shaders.light_textured_mesh);
    }
    while (iter.next()) |actor| {
        renderActor(actor.value_ptr.*);
    }
}

fn renderBillboards() void {
    if (state.billboards.len == 0) return;
    const buffers = &state.buffers.billboard;
    gl.BindVertexArray(buffers.vao);
    defer gl.BindVertexArray(0);
    state.shaders.billboard.use();

    const cam = engine.camera();
    const shader = &state.shaders.billboard;
    shader.setVec3("cam_right", cam.right);
    shader.setVec3("cam_up", cam.up);

    gl.DrawArraysInstanced(
        gl.TRIANGLES,
        0,
        @intCast(6 * buffers.len),
        @intCast(buffers.len),
    ); // 6 vertices per quad (two tris)
}

fn renderActor(actor: *const Actor) void {
    const render_item = &actor.render_item;
    const mat = &render_item.material;
    if (render_item.hidden) return;
    const model = actor.transform.mat4();
    const scene = engine.scene();
    var shader: *Shader = undefined;
    // if (engine.wireframeEnabled()) {
    //     shader = &state.shaders.wireframe;
    //     shader.use();
    // } else
    if (mat.shader) |s| {
        shader = s;
        shader.use();
    } else if (scene.hasLights()) {
        if (mat.hasDiffuseTextures()) {
            shader = &state.shaders.light_textured_mesh;
            // sendLightData calls shader.use
            sendLightData(shader);
            sendTextureData(mat, shader);
            shader.setMat3(
                "inverse_model",
                &model.inverse().transpose().toMat3(),
            );
            shader.setFloat("material.shininess", mat.shininess);
        } else {
            shader = &state.shaders.light_mesh;
            shader.use();
            shader.setMat3(
                "inverse_model",
                &model.inverse().transpose().toMat3(),
            );
            shader.setFloat("material.shininess", mat.shininess);
        }
    } else {
        if (mat.hasDiffuseTextures()) {
            shader = &state.shaders.basic_textured_mesh;
            sendTextureData(mat, shader);
        } else {
            shader = &state.shaders.basic_mesh;
            shader.use();
        }
    }

    // TODO: this is pretty bad for performance i think?
    // figure out a better way to do this
    if (shader.hasUniform("model")) {
        shader.setMat4("model", &model);
    }
    if (shader.hasUniform("material.color")) {
        shader.setVec3("material.color", mat.color.clampedVec3());
    }
    for (render_item.meshes.items) |*mesh| {
        renderMesh(mesh);
    }
}

fn sendTextureData(mat: *const Material, shader: *Shader) void {
    shader.use();
    var i: usize = 0;
    while (i < mat.diffuseTextureCount()) : (i += 1) {
        mat.diffuse_textures.items[i].bindSlot(i);
        const str = std.fmt.allocPrintZ(
            state.alloc,
            "material.texture_diffuse{}",
            .{i + 1},
        ) catch unreachable;
        defer state.alloc.free(str);
        shader.setSampler(@ptrCast(str), i);
    }
    i = 0;
    while (i < mat.specularTextureCount()) : (i += 1) {
        mat.specular_textures.items[i].bindSlot(i);
        const str = std.fmt.allocPrintZ(
            state.alloc,
            "material.texture_specular{}",
            .{i + 1},
        ) catch unreachable;
        defer state.alloc.free(str);
        shader.setSampler(@ptrCast(str), i);
    }
}

pub fn sendLightData(shader: *Shader) void {
    const scene = engine.scene();
    shader.use();

    debug.checkGlError();
    shader.setVec3("view_pos", engine.camera().transform.position);
    shader.setInt("n_point_lights_used", @intCast(scene.pointLightCount()));
    shader.setInt("n_spot_lights_used", @intCast(scene.spotLightCount()));
    shader.setInt("n_dir_lights_used", @intCast(scene.dirLightCount()));

    var p_iter = scene.point_lights.iterator();
    var i: usize = 0;
    while (p_iter.next()) |light| : (i += 1) {
        const name = std.fmt.allocPrintZ(
            state.alloc,
            "point_lights[{}]",
            .{i},
        ) catch unreachable;
        defer state.alloc.free(name);
        light.value_ptr.*.sendToShader(state.alloc, name, shader);
    }

    var s_iter = scene.spot_lights.iterator();
    i = 0;
    while (s_iter.next()) |light| : (i += 1) {
        const name = std.fmt.allocPrintZ(
            state.alloc,
            "spot_lights[{}]",
            .{i},
        ) catch unreachable;
        defer state.alloc.free(name);
        light.value_ptr.*.sendToShader(state.alloc, name, shader);
    }

    var d_iter = scene.dir_lights.iterator();
    i = 0;
    while (d_iter.next()) |light| : (i += 1) {
        const name = std.fmt.allocPrintZ(
            state.alloc,
            "dir_lights[{}]",
            .{i},
        ) catch unreachable;
        defer state.alloc.free(name);
        light.value_ptr.*.sendToShader(state.alloc, name, shader);
    }
}

/// assumes a shader is in use
/// doesn't set any shader uniforms
pub fn renderMesh(mesh: *const Mesh) void {
    assert(mesh.buffersCreated(), "Mesh has no draw command", .{});
    const dc = mesh.draw_command.?;
    const mode: c_uint = @intCast(dc.mode.toInt());
    mesh.vertex_buffer.bind();
    defer mesh.vertex_buffer.unbind();
    switch (dc.type) {
        .draw_arrays => {
            gl.DrawArrays(
                mode,
                0,
                @intCast(dc.vertex_count),
            );
        },
        .draw_elements => {
            gl.DrawElements(
                mode,
                @intCast(dc.vertex_count),
                gl.UNSIGNED_INT,
                0,
            );
        },
        .draw_arrays_instanced => {
            gl.DrawArraysInstanced(
                mode,
                0,
                @intCast(dc.vertex_count),
                @intCast(dc.instance_count),
            );
        },
        .draw_elements_instanced => {
            gl.DrawElementsInstanced(
                mode,
                @intCast(dc.vertex_count),
                gl.UNSIGNED_INT,
                null,
                @intCast(dc.instance_count),
            );
        },

        // else => {
        //     log.err(
        //         "draw command type {s} not supported",
        //         .{@tagName(dc.type)},
        //     );
        // },
    }
}

fn renderSkybox(skybox: *Skybox) void {
    assert(skybox.loaded(), "skybox not loaded", .{});

    if (engine.wireframeEnabled()) {
        gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL);
    }

    const shader = &state.shaders.skybox;
    shader.use();
    gl.ActiveTexture(gl.TEXTURE0);
    shader.setInt("skybox", 0);
    shader.setMat4(
        "view",
        &engine
            .camera()
            .getViewMatrix()
            .toMat3()
            .toMat4(),
    );
    gl.BindTexture(gl.TEXTURE_CUBE_MAP, skybox.handle);

    gl.DepthFunc(gl.LEQUAL);
    defer gl.DepthFunc(gl.LESS);

    const mesh = state.cube_model.meshes.items[0];
    renderMesh(&mesh);

    if (engine.wireframeEnabled()) {
        gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE);
    }
}

pub fn cubeModel() *Model {
    return state.cube_model;
}

pub fn rectMesh() *Mesh {
    return &state.rect_mesh;
}

pub fn getCameraMatrices() struct { proj: Mat4, view: Mat4 } {
    return .{
        .proj = state.camera.getPerspectiveMatrix(),
        .view = state.camera.getViewMatrix(),
    };
}

pub fn drawRay(ray: *const math.Ray, t: f32) void {
    const p1 = ray.origin;
    const p2 = ray.at(t);

    var vb = VertexBuffer.init(state.alloc);
    defer vb.deinit();
    vb.vertices.appendSlice(&.{
        .fromPos(p1),
        .fromPos(p2),
    }) catch unreachable;
    vb.sendVertexData();

    vb.bind();
    defer vb.unbind();

    state.shaders.line.use();
    gl.DrawArrays(gl.LINES, 0, 2);
}

pub fn drawQuad(
    tf: *const Transform,
    color: Color,
    fill: bool,
) void {
    const shader = &state.shaders.basic_mesh;
    shader.use();
    shader.setMat4("model", &tf.mat4());
    shader.setVec3("material.color", color.clampedVec3());

    const dc = &state.rect_mesh.draw_command.?;
    if (fill) {
        dc.mode = .triangles;
        dc.type = .draw_elements;
        dc.vertex_count = 6;
    } else {
        dc.mode = .line_loop;
        dc.type = .draw_arrays;
        dc.vertex_count = 4;
    }

    renderMesh(&state.rect_mesh);
}

fn renderLights(scene: *const engine.Scene) void {
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
    state.billboards.ensureTotalCapacity(state.alloc, billboards.len) catch unreachable;
    for (billboards) |bb| {
        state.billboards.appendAssumeCapacity(bb);
    }
}
