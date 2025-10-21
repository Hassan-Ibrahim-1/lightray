pub const ResourcePool = @import("ResourcePool.zig");

pub const Mesh = struct {
    pub const Handle = enum(usize) {
        _,
        pub const zero: Handle = @enumFromInt(0);
    };

    x: u32,

    pub fn init() Mesh {
        return .{};
    }

    pub fn deinit(_: Mesh) void {}
};
pub const Texture = struct {
    pub const Handle = enum(usize) {
        _,
        pub const zero: Handle = @enumFromInt(0);
    };

    x: u32,

    pub fn init() Texture {
        return .{};
    }

    pub fn deinit(_: Texture) void {}
};
pub const Shader = struct {
    pub const Handle = enum(usize) {
        _,
        pub const zero: Handle = @enumFromInt(0);
    };

    x: u32,

    pub fn init() Shader {
        return .{};
    }

    pub fn deinit(_: Shader) void {}
};
pub const Model = struct {
    pub const Handle = enum(usize) {
        _,
        pub const zero: Handle = @enumFromInt(0);
    };

    x: u32,

    pub fn init() Model {
        return .{};
    }

    pub fn deinit(_: Model) void {}
};
pub const VertexBuffer = struct {
    pub const Handle = enum(usize) {
        _,
        pub const zero: Handle = @enumFromInt(0);
    };

    x: u32,

    pub fn init() VertexBuffer {
        return .{};
    }

    pub fn deinit(_: VertexBuffer) void {}
};
pub const ComputeShader = struct {
    pub const Handle = enum(usize) {
        _,
        pub const zero: Handle = @enumFromInt(0);
    };

    x: u32,

    pub fn init() ComputeShader {
        return .{};
    }

    pub fn deinit(_: ComputeShader) void {}
};
pub const ComputeTexture = struct {
    pub const Handle = enum(usize) {
        _,
        pub const zero: Handle = @enumFromInt(0);
    };

    x: u32,

    pub fn init() ComputeTexture {
        return .{};
    }

    pub fn deinit(_: ComputeTexture) void {}
};
