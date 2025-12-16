shader_type canvas_item;

// -----------------------------
// Rotation
// -----------------------------
uniform vec3 roll_axis = vec3(0.0, 1.0, 0.0);
uniform float roll_speed = 0.6;
uniform float roll_angle = 0.0;

// -----------------------------
// Texture Controls
// -----------------------------
uniform float aspect_ratio = 1.0;
uniform vec2 tile_factor = vec2(1.0, 1.0);
uniform vec2 texture_offset = vec2(0.0, 0.0);

uniform float edge_warp_strength = 0.08; // How wobbly the edge is
uniform float edge_warp_scale = 6.0;     // Number of ripples around the sphere
uniform float edge_warp_speed = 0.6;     // Animation speed
uniform float edge_pixel_steps = 48.0; // Lower = chunkier pixels


// -----------------------------
varying mat3 v_rot_matrix;
varying vec2 v_centered_uv;

// Rodrigues rotation
mat3 get_rotation_matrix(vec3 axis, float angle) {
    float c = cos(angle);
    float s = sin(angle);
    float t = 1.0 - c;

    return mat3(
        vec3(t*axis.x*axis.x + c,        t*axis.x*axis.y - s*axis.z, t*axis.x*axis.z + s*axis.y),
        vec3(t*axis.x*axis.y + s*axis.z, t*axis.y*axis.y + c,        t*axis.y*axis.z - s*axis.x),
        vec3(t*axis.x*axis.z - s*axis.y, t*axis.y*axis.z + s*axis.x, t*axis.z*axis.z + c)
    );
}

void vertex() {
    v_centered_uv = (UV - 0.5) * 2.0;
    v_centered_uv.x *= aspect_ratio;

    float angle = roll_angle + TIME * roll_speed;
    v_rot_matrix = get_rotation_matrix(normalize(roll_axis), angle);
}

void fragment() {
    vec2 centered = v_centered_uv;

    float r = length(centered);
    float angle = atan(centered.y, centered.x);

    // -----------------------------
    // Pixelated angle
    // -----------------------------
    float angle01 = (angle + PI) / (2.0 * PI);          // [-π,π] → [0,1]
    angle01 = floor(angle01 * edge_pixel_steps) / edge_pixel_steps;
    float pixel_angle = angle01 * (2.0 * PI) - PI;     // back to radians

    // -----------------------------
    // Pixelated web-like edge warp
    // -----------------------------
    float warp =
        sin(pixel_angle * edge_warp_scale + TIME * edge_warp_speed) *
        sin((pixel_angle + TIME * 0.7) * (edge_warp_scale * 0.6)) *
        edge_warp_strength;

    float warped_radius = 1.0 + warp;

    // Clip
    if (r > warped_radius) discard;

    // Edge AA (still smooth between steps)
    float aa = fwidth(r);
    float alpha = 1.0 - smoothstep(warped_radius - aa, warped_radius, r);

    // -----------------------------
    // Sphere geometry (unchanged)
    // -----------------------------
    float dist_sq = dot(centered, centered);
    float z = sqrt(max(0.0, 1.0 - dist_sq));
    vec3 normal = vec3(centered, z);

    vec3 rotated = v_rot_matrix * normal;

    float u = 0.5 + atan(rotated.x, rotated.z) * 0.1591549;
    float v = 0.5 - asin(rotated.y) * 0.3183098;

    vec4 tex = texture(TEXTURE, vec2(u, v) * tile_factor + texture_offset);

    COLOR = vec4(tex.rgb, tex.a * alpha);
}


