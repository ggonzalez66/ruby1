shader_type canvas_item;
render_mode unshaded;

void fragment() {
	float wave = sin(UV.x * 105.0 + TIME * 1.4) * 0.5 + sin(UV.x * 61.0 - TIME * 0.9) * 0.5;
	float depth = clamp(UV.y, 0.0, 1.0);
	vec3 shallow = vec3(0.30, 0.88, 0.75);
	vec3 deep = vec3(0.035, 0.36, 0.38);
	vec3 water = mix(shallow, deep, smoothstep(0.0, 1.0, depth));
	float ripple = pow(max(0.0, sin(UV.x * 170.0 + UV.y * 26.0 + TIME * 1.1 + wave)), 18.0);
	float caustic = pow(max(0.0, sin(UV.x * 89.0 - UV.y * 34.0 - TIME * 0.6) * sin(UV.x * 53.0 + UV.y * 45.0 + TIME * 0.8)), 6.0);
	water += vec3(0.42, 0.55, 0.33) * (ripple * 0.13 + caustic * 0.18);
	float surface = 1.0 - smoothstep(0.0, 0.038, abs(UV.y - 0.018 - wave * 0.009));
	water = mix(water, vec3(0.83, 0.99, 0.84), surface * 0.7);
	COLOR = vec4(water, mix(0.62, 0.88, depth));
}
