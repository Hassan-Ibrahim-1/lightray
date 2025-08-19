
struct Material {
    // sampler2D texture_diffuse1;
    // sampler2D texture_specular1;
    // sampler2D texture_emission1;
    vec3 color;
    float shininess;
};

struct DirLight {
    vec3 direction;
    vec3 position;
    vec3 ambient;
    vec3 diffuse;
    vec3 specular;
};

struct PointLight {
    vec3 position;

    vec3 ambient;
    vec3 diffuse;
    vec3 specular;
};

struct SpotLight {
    vec3 position;
    vec3 direction;

    float inner_cutoff;
    float outer_cutoff;

    vec3 ambient;
    vec3 diffuse;
    vec3 specular;
};

vec3 calc_dir_light(DirLight light, vec3 normal, vec3 frag_pos, vec3 view_dir);
vec3 calc_point_light(PointLight light, vec3 normal, vec3 frag_pos, vec3 view_dir);
vec3 calc_spot_light(SpotLight light, vec3 normal, vec3 frag_pos, vec3 view_dir);
float calc_attenuation(float distance, float radius, float max_intensity, float falloff);

in vec3 normal;
in vec3 frag_pos;
in vec2 tex_coord;

out vec4 FragColor;

#define MAX_POINT_LIGHTS 4
#define MAX_SPOT_LIGHTS  4
#define MAX_DIR_LIGHTS   4


uniform Material material;
uniform DirLight dir_lights[MAX_DIR_LIGHTS];
uniform PointLight point_lights[MAX_POINT_LIGHTS];
uniform SpotLight spot_lights[MAX_SPOT_LIGHTS];
uniform vec3 view_pos;

// How many point lights are actually in use
uniform int n_point_lights_used;
uniform int n_spot_lights_used;
uniform int n_dir_lights_used;

void main() {
    vec3 view_direction = normalize(view_pos - frag_pos);
    // vec3 view_direction = normalize(-frag_pos);

    vec3 result = vec3(0, 0, 0);
    for (uint i = 0; i < n_dir_lights_used; i++) {
        result += calc_dir_light(dir_lights[i], normal, frag_pos, view_direction);
    }

    for (uint i = 0; i < n_point_lights_used; i++) {
        result += calc_point_light(point_lights[i], normal, frag_pos, view_direction);
    }

    for (uint i = 0; i < n_spot_lights_used; i++) {
        result += calc_spot_light(spot_lights[i], normal, frag_pos, view_direction);
    }

    FragColor = vec4(result, 1.0f);

    // FragColor = vec4(result, 1.0f);
    // if (n_point_lights_used > 0) {
    //     FragColor = vec4(0, 1, 0, 1);
    // }
    // else {
    //     FragColor = vec4(1, 0, 0, 1);
    // }
    // FragColor = vec4(normal, 1.0f);

}

vec3 saturate(vec3 vec) {
    return clamp(vec, 0.0, 1.0);
}

vec3 calc_dir_light(DirLight light, vec3 normal, vec3 frag_pos, vec3 view_dir) {
    // vec3 light_dir = normalize(-light.direction);
    // // diffuse shading
    // float diff = max(dot(normal, light_dir), 0.0);
    // // specular shading
    // vec3 half_dir = normalize(light_dir + view_dir);
    // float spec = pow(max(dot(normal, half_dir), 0.0), material.shininess);
    // // combine results
    // vec3 ambient = light.ambient * material.color;
    // vec3 diffuse = light.diffuse * diff * material.color;
    // vec3 specular = light.specular * spec;
    // return (ambient + diffuse + specular);

    const float ambient_strength = 0.2;
    vec3 light_dir = normalize(light.position - frag_pos);

    vec3 half_dir = normalize(light_dir + view_dir);
    float spec = pow(max(dot(normal, half_dir), 0.0), material.shininess);
    vec3 specular = light.specular * spec;

    float distance = length(light.position - frag_pos);
    float attenuation = 1.0 / distance;

    float theta = dot(light_dir, normalize(-light.direction));
    // might need to make theta bigger if dir light isn't wide enough
    theta = clamp(theta * 5.0, 0.0, 1.0);
    vec3 amb_diff = saturate(ambient_strength * light.ambient + dot(normal, light_dir) * light.diffuse);
    amb_diff *= theta * material.color;
    specular *= theta;

    specular *= attenuation;
    // amb_diff *= attenuation;


    return amb_diff + specular;

    // diffuse shading
    // vec3 reflect_dir = reflect(-light_dir, normal);
    // float spec = pow(max(dot(view_dir, reflect_dir), 0.0), material.shininess);
    

}

vec3 calc_point_light(PointLight light, vec3 normal, vec3 frag_pos, vec3 view_dir) {
    vec3 light_dir = normalize(light.position - frag_pos);
    // diffuse shading
    float diff = max(dot(normal, light_dir), 0.0);

    // specular shading
    vec3 reflect_dir = reflect(-light_dir, normal);
    // float spec = pow(max(dot(reflect_dir, view_dir), 0.0), material.shininess);
    vec3 half_dir = normalize(light_dir + view_dir);
    float spec = pow(max(dot(normal, half_dir), 0.0), material.shininess);

    vec3 ambient = light.ambient * material.color;
    vec3 diffuse = light.diffuse * diff * material.color;
    vec3 specular = light.specular * spec;

    // attenuation
    float distance = length(light.position - frag_pos);
    float attenuation = 1.0 / distance;
    // float attenuation = 1.0 / (light.constant + light.linear * distance +
    //     light.quadratic * (distance * distance));
    ambient *= attenuation * 3;
    diffuse *= attenuation;
    specular *= attenuation;
    // return specular;
    return (ambient + diffuse + specular);
}

vec3 calc_spot_light(SpotLight light, vec3 normal, vec3 frag_pos, vec3 view_dir) {
    vec3 light_dir = normalize(light.position - frag_pos);
    // diffuse shading
    float diff = max(dot(normal, light_dir), 0.0);
    // specular shading
    vec3 half_dir = normalize(light_dir + view_dir);
    float spec = pow(max(dot(normal, half_dir), 0.0), material.shininess);
    
    vec3 ambient = light.ambient * material.color;
    vec3 diffuse = light.diffuse * diff * material.color;
    vec3 specular = light.specular * spec * material.color;

    float distance = length(light.position - frag_pos);
    float attenuation = 1.0 / distance;
    // float attenuation =
    //     1.0 / (light.constant + light.linear * distance + light.quadratic * (distance * distance));    
    // attenuation = calc_attenuation(distance, light.linear, light.constant, light.quadratic);
    // attenuation = (1 / distance * distance * light.linear);

    float theta = dot(light_dir, normalize(-light.direction));
    float epsilon = light.inner_cutoff - light.outer_cutoff;
    float intensity = clamp((theta - light.outer_cutoff) / epsilon, 0.0, 1.0);

    ambient *= attenuation * intensity;
    diffuse *= attenuation * intensity;
    specular *= attenuation * intensity;

    return (ambient + diffuse + specular);
}

float calc_attenuation(float distance, float radius, float max_intensity, float falloff) {
    float s = distance / radius;

    if (s >= 1.0) {
        return 0.0;
    }
    float s2 = s * s;
    float x = (1 - s2) * (1 - s2);

    return max_intensity * x / (1 + falloff * s);
}

