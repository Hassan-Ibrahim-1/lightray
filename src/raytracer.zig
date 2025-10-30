const log = engine.debug.log.scoped(.raytracer);
const cube_len: usize = 5000;

const std = @import("std");
const builtin = @import("builtin");

const engine = @import("engine");
const math = engine.math;
const res = engine.res;
const fs = engine.fs;
const ig = engine.ig;
const input = engine.input;
const renderer = engine.renderer;
const debug = renderer.debug;
const Framebuffer = res.Framebuffer;
const RenderPass = renderer.RenderPass;
const Vec3 = math.Vec3;
const Image = engine.Image;
