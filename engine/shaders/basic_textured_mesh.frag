
out vec4 FragColor;

in VS_OUT {
    vec3 normal;
    vec2 uv;
    vec3 color;
} fs_in;

uniform sampler2D texture_diffuse1;

void main() {
    vec3 result = (fs_in.color) * texture(texture_diffuse1, fs_in.uv).rgb;
    FragColor = vec4(result, 1.0);
}
