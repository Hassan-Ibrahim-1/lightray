layout(location = 0) in vec3 a_center;
layout(location = 1) in vec3 a_color;
layout(location = 2) in float a_scale;

vec2 OFFSETS[6] = vec2[](
        vec2(-1.0, -1.0),
        vec2(-1.0, 1.0),
        vec2(1.0, -1.0),
        vec2(1.0, -1.0),
        vec2(-1.0, 1.0),
        vec2(1.0, 1.0)
    );

// Uniforms
uniform mat4 view;
uniform mat4 projection;
uniform vec3 cam_right; // x-axis of view matrix
uniform vec3 cam_up; // y-axis of view matrix

out vec3 color;

void main() {
    vec2 frag_offset = OFFSETS[gl_VertexID];

    vec3 world_pos =
        a_center + (frag_offset.x * cam_right + frag_offset.y * cam_up) * a_scale;

    gl_Position = projection * view * vec4(world_pos, 1.0);

    color = a_color;
}
