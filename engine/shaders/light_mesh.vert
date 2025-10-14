layout(location = 0) in vec3 a_position;
layout(location = 1) in vec3 a_normal;
layout(location = 2) in vec2 a_uv;
layout(location = 3) in mat4 a_model;
layout(location = 7) in mat3 a_inverse_model;
layout(location = 10) in vec3 a_color;
layout(location = 11) in float a_shininess;

struct Material {
    vec3 color;
    float shininess;
};

out VS_OUT {
    vec3 normal;
    vec3 frag_pos;
    vec2 uv;
    Material material;
} vs_out;

uniform mat4 projection;
uniform mat4 view;

void main() {
    gl_Position = projection * view * a_model * vec4(a_position, 1.0f);
    vs_out.frag_pos = vec3(a_model * vec4(a_position, 1.0f));
    vs_out.normal = a_normal;
    vs_out.material.color = a_color;
    vs_out.material.shininess = a_shininess;
    vs_out.uv = a_uv;
}
