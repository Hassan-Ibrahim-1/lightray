const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const engine = @import("../engine.zig");
const log = engine.debug.log;
const fs = engine.fs;
const res = engine.res;
const Vertex = engine.Vertex;
const math = engine.math;
const Vec3 = math.Vec3;
const Vec2 = math.Vec2;
const Mesh = res.Mesh;

const c = @cImport({
    @cInclude("cgltf.h");
});

const Model = @This();

pub const Handle = enum(usize) {
    _,
    pub const zero: Handle = @enumFromInt(0);
};

pub const Error = error{
    FileNotFound,
    IoError,
    InvalidGltf,
    Unknown,
} || Allocator.Error;

alloc: Allocator,
meshes: ArrayList(Mesh),
textures: ArrayList(res.Texture.Handle),

pub fn init(
    alloc: Allocator,
    rp: *res.ResourcePool,
    path: []const u8,
) Error!Model {
    const options: c.cgltf_options = .{};
    var data: *c.cgltf_data = undefined;
    var result = c.cgltf_parse_file(
        &options,
        @ptrCast(path),
        @ptrCast(&data),
    );
    if (result != c.cgltf_result_success) {
        return intToError(result);
    }
    defer c.cgltf_free(data);
    // log.info("file loaded", .{});
    result = c.cgltf_load_buffers(
        &options,
        @ptrCast(data),
        @ptrCast(path),
    );
    if (result != c.cgltf_result_success) {
        return intToError(result);
    }

    var meshes = ArrayList(Mesh).empty;
    errdefer meshes.deinit(alloc);
    var textures = ArrayList(res.Texture.Handle).empty;
    errdefer textures.deinit(alloc);

    try meshes.resize(alloc, data.meshes_count);

    for (0..data.meshes_count) |i| {
        const vb, const vb_handle = try rp.createVertexBuffer();
        vb.* = .init(alloc);
        errdefer rp.freeVertexBuffer(vb_handle);

        try processMesh(@ptrCast(&data.meshes[i]), vb);
        vb.sendData();
        meshes.items[i] = Mesh.init(vb_handle, vb.vertices.items);
    }

    for (0..data.materials_count) |i| {
        const path_opt = try processMaterial(
            alloc,
            data,
            @ptrCast(&data.materials[i]),
        );
        if (path_opt) |p| {
            defer alloc.free(p);
            const tex, const handle = try rp.createTexture();
            tex.* = .init(p);
            try textures.append(alloc, handle);
        }
    }

    return Model{
        .alloc = alloc,
        .meshes = meshes,
        .textures = textures,
    };
}

fn intToError(int: c_uint) Error {
    switch (int) {
        c.cgltf_result_file_not_found => {
            return Error.FileNotFound;
        },
        c.cgltf_result_io_error => {
            return Error.IoError;
        },
        c.cgltf_result_invalid_gltf => {
            return Error.InvalidGltf;
        },
        c.cgltf_result_out_of_memory => {
            return Error.OutOfMemory;
        },
        else => {
            return Error.Unknown;
        },
    }
}

pub fn deinit(self: *Model) void {
    self.meshes.deinit(self.alloc);
    self.textures.deinit(self.alloc);
}

