
layout (location = 0) in vec3 a_position;

out vec3 tex_coord;

uniform mat4 projection;
uniform mat4 view;

void main() {
    tex_coord = a_position;
    vec4 pos = projection * view * vec4(a_position, 1);
    // To draw behind everthing else
    gl_Position = pos.xyww;
}

