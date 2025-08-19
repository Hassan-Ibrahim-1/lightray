
layout (location = 0) in vec3 a_position;
layout (location = 1) in vec3 a_normal;
// layout (location = 2) in vec2 a_tex_coord;

out vec3 normal;
out vec3 frag_pos; // fragment position

uniform mat4 model; // converts vectors to world_space
uniform mat3 inverse_model;
uniform mat4 projection;
uniform mat4 view;

void main() {
    gl_Position = projection * view * model * vec4(a_position, 1.0f);
    frag_pos = vec3(model * vec4(a_position, 1.0f));
    normal = normalize(inverse_model * a_normal);

    // normal = (inverse_view * a_normal);
    // normal = normalize(inverse_view * a_normal);
    // normal = normalize(mat3(transpose(inverse(model))) * a_normal);
}

