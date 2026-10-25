extends Node2D

# Cubo de Metatrón: los 13 círculos de la Fruta de la Vida (centro + 6 interiores + 6 exteriores)
# con todas las líneas entre sus centros. Se dibuja una vez; rotación, escala y brillo se animan
# desde fuera con rotation / scale / modulate.

@export var outer_radius := 46.0
# Dorado profundo (menos amarillo).
@export var line_color := Color(0.88, 0.64, 0.2, 0.9)
@export var glow_color := Color(0.75, 0.45, 0.08, 0.2)
@export var line_width := 1.0
# Con textura (el aura de Rengar) se dibuja el sprite en vez de las líneas; el desgaste lo tiñe de rojo.
@export var texture: Texture2D
# El cubo del sprite ocupa este ancho relativo al diámetro (el resto son destellos alrededor).
@export var texture_fit := 1.15
var wear_material: ShaderMaterial
var formation := 1.0

func set_formation(amount: float) -> void:
	var value := clampf(amount, 0.0, 1.0)
	if not is_equal_approx(value, formation):
		formation = value
		queue_redraw()

func hexagon(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(6):
		points.append(Vector2.from_angle(-PI * 0.5 + TAU * index / 6.0) * radius)
	return points

func parry_outline() -> PackedVector2Array:
	# Sus lados rodean el radio circular real del parry sin cambiar la detección.
	var points := hexagon(outer_radius / cos(PI / 6.0))
	points.append(points[0])
	return points

func _ready() -> void:
	queue_redraw()

func set_wear(amount: float) -> void:
	# 0 = dorado intacto, 1 = rojo (casi sin durabilidad). Solo con textura.
	if wear_material == null:
		wear_material = ShaderMaterial.new()
		wear_material.shader = load("res://shaders/charge_glow.gdshader")
		material = wear_material
	wear_material.set_shader_parameter("glow_color", Color(1.0, 0.08, 0.06))
	wear_material.set_shader_parameter("glow_amount", clamp(amount, 0.0, 1.0) * 0.85)

func set_tint(line: Color, glow: Color) -> void:
	# Cambia los colores del dibujo (p. ej. se enrojece al gastarse la durabilidad del shine).
	line_color = line
	glow_color = glow
	queue_redraw()

func get_centers() -> PackedVector2Array:
	# Separación entre centros: el borde exterior (2d + d/2) coincide con outer_radius.
	var spacing: float = outer_radius / 2.5
	var centers := PackedVector2Array([Vector2.ZERO])
	for ring in [1, 2]:
		for index in range(6):
			var angle: float = -PI * 0.5 + TAU * index / 6.0
			centers.append(Vector2(cos(angle), sin(angle)) * spacing * ring)
	return centers

func _draw() -> void:
	if texture:
		if formation < 1.0:
			var gold := Color(1.0, 0.75, 0.25, 1.0 - formation)
			draw_colored_polygon(hexagon(8.0), gold)
			draw_polyline(parry_outline(), gold, 1.5, true)
		var width: float = outer_radius * 2.0 * texture_fit
		var size := Vector2(width, width * texture.get_height() / texture.get_width())
		# El cubo del sprite está un poco por encima del centro de la imagen.
		draw_texture_rect(texture, Rect2(-size * 0.5 - Vector2(0, size.y * 0.02), size), false, Color(1.0, 1.0, 1.0, formation))
		return
	var spacing: float = outer_radius / 2.5
	var circle_radius: float = spacing * 0.5
	var centers := get_centers()
	# Halo suave de fondo para que se lea sobre cualquier escenario.
	draw_circle(Vector2.ZERO, outer_radius, Color(glow_color, glow_color.a * 0.5))
	draw_arc(Vector2.ZERO, outer_radius, 0.0, TAU, 48, Color(glow_color, 0.35), line_width * 5.0, true)
	# Las 78 líneas del cubo: primero un trazo grueso y translúcido (brillo), luego el fino.
	for pass_index in range(2):
		var width: float = line_width * (2.4 if pass_index == 0 else 1.0)
		var color: Color = glow_color if pass_index == 0 else line_color
		for a in range(centers.size()):
			for b in range(a + 1, centers.size()):
				draw_line(centers[a], centers[b], color, width, true)
	# Los 13 círculos.
	for center in centers:
		draw_arc(center, circle_radius, 0.0, TAU, 24, line_color, line_width, true)
	draw_arc(Vector2.ZERO, outer_radius, 0.0, TAU, 48, Color(line_color, 1.0), line_width * 1.6, true)
