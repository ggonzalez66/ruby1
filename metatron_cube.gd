extends Node2D

# Cubo de Metatrón: los 13 círculos de la Fruta de la Vida (centro + 6 interiores + 6 exteriores)
# con todas las líneas entre sus centros. Se dibuja una vez; rotación, escala y brillo se animan
# desde fuera con rotation / scale / modulate.

@export var outer_radius := 46.0
# Dorado profundo (menos amarillo).
@export var line_color := Color(0.88, 0.64, 0.2, 0.9)
@export var glow_color := Color(0.75, 0.45, 0.08, 0.2)
@export var line_width := 1.0

func _ready() -> void:
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
