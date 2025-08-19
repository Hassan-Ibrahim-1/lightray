const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const engine = @import("engine.zig");
const log = engine.debug.log;
const fs = engine.fs;
const Mesh = engine.Mesh;
const Texture = engine.Texture;
const Vertex = engine.Vertex;
const math = engine.math;
const Vec3 = math.Vec3;
const String = engine.String;
const Vec2 = math.Vec2;

const c = @cImport({
    @cInclude("cgltf.h");
});

const Model = @This();

const Error = error{
    FileNotFound,
    IoError,
    InvalidGltf,
    Unknown,
} || Allocator.Error;

meshes: ArrayList(Mesh),
textures: ArrayList(Texture),

pub fn init(
    allocator: Allocator,
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

    var meshes = ArrayList(Mesh).init(allocator);
    var textures = ArrayList(Texture).init(allocator);
    try meshes.resize(data.meshes_count);

    for (0..data.meshes_count) |i| {
        var mesh = &meshes.items[i];
        mesh.* = Mesh.init(allocator);
        try processMesh(@ptrCast(&data.meshes[i]), mesh);
        mesh.sendData();
        mesh.createDrawCommand();
    }

    for (0..data.materials_count) |i| {
        if (processMaterial(
            allocator,
            data,
            @ptrCast(&data.materials[i]),
        )) |tex| {
            try textures.append(tex);
        }
    }

    return Model{
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
    for (self.meshes.items) |*mesh| {
        mesh.deinit();
    }
    for (self.textures.items) |*texture| {
        texture.deinit();
    }
    self.meshes.deinit();
    self.textures.deinit();
}

/// Expects an initalized Mesh
fn processMesh(mesh: *c.cgltf_mesh, out_mesh: *Mesh) Allocator.Error!void {
    //
    const vb = &out_mesh.vertex_buffer;

    for (0..mesh.primitives_count) |i| {
        const primitive = &mesh.primitives[i];

        const positions: *c.cgltf_accessor = @ptrCast(primitive.attributes[0].data);
        const vertex_count = positions.count;

        try vb.vertices.resize(vertex_count);

        for (0..vertex_count) |v| {
            _ = c.cgltf_accessor_read_float(
                @ptrCast(positions),
                v,
                @ptrCast(&vb.vertices.items[v].position.x),
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
                    @ptrCast(&vb.vertices.items[v].normal.x),
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
                    @ptrCast(&vb.vertices.items[v].uv.x),
                    3,
                );
            }
        }
        if (primitive.indices != 0) {
            const index_count = primitive.indices.*.count;
            try vb.indices.resize(index_count);
            for (0..index_count) |j| {
                const index = c.cgltf_accessor_read_index(primitive.indices, j);
                vb.indices.items[j] = @intCast(index);
            }
        }
    }
}

/// expects a non initialized texture
fn processMaterial(
    allocator: Allocator,
    data: *c.cgltf_data,
    mat: *c.cgltf_material,
) ?Texture {
    var out_tex: ?Texture = null;
    if (mat.normal_texture.texture != 0) {
        const image = mat.normal_texture.texture.*.image;
        if (image.*.uri != 0) {
            const path = getTexturePath(
                allocator,
                @ptrCast(data.file_data.?),
                image.*.uri,
            );
            defer path.deinit();
            out_tex = Texture.init(path.items);
        }
    }
    return out_tex;
}

fn cStrLen(str: [*]u8) usize {
    var len: usize = 0;
    while (str[len] != 0) : (len += 1) {}
    return len;
}

fn getTexturePath(
    allocator: Allocator,
    mp: [*]u8,
    texture_path: [*c]u8,
) String {
    var base_path = String.init(allocator);
    const len = cStrLen(mp);
    log.info("base len: {}", .{len});
    const model_path = mp[0..len];
    base_path.appendSlice((model_path)) catch unreachable;

    const last_slash = std.mem.lastIndexOf(u8, base_path.items, "/");
    var substr: []u8 = undefined;
    if (last_slash) |ls| {
        log.info("last slash: {}", .{ls});
        substr = base_path.items[0 .. ls + 1];
    } else {
        substr = "";
    }

    var ret = String.init(allocator);
    ret.appendSlice(substr) catch unreachable;
    const tp_len = cStrLen(texture_path);
    ret.appendSlice(@ptrCast(texture_path[0..tp_len])) catch unreachable;
    base_path.deinit();

    return ret;
}
