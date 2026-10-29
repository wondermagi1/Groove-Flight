shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 cyan: source_color = vec4(0.10, 0.75, 1.0, 1.0);
uniform vec4 violet: source_color = vec4(0.48, 0.20, 1.0, 1.0);
uniform float intensity = 1.0;

void fragment() {
    vec2 p = UV * 2.0 - 1.0;
    float r = length(p);
    float a = atan(p.y, p.x);
    float t = TIME * 0.52;
    float aperture = 1.0 - smoothstep(0.88, 1.0, r);
    float arms = pow(max(0.0, sin(a * 5.0 - r * 16.0 + t * 4.0)), 10.0);
    float fine = pow(max(0.0, sin(a * 11.0 - r * 35.0 - t * 2.0)), 18.0);
    float throat = exp(-r * r * 21.0);
    float rim = exp(-pow((r - 0.88) * 35.0, 2.0));
    float body = (arms * 1.7 + fine * 0.45) * smoothstep(0.02, 0.32, r);
    vec3 col = mix(violet.rgb, cyan.rgb, clamp(r + sin(a + t) * 0.17, 0.0, 1.0));
    vec3 light = col * (body * 2.0 + rim * 2.2 + throat * 1.8) * aperture * intensity;
    EMISSION = light;
    ALBEDO = light;
    ALPHA = aperture * clamp(0.5 + body + rim + throat, 0.0, 0.9);
}
