layout(location = 0) in vec3 a_position;
layout(location = 1) in vec3 a_normal;
layout(location = 2) in vec2 a_uv;
layout(location = 3) in vec3 a_color;
layout(location = 4) in mat4 a_model;

out vec3 color;

uniform mat4 projection;
uniform mat4 view;

void main() {
    gl_Position = projection * view * a_model * vec4(a_position, 1.0f);
    color = a_color;
    // gl_Position = model * vec4(a_position, 1.0f);
}
