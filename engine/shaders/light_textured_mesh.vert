
layout (location = 0) in vec3 a_position;
layout (location = 1) in vec3 a_normal;
layout (location = 2) in vec2 a_tex_coord;

out vec3 normal;
out vec3 frag_pos;
out vec2 tex_coord;

uniform mat4 model;
uniform mat3 inverse_model;
uniform mat4 projection;
uniform mat4 view;

void main() {
    gl_Position = projection * view * model * vec4(a_position, 1.0f);
    frag_pos = vec3(model * vec4(a_position, 1.0f));
    normal = normalize(inverse_model * a_normal);
    tex_coord = a_tex_coord;
    // normal = mat3(transpose(inverse(view * model))) * a_normal;
}

