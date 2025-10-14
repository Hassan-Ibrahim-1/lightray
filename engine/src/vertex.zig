const std = @import("std");
const engine = @import("engine.zig");
const Vec3 = engine.math.Vec3;
const Vec2 = engine.math.Vec2;
const Writer = std.Io.Writer;

pub const Vertex = struct {
    position: Vec3,
    normal: Vec3,
    uv: Vec2,

    pub fn init(pos: Vec3, normal: Vec3, uv: Vec2) Vertex {
        return Vertex{
            .position = pos,
            .normal = normal,
            .uv = uv,
        };
    }

    pub fn fromPos(pos: Vec3) Vertex {
        return Vertex{
            .position = pos,
            .normal = Vec3.zero,
            .uv = Vec2.zero,
        };
    }

    pub fn format(self: Vertex, writer: *Writer) Writer.Error!void {
        const indent = "    ";
        try writer.print(
            "Vertex = .{{\n{s}position = ({f}),\n{s}normal = ({f}),\n{s}uv = ({f})\n}}",
            .{ indent, self.position, indent, self.normal, indent, self.uv },
        );
    }
};
