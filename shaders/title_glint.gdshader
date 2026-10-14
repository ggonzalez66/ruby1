shader_type canvas_item;

// Destello del título: una franja de luz diagonal que recorre el texto (coordenadas locales del Label).
// Solo ilumina el relleno (las partes claras), no el contorno oscuro.
uniform float sweep_x = -1000.0;
uniform float band_width = 26.0;
uniform vec4 shine_color : source_color = vec4(1.0, 0.93, 0.9, 1.0);

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec4 base = COLOR;
	float distance_to_band = abs(local_pos.x + local_pos.y * 0.45 - sweep_x);
	float band = 1.0 - smoothstep(0.0, band_width, distance_to_band);
	float fill = smoothstep(0.2, 0.45, max(base.r, max(base.g, base.b)));
	base.rgb = mix(base.rgb, shine_color.rgb, band * fill * 0.9);
	COLOR = base;
}
