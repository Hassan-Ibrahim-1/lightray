
layout (location = 0) in vec3 a_position;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

out vec3 frag_pos;

void main() {
    vec4 pos = model * vec4(a_position, 1.0);
    gl_Position = projection * view * pos;
    // gl_Position = pos;
    frag_pos = vec3(pos);
}
