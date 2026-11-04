shader_type canvas_item;

// Solo el contorno de un sprite (quien está dentro de un arbusto): los píxeles transparentes que tocan uno
// opaco se pintan del color de la línea; el resto, transparente. "width" va en píxeles de la textura.
uniform vec4 line_color : source_color = vec4(0.8, 1.0, 0.85, 0.95);
uniform float width = 2.0;

void fragment() {
	float inside = texture(TEXTURE, UV).a;
	vec2 step_size = TEXTURE_PIXEL_SIZE * width;
	float around = 0.0;
	for (int i = 0; i < 8; i++) {
		float angle = float(i) * 0.785398;
		around = max(around, texture(TEXTURE, UV + vec2(cos(angle), sin(angle)) * step_size).a);
	}
	float edge = step(0.4, around) * (1.0 - step(0.4, inside));
	COLOR = vec4(line_color.rgb, line_color.a * edge);
}
