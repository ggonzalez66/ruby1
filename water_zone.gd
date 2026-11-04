@tool
extends Node2D

# Agua (estilo Metroid): dentro, Viridy se mueve lenta y pesada (movimiento.gd la consulta con
# WaterZone.at), pero sus ataques no cambian. Se dibuja delante de los personajes, translúcida, con la
# superficie ondulando; "size" mide desde la superficie (y = 0) hacia abajo.

@export var size := Vector2(400, 120):
	set(value):
		size = value
		queue_redraw()
@export var tint := Color(0.16, 0.5, 0.62, 0.46)
@export var draw_body := true

var clock := 0.0

func _ready() -> void:
	add_to_group(&"water_zones")
	z_index = 7

func contains(point: Vector2) -> bool:
	var local := point - global_position
	return local.x >= -size.x * 0.5 and local.x <= size.x * 0.5 and local.y >= 0.0 and local.y <= size.y

func surface_y() -> float:
	return global_position.y

# La zona de agua que contiene ese punto (o null).
static func at(tree: SceneTree, point: Vector2) -> Node2D:
	for zone in tree.get_nodes_in_group(&"water_zones"):
		if zone.contains(point):
			return zone
	return null

func _process(delta: float) -> void:
	if not draw_body:
		return
	clock += delta
	queue_redraw()

func _draw() -> void:
	if not draw_body:
		return
	var half := size.x * 0.5
	draw_rect(Rect2(-half, 0, size.x, size.y), tint)
	# Más oscura al fondo.
	draw_rect(Rect2(-half, size.y * 0.55, size.x, size.y * 0.45), Color(0.02, 0.12, 0.2, 0.25))
	# Superficie que ondula, con brillos.
	var points := PackedVector2Array()
	var x := -half
	while x <= half:
		points.append(Vector2(x, 2.0 * sin(x * 0.045 + clock * 2.4) + 1.0))
		x += 8.0
	points.append(Vector2(half, 2.0 * sin(half * 0.045 + clock * 2.4) + 1.0))
	draw_polyline(points, Color(0.7, 0.95, 1.0, 0.85), 2.0)
	var glint := -half + fposmod(clock * 40.0, size.x)
	draw_line(Vector2(glint, 4), Vector2(minf(glint + 24.0, half), 4), Color(1, 1, 1, 0.35), 1.0)
