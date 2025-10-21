const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

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
    loaded: bool,

    pub fn init(
        spec: *const ColorAttachmentSpec,
    ) ColorAttachment {
        var attachment_handle: c_uint = undefined;
        gl.GenTextures(1, @ptrCast(&attachment_handle));
        gl.BindTexture(gl.TEXTURE_2D, attachment_handle);

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

    pub fn setImage(
        self: *ColorAttachment,
        comptime fmt: Texture.Format,
        image: Image(fmt),
    ) void {
        _ = self; // autofix
        _ = image; // autofix
    }
};

const Framebuffer = @This();

width: u32,
height: u32,
handle: c_uint,

color_attachments: [max_color_attachments]c_uint,
/// number of color attachments actually created
color_attachments_len: u8,

renderbuffer_attachments: [max_renderbuffer_attachments]c_uint,
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
        _ = i; // autofix
    }

    for (0..self.renderbuffer_attachments_len) |i| {
        gl.DeleteRenderbuffers(1, @ptrCast(&self.renderbuffer_attachments[i]));
    }

    gl.DeleteFramebuffers(1, self.handle);
    self.* = undefined;
}

pub fn bind(self: *const Framebuffer) void {
    gl.BindFramebuffer(gl.FRAMEBUFFER, self.handle);
}

pub fn unbind(_: *const Framebuffer) void {
    gl.BindFramebuffer(gl.FRAMEBUFFER, 0);
}

const Texture = res.Texture;

pub const ColorAttachmentSpec = struct {
    minimum_filter: Texture.Filter,
    magnification_filter: Texture.Filter,
};

/// Assumes that `self` is bound.
pub fn createColorAttachment(
    self: *Framebuffer,
    spec: *const ColorAttachmentSpec,
) void {
    _ = self; // autofix
    _ = spec; // autofix
}
