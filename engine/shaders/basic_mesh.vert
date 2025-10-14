layout(location = 0) in vec3 a_position;
layout(location = 1) in vec3 a_normal;
layout(location = 2) in vec2 a_uv;
layout(location = 3) in mat4 a_model;
layout(location = 7) in vec3 a_color;

uniform mat4 projection;
uniform mat4 view;

out VS_OUT {
    vec3 color;
} vs_out;

void main() {
    gl_Position = projection * view * a_model * vec4(a_position, 1.0f);
    vs_out.color = a_color;
}
