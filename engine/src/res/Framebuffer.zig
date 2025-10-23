const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const builtin = @import("builtin");

const gl = @import("gl");

const engine = @import("../engine.zig");
const math = engine.math;
const log = engine.debug.log;
const Vertex = engine.Vertex;
const assert = engine.debug.assert;
const res = engine.res;
const Image = engine.Image;

pub const max_color_attachments = 7;
pub const max_renderbuffer_attachments = 7;

pub const Handle = enum(usize) {
    _,
    pub const zero: Handle = @enumFromInt(0);
};

pub const ColorAttachment = struct {
    handle: c_uint,

    pub const Spec = struct {
        minimum_filter: Texture.Filter,
        magnification_filter: Texture.Filter,
    };

    pub fn init(
        spec: *const Spec,
    ) ColorAttachment {
        var handle: c_uint = undefined;
        gl.GenTextures(1, @ptrCast(&handle));
        gl.BindTexture(gl.TEXTURE_2D, handle);

        gl.TexParameteri(
            gl.TEXTURE_2D,
            gl.TEXTURE_MIN_FILTER,
            spec.minimum_filter.as(c_int),
        );

        gl.TexParameteri(
            gl.TEXTURE_2D,
            gl.TEXTURE_MAG_FILTER,
            spec.magnification_filter.as(c_int),
        );

        return .{
            .handle = handle,
        };
    }

    pub fn deinit(self: *ColorAttachment) void {
        gl.DeleteTextures(1, @ptrCast(&self.handle));
        self.* = undefined;
    }

    pub fn bind(self: *ColorAttachment) void {
        gl.BindTexture(gl.TEXTURE_2D, self.handle);
    }

    pub fn unbind(_: *ColorAttachment) void {
        gl.BindTexture(gl.TEXTURE_2D, 0);
    }

    /// Assumes `self` is bound
    pub fn setImage(
        _: *ColorAttachment,
        image: Image,
    ) void {
        const width, const height = switch (builtin.os.tag) {
            .macos => .{ image.width * 2, image.height * 2 },
            .linux => .{ image.width, image.height },
            else => |tag| @compileError(@tagName(tag) ++ " os not supported"),
        };
        const format = image.format.as(c_uint);
        const data_type = gl.UNSIGNED_BYTE;
        gl.TexImage2D(
            gl.TEXTURE_2D,
            0,
            @intCast(format),
            @intCast(width),
            @intCast(height),
            0,
            format,
            data_type,
            image.data.ptr,
        );
    }
};

pub const RenderbufferAttachment = struct {
    handle: c_uint,

    pub const Format = enum(u32) {
        depth24_stencil8 = gl.DEPTH24_STENCIL8,

        pub fn as(self: Format, T: type) T {
            return @intCast(@intFromEnum(self));
        }
    };

    pub fn init(width: u32, height: u32, format: Format) RenderbufferAttachment {
        var handle: c_uint = undefined;
        gl.GenRenderbuffers(1, @ptrCast(&handle));
        gl.BindRenderbuffer(gl.RENDERBUFFER, handle);

        const w, const h = switch (builtin.os.tag) {
            .macos => .{ width * 2, height * 2 },
            .linux => .{ width, height },
            else => |tag| @compileError(@tagName(tag) ++ " os not supported"),
        };
        gl.RenderbufferStorage(
            gl.RENDERBUFFER,
            format.as(c_uint),
            @intCast(w),
            @intCast(h),
        );

        return .{
            .handle = handle,
        };
    }

    pub fn deinit(self: *RenderbufferAttachment) void {
        gl.DeleteRenderbuffers(1, @ptrCast(&self.handle));
        self.* = undefined;
    }

    pub fn bind(self: *const RenderbufferAttachment) void {
        gl.BindRenderbuffer(gl.RENDERBUFFER, self.handle);
    }
    pub fn unbind(_: *const RenderbufferAttachment) void {
        gl.BindRenderbuffer(gl.RENDERBUFFER, 0);
    }
};

const Framebuffer = @This();

width: u32,
height: u32,
handle: c_uint,

color_attachments: [max_color_attachments]ColorAttachment,
/// number of color attachments actually created
color_attachments_len: u8,

renderbuffer_attachments: [max_renderbuffer_attachments]RenderbufferAttachment,
/// number of renderbuffer attachments actually created
renderbuffer_attachments_len: u8,

pub fn init(width: u32, height: u32) Framebuffer {
    var handle: c_uint = undefined;
    gl.GenFramebuffers(1, @ptrCast(&handle));

    return .{
        .width = width,
        .height = height,
        .handle = handle,

        .color_attachments = undefined,
        .color_attachments_len = 0,

        .renderbuffer_attachments = undefined,
        .renderbuffer_attachments_len = 0,
    };
}

pub fn deinit(self: *Framebuffer) void {
    for (0..self.color_attachments_len) |i| {
        self.color_attachments[i].deinit();
    }

    for (0..self.renderbuffer_attachments_len) |i| {
        self.renderbuffer_attachments[i].deinit();
    }

    gl.DeleteFramebuffers(1, @ptrCast(&self.handle));
    self.* = undefined;
}

pub fn bind(self: *const Framebuffer) void {
    gl.BindFramebuffer(gl.FRAMEBUFFER, self.handle);
}

pub fn unbind(_: *const Framebuffer) void {
    gl.BindFramebuffer(gl.FRAMEBUFFER, 0);
}

const Texture = res.Texture;
const cast = engine.cast;

/// Assumes that `self` is bound.
pub fn createColorAttachment(
    self: *Framebuffer,
    spec: *const ColorAttachment.Spec,
) *ColorAttachment {
    defer self.color_attachments_len += 1;
    self.color_attachments[self.color_attachments_len] = .init(spec);
    const ca = &self.color_attachments[self.color_attachments_len];

    gl.FramebufferTexture2D(
        gl.FRAMEBUFFER,
        gl.COLOR_ATTACHMENT0 + cast.as(c_uint, self.color_attachments_len),
        gl.TEXTURE_2D,
        ca.handle,
        0,
    );

    return ca;
}

pub fn createRenderbufferAttachment(
    self: *Framebuffer,
    fmt: RenderbufferAttachment.Format,
) *RenderbufferAttachment {
    defer self.renderbuffer_attachments_len += 1;
    self.renderbuffer_attachments[self.renderbuffer_attachments_len] =
        .init(self.width, self.height, fmt);
    const rba = &self.renderbuffer_attachments[self.renderbuffer_attachments_len];

    gl.FramebufferRenderbuffer(
        gl.FRAMEBUFFER,
        gl.DEPTH_STENCIL_ATTACHMENT,
        gl.RENDERBUFFER,
        rba.handle,
    );

    return rba;
}

/// `self` must be bound
pub fn isComplete(_: *const Framebuffer) bool {
    return gl.CheckFramebufferStatus(gl.FRAMEBUFFER) == gl.FRAMEBUFFER_COMPLETE;
}
