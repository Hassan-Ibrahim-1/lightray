
out vec4 FragColor;

in vec3 frag_pos;

// Uniforms for the rectangle’s parameters in world space.
uniform vec3 position;  // Center of the rectangle in 3D space.
uniform vec2 scale;     // Full width and height of the rectangle.
uniform float radius;   // Corner radius.

struct Material {
    vec3 color;
};

uniform Material material;


// SDF for a rounded rectangle in 2D.
// p: point position in the rectangle’s local (XY) space (with the rectangle centered at the origin)
// half_size: half the size of the rectangle (i.e. scale * 0.5)
// radius: corner radius
float roundedBoxSdf(vec2 p, vec2 half_size, float radius) {
    // Shift the bounds inward by the radius.
    vec2 d = abs(p) - (half_size - vec2(radius));
    // Compute the distance: inside the shape, d.x or d.y may be negative.
    return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - radius;
}

void main() {
    // Transform the fragment’s XY world coordinates into the rectangle’s local space.
    // (We assume the rectangle is axis-aligned in the XY plane.)
    vec2 local_pos = frag_pos.xy - position.xy;
    vec2 half_size = scale * 0.5;
    
    // Compute the signed distance from the fragment’s local position to the rounded rectangle edge.
    float dist = roundedBoxSdf(local_pos, half_size, radius);
    
    // Use fwidth to get a screen-space derivative for smooth anti-aliasing.
    float smooth_width = fwidth(dist);
    float alpha = 1.0 - smoothstep(0.0, smooth_width, dist);
    
    // Output a red color with the computed alpha.
    FragColor = vec4(material.color, alpha);
    // FragColor = vec4(color, 1.0);
}

