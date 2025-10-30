layout(location = 0) in vec3 a_position;
layout(location = 2) in vec2 a_uv;

out vec2 uv;

void main() {
    gl_Position = vec4(a_position.xy, 0.0, 1.0f);
    uv = a_uv;
}
