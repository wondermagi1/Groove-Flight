shader_type spatial;
render_mode cull_back;

uniform vec4 base_color: source_color = vec4(0.012, 0.025, 0.055, 1.0);
void fragment() {
    float wave = sin(UV.x * 120.0 + TIME * 0.5) * sin(UV.y * 137.0 - TIME * 0.7);
    ALBEDO = base_color.rgb + vec3(0.002, 0.005, 0.009) * wave;
    METALLIC = 0.65;
    ROUGHNESS = 0.2 + wave * 0.03;
    NORMAL_MAP = vec3(0.5 + wave * 0.035, 0.5 + cos(UV.y * 140.0 + TIME) * 0.025, 1.0);
}
