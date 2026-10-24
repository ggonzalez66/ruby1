shader_type canvas_item;

uniform float glow_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.86, 0.45, 1.0);
uniform float jade_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// En Godot 4 COLOR ya incluye el color de la textura; multiplicarlo otra vez oscurece el sprite.
	vec4 base = COLOR;
	// Solo pigmento verde: conserva marfil, ojos blancos, metal y tela. Las hojas originales
	// no activan esta corrección. Jade oscuro, tono medio frío y luz celadón como el Viridy original.
	float pigment = smoothstep(-0.01, 0.07, base.g - base.r) * smoothstep(0.02, 0.12, base.g - base.b);
	vec3 jade = mix(vec3(0.025, 0.09, 0.075), vec3(0.22, 0.48, 0.35), clamp(base.g / 0.65, 0.0, 1.0));
	jade = mix(jade, vec3(0.78, 0.87, 0.58), smoothstep(0.65, 1.0, base.g));
	base.rgb = mix(base.rgb, jade, jade_amount * pigment);
	// Tiñe el sprite hacia el color de carga y le suma brillo, respetando la transparencia.
	base.rgb = mix(base.rgb, glow_color.rgb, glow_amount * 0.65) + glow_color.rgb * glow_amount * 0.35;
	COLOR = base;
}
