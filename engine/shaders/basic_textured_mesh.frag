
out vec4 FragColor;

in vec2 tex_coords;
in vec3 normal;

struct Material {
    sampler2D texture_diffuse1;
    vec3 color;
};

uniform Material material;

void main() {
    vec3 result = (material.color) * texture(material.texture_diffuse1, tex_coords).rgb;
    FragColor = vec4(result, 1.0);
    // FragColor = vec4(normal, 1.0);

    // TODO: gamma correction
    // float gamma = 2.2;
    // FragColor.rgb = pow(result.rgb, vec3(1.0/gamma));
}

