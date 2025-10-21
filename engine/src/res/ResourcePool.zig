//! Never store pointers to resources since they can be invalidated, store the
//! handles instead

const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;
const HashMap = std.AutoHashMapUnmanaged;
const builtin = @import("builtin");

const res = @import("../res.zig");
const Mesh = res.Mesh;
const Texture = res.Texture;
const Shader = res.Shader;
const Model = res.Model;
const VertexBuffer = res.VertexBuffer;
const ComputeShader = res.ComputeShader;
const ComputeTexture = res.ComputeTexture;
const Buffer = res.Buffer;

const log = std.log.scoped(.s);

alloc: Allocator,
textures: HashMap(Texture.Handle, Texture),
shaders: HashMap(Shader.Handle, Shader),
models: HashMap(Model.Handle, Model),
vertex_buffers: HashMap(VertexBuffer.Handle, VertexBuffer),
buffers: HashMap(Buffer.Handle, Buffer),

handles: struct {
    texture: usize = 0,
    shader: usize = 0,
    model: usize = 0,
    vertex_buffer: usize = 0,
    buffer: usize = 0,
},

free_list_arena: switch (builtin.mode) {
    .Debug, .ReleaseSafe => std.heap.ArenaAllocator,
    else => void,
},

free_list: switch (builtin.mode) {
    .Debug, .ReleaseSafe => struct {
        textures: ArrayList(Texture.Handle) = .empty,
        shaders: ArrayList(Shader.Handle) = .empty,
        models: ArrayList(Model.Handle) = .empty,
        vertex_buffers: ArrayList(VertexBuffer.Handle) = .empty,
        buffers: ArrayList(Buffer.Handle) = .empty,
    },
    else => void,
},

const ResourcePool = @This();

pub fn init(alloc: Allocator) ResourcePool {
    return .{
        .alloc = alloc,
        .textures = .empty,
        .shaders = .empty,
        .models = .empty,
        .vertex_buffers = .empty,
        .buffers = .empty,
        .handles = .{},

        .free_list = switch (builtin.mode) {
            .Debug, .ReleaseSafe => .{},
            else => {},
        },
        .free_list_arena = switch (builtin.mode) {
            .Debug, .ReleaseSafe => .init(alloc),
            else => {},
        },
    };
}

pub fn deinit(self: *ResourcePool) void {
    var texture_iter = self.textures.valueIterator();
    while (texture_iter.next()) |t| {
        t.deinit();
    }
    self.textures.deinit(self.alloc);

    var shader_iter = self.shaders.valueIterator();
    while (shader_iter.next()) |s| {
        s.deinit();
    }
    self.shaders.deinit(self.alloc);

    var model_iter = self.models.valueIterator();
    while (model_iter.next()) |m| {
        m.deinit();
    }
    self.models.deinit(self.alloc);

    var vb_iter = self.vertex_buffers.valueIterator();
    while (vb_iter.next()) |vb| {
        vb.deinit();
    }
    self.vertex_buffers.deinit(self.alloc);

    var buf_iter = self.buffers.valueIterator();
    while (buf_iter.next()) |b| {
        b.deinit();
    }
    self.buffers.deinit(self.alloc);

    switch (builtin.mode) {
        .Debug, .ReleaseSafe => self.free_list_arena.deinit(),
        else => {},
    }

    self.* = undefined;
}

pub fn createTexture(
    self: *ResourcePool,
) Allocator.Error!struct { *Texture, Texture.Handle } {
    defer self.handles.texture += 1;
    const handle: Texture.Handle = @enumFromInt(self.handles.texture);

    // TODO: would getOrPut be better here?
    try self.textures.put(self.alloc, handle, undefined);
    const m = self.textures.getPtr(handle).?;
    return .{ m, handle };
}

pub fn freeTexture(self: *ResourcePool, handle: Texture.Handle) void {
    switch (builtin.mode) {
        .Debug, .ReleaseSafe => {
            if (mem.indexOfScalar(Texture.Handle, self.free_list.textures.items, handle) != null) {
                try log.err("Double free detected for texture of handle {}", .{handle});
                @panic("Double free");
            }
        },
        else => {},
    }

    self.free_list.textures.append(self.free_list_arena.allocator(), handle) catch unreachable;

    self.textures.getPtr(handle).?.deinit();
    std.debug.assert(self.textures.remove(handle));
}

