shader_type canvas_item;

uniform float glow_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.86, 0.45, 1.0);

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	// Tiñe el sprite hacia el color de carga y le suma brillo, respetando la transparencia.
	base.rgb = mix(base.rgb, glow_color.rgb, glow_amount * 0.65) + glow_color.rgb * glow_amount * 0.35;
	COLOR = base;
}
