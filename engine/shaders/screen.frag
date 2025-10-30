out vec4 FragColor;

in vec2 uv;

uniform sampler2D screen_texture;

void main() {
    FragColor = texture(screen_texture, uv);
}