pub fn getTexture(self: *ResourcePool, handle: Texture.Handle) ?*Texture {
    switch (builtin.mode) {
        .Debug, .ReleaseSafe => {
            if (mem.indexOfScalar(Texture.Handle, self.free_list.textures.items, handle) != null) {
                log.err("Use after free detected for texture of handle {}", .{handle});
                @panic("Use after free");
            }
        },
        else => {},
    }

    return self.textures.getPtr(handle);
}

pub fn createShader(
    self: *ResourcePool,
) Allocator.Error!struct { *Shader, Shader.Handle } {
    defer self.handles.shader += 1;
    const handle: Shader.Handle = @enumFromInt(self.handles.shader);

    // TODO: would getOrPut be better here?
    try self.shaders.put(self.alloc, handle, undefined);
    const m = self.shaders.getPtr(handle).?;
    return .{ m, handle };
}

pub fn freeShader(self: *ResourcePool, handle: Shader.Handle) void {
    switch (builtin.mode) {
        .Debug, .ReleaseSafe => {
            if (mem.indexOfScalar(Shader.Handle, self.free_list.shaders.items, handle) != null) {
                log.err("Double free detected for shader of handle {}", .{handle});
                @panic("Double free");
            }
        },
        else => {},
    }

    self.free_list.shaders.append(self.free_list_arena.allocator(), handle) catch unreachable;

    self.shaders.getPtr(handle).?.deinit();
    std.debug.assert(self.shaders.remove(handle));
}

pub fn getShader(self: *ResourcePool, handle: Shader.Handle) ?*Shader {
    switch (builtin.mode) {
        .Debug, .ReleaseSafe => {
            if (mem.indexOfScalar(
                Shader.Handle,
                self.free_list.shaders.items,
                handle,
            ) != null) {
                log.err("Use after free detected for shader of handle {}", .{handle});
                @panic("Use after free");
            }
        },
        else => {},
    }

    return self.shaders.getPtr(handle);
}

pub fn createModel(
    self: *ResourcePool,
) Allocator.Error!struct { *Model, Model.Handle } {
    defer self.handles.model += 1;
    const handle: Model.Handle = @enumFromInt(self.handles.model);

    // TODO: would getOrPut be better here?
    try self.models.put(self.alloc, handle, undefined);
    const m = self.models.getPtr(handle).?;
    return .{ m, handle };
}

pub fn freeModel(self: *ResourcePool, handle: Model.Handle) void {
    switch (builtin.mode) {
        .Debug, .ReleaseSafe => {
            if (mem.indexOfScalar(Model.Handle, self.free_list.models.items, handle) != null) {
                log.err("Double free detected for model of handle {}", .{handle});
                @panic("Double free");
            }
        },
        else => {},
    }

    self.free_list.models.append(self.free_list_arena.allocator(), handle) catch unreachable;

    self.models.getPtr(handle).?.deinit();
    std.debug.assert(self.models.remove(handle));
}

pub fn getModel(self: *ResourcePool, handle: Model.Handle) ?*Model {
    switch (builtin.mode) {
        .Debug, .ReleaseSafe => {
            if (mem.indexOfScalar(Model.Handle, self.free_list.models.items, handle) != null) {
                log.err("Use after free detected for model of handle {}", .{handle});
                @panic("Use after free");
            }
        },
        else => {},
    }

    return self.models.getPtr(handle);
}

pub fn createVertexBuffer(
    self: *ResourcePool,
) Allocator.Error!struct { *VertexBuffer, VertexBuffer.Handle } {
    defer self.handles.vertex_buffer += 1;
    const handle: VertexBuffer.Handle = @enumFromInt(self.handles.vertex_buffer);

    // TODO: would getOrPut be better here?
    try self.vertex_buffers.put(self.alloc, handle, undefined);
    const m = self.vertex_buffers.getPtr(handle).?;
    return .{ m, handle };
}

