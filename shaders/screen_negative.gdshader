shader_type canvas_item;

// Negativo de toda la pantalla (la muerte de Viridy): "amount" mezcla de la imagen normal a su negativo,
// con un toque de contraste para que el golpe se sienta duro.
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float amount : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec3 color = texture(screen_texture, SCREEN_UV).rgb;
	vec3 negative = vec3(1.0) - color;
	negative = clamp((negative - 0.5) * 1.25 + 0.5, 0.0, 1.0);
	COLOR = vec4(mix(color, negative, amount), 1.0);
}