fn processMesh(mesh: *c.cgltf_mesh, out_vb: *res.VertexBuffer) Allocator.Error!void {
    for (0..mesh.primitives_count) |i| {
        const primitive = &mesh.primitives[i];

        const positions: *c.cgltf_accessor = @ptrCast(primitive.attributes[0].data);
        const vertex_count = positions.count;

        try out_vb.vertices.resize(out_vb.alloc, vertex_count);

        for (0..vertex_count) |v| {
            _ = c.cgltf_accessor_read_float(
                @ptrCast(positions),
                v,
                @ptrCast(&out_vb.vertices.items[v].position.x),
                3,
            );
            // vb.vertices.append(Vertex.fromPos(vec3FromArr(&v_arr))) catch unreachable;
        }

        const normals: ?*c.cgltf_accessor = norm: {
            for (0..primitive.attributes_count) |j| {
                if (primitive.attributes[j].type == c.cgltf_attribute_type_normal) {
                    break :norm primitive.attributes[j].data;
                }
            }
            break :norm null;
        };
        if (normals) |norms| {
            for (0..vertex_count) |v| {
                _ = c.cgltf_accessor_read_float(
                    @ptrCast(norms),
                    v,
                    @ptrCast(&out_vb.vertices.items[v].normal.x),
                    3,
                );
            }
        }

        const tex_coords: ?*c.cgltf_accessor = tc: {
            for (0..primitive.attributes_count) |j| {
                if (primitive.attributes[j].type == c.cgltf_attribute_type_texcoord) {
                    break :tc primitive.attributes[j].data;
                }
            }
            break :tc null;
        };
        if (tex_coords) |uv| {
            for (0..vertex_count) |v| {
                _ = c.cgltf_accessor_read_float(
                    @ptrCast(uv),
                    v,
                    @ptrCast(&out_vb.vertices.items[v].uv.x),
                    3,
                );
            }
        }
        if (primitive.indices != 0) {
            const index_count = primitive.indices.*.count;
            try out_vb.indices.resize(out_vb.alloc, index_count);
            for (0..index_count) |j| {
                const index = c.cgltf_accessor_read_index(primitive.indices, j);
                out_vb.indices.items[j] = @intCast(index);
            }
        }
    }
}

/// returns an optional owned path to the texture
fn processMaterial(
    alloc: Allocator,
    data: *c.cgltf_data,
    mat: *c.cgltf_material,
) Allocator.Error!?[]u8 {
    if (mat.normal_texture.texture != 0) {
        const image = mat.normal_texture.texture.*.image;
        if (image.*.uri != 0) {
            return try getTexturePath(
                alloc,
                @ptrCast(data.file_data.?),
                image.*.uri,
            );
        }
    }
    return null;
}

fn cStrLen(str: [*]u8) usize {
    var len: usize = 0;
    while (str[len] != 0) : (len += 1) {}
    return len;
}

fn getTexturePath(
    alloc: Allocator,
    mp: [*]u8,
    texture_path: [*c]u8,
) Allocator.Error![]u8 {
    var base_path = ArrayList(u8).empty;
    defer base_path.deinit(alloc);

    const len = cStrLen(mp);
    const model_path = mp[0..len];
    try base_path.appendSlice(alloc, model_path);

    const last_slash = std.mem.lastIndexOf(u8, base_path.items, "/");
    var substr: []u8 = undefined;
    if (last_slash) |ls| {
        substr = base_path.items[0 .. ls + 1];
    } else {
        substr = "";
    }

    var ret = ArrayList(u8).empty;
    try ret.appendSlice(alloc, substr);
    const tp_len = cStrLen(texture_path);
    try ret.appendSlice(alloc, @ptrCast(texture_path[0..tp_len]));

    return ret.toOwnedSlice(alloc);
}

pub const LoadMeshError = error{ExpectedOneMesh} || Error;

pub fn loadMesh(
    alloc: Allocator,
    rp: *res.ResourcePool,
    path: []const u8,
) LoadMeshError!Mesh {
    const options: c.cgltf_options = .{};
    var data: *c.cgltf_data = undefined;
    var result = c.cgltf_parse_file(
        &options,
        @ptrCast(path),
        @ptrCast(&data),
    );
    if (result != c.cgltf_result_success) {
        return intToError(result);
    }
    defer c.cgltf_free(data);
    // log.info("file loaded", .{});
    result = c.cgltf_load_buffers(
        &options,
        @ptrCast(data),
        @ptrCast(path),
    );
    if (result != c.cgltf_result_success) {
        return intToError(result);
    }

    if (data.meshes_count > 1) {
        return error.ExpectedOneMesh;
    }

    const vb, const vb_handle = try rp.createVertexBuffer();
    vb.* = .init(alloc);
    errdefer rp.freeVertexBuffer(vb_handle);
    try processMesh(@ptrCast(&data.meshes[0]), vb);
    vb.sendData();
    return Mesh.init(vb_handle, vb.vertices.items);
}
