shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float intensity : hint_range(0.0, 2.0) = 0.9;

void fragment() {
	vec2 p = UV;
	float end = smoothstep(0.0, 0.045, p.x) * (1.0 - smoothstep(0.955, 1.0, p.x));
	float cross_section = abs(p.y - 0.5) * 2.0;
	float body = exp(-cross_section * cross_section * 6.8);
	float core = exp(-cross_section * cross_section * 32.0);
	vec3 tint = COLOR.rgb * 0.90 + vec3(0.27, 0.31, 0.35) * core;
	float alpha = (body * 0.40 + core * 0.53) * end * intensity * COLOR.a;
	COLOR = vec4(tint, alpha);
}
