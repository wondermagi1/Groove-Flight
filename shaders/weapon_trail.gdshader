shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float intensity : hint_range(0.0, 2.0) = 0.9;

void fragment() {
	vec2 p = UV;
	float tail_fade = smoothstep(0.0, 0.16, p.x);
	float body = 1.0 - smoothstep(0.08, 0.50, abs(p.y - 0.5));
	float core = 1.0 - smoothstep(0.0, 0.13, abs(p.y - 0.5));
	float head = pow(clamp(p.x, 0.0, 1.0), 2.2);
	float filament = 1.0-smoothstep(0.01,0.08,abs(abs(p.y-.5)-.24));
	vec3 tint = COLOR.rgb * (0.54 + head * 1.18) + vec3(0.54, 0.63, 0.68) * core * head;
	float alpha = (body * 0.48 + core * 0.88 + filament*.18) * tail_fade * intensity * COLOR.a;
	COLOR = vec4(tint, alpha);
}