pub fn freeVertexBuffer(self: *ResourcePool, handle: VertexBuffer.Handle) void {
    switch (builtin.mode) {
        .Debug, .ReleaseSafe => {
            if (mem.indexOfScalar(VertexBuffer.Handle, self.free_list.vertex_buffers.items, handle) != null) {
                log.err("Double free detected for vertex buffer of handle {}", .{handle});
                @panic("Double free");
            }
        },
        else => {},
    }

    self.free_list.vertex_buffers.append(self.free_list_arena.allocator(), handle) catch unreachable;

    self.vertex_buffers.getPtr(handle).?.deinit();
    std.debug.assert(self.vertex_buffers.remove(handle));
}

pub fn getVertexBuffer(self: *ResourcePool, handle: VertexBuffer.Handle) ?*VertexBuffer {
    switch (builtin.mode) {
        .Debug, .ReleaseSafe => {
            if (mem.indexOfScalar(VertexBuffer.Handle, self.free_list.vertex_buffers.items, handle) != null) {
                log.err("Use after free detected for vertex_buffer of handle {}", .{handle});
                @panic("Use after free");
            }
        },
        else => {},
    }

    return self.vertex_buffers.getPtr(handle);
}

pub fn createBuffer(
    self: *ResourcePool,
) Allocator.Error!struct { *Buffer, Buffer.Handle } {
    defer self.handles.buffer += 1;
    const handle: Buffer.Handle = @enumFromInt(self.handles.buffer);

    // TODO: would getOrPut be better here?
    try self.buffers.put(self.alloc, handle, undefined);
    const m = self.buffers.getPtr(handle).?;
    return .{ m, handle };
}

pub fn freeBuffer(self: *ResourcePool, handle: Buffer.Handle) void {
    switch (builtin.mode) {
        .Debug, .ReleaseSafe => {
            if (mem.indexOfScalar(Buffer.Handle, self.free_list.buffers.items, handle) != null) {
                log.err("Double free detected for buffer of handle {}", .{handle});
                @panic("Double free");
            }
        },
        else => {},
    }

    self.free_list.buffers.append(self.free_list_arena.allocator(), handle) catch unreachable;

    self.buffers.getPtr(handle).?.deinit();
    std.debug.assert(self.buffers.remove(handle));
}

pub fn getBuffer(self: *ResourcePool, handle: Buffer.Handle) ?*Buffer {
    switch (builtin.mode) {
        .Debug, .ReleaseSafe => {
            if (mem.indexOfScalar(Buffer.Handle, self.free_list.buffers.items, handle) != null) {
                log.err("Use after free detected for buffer of handle {}", .{handle});
                @panic("Use after free");
            }
        },
        else => {},
    }

    return self.buffers.getPtr(handle);
}

test "ResourcePool.createTexture" {
    var rp = ResourcePool.init(std.testing.allocator);
    defer rp.deinit();

    _, const handle = try rp.createTexture();
    try std.testing.expectEqual(handle, 0);
}

test "ResourcePool.createShader" {
    var rp = ResourcePool.init(std.testing.allocator);
    defer rp.deinit();

    _, const handle = try rp.createShader();
    try std.testing.expectEqual(handle, 0);
}

test "ResourcePool.createModel" {
    var rp = ResourcePool.init(std.testing.allocator);
    defer rp.deinit();

    _, const handle = try rp.createModel();
    try std.testing.expectEqual(handle, 0);
}

test "ResourcePool.createVertexBuffer" {
    var rp = ResourcePool.init(std.testing.allocator);
    defer rp.deinit();

    _, const handle = try rp.createVertexBuffer();
    try std.testing.expectEqual(handle, 0);

    _, const h2 = try rp.createVertexBuffer();
    try std.testing.expectEqual(h2, 1);
}

test "multiple resources" {
    var rp = ResourcePool.init(std.testing.allocator);
    defer rp.deinit();

    const expect = std.testing.expect;

    _, const vbh1 = try rp.createVertexBuffer();
    _, const vbh2 = try rp.createVertexBuffer();
    try expect(vbh1 == 0);
    try expect(vbh2 == 1);

    _, const th1 = try rp.createTexture();
    _, const th2 = try rp.createTexture();
    try expect(th1 == 0);
    try expect(th2 == 1);

    _, const moh1 = try rp.createModel();
    _, const moh2 = try rp.createModel();
    try expect(moh1 == 0);
    try expect(moh2 == 1);

    _, const sh1 = try rp.createShader();
    _, const sh2 = try rp.createShader();
    try expect(sh1 == 0);
    try expect(sh2 == 1);
}
