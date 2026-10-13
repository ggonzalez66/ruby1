extends Area2D

# Onda de choque que recorre el suelo. Es baja: hay que saltarla.

const HEIGHT := 26.0
const WIDTH := 34.0
const COLOR_FILL := Color(1.0, 0.55, 0.2, 0.75)
const COLOR_EDGE := Color(1.0, 0.9, 0.6, 0.95)

var direction := 1
var speed := 430.0
var distance_left := 720.0
var damage := 20
var hit_done := false
var visual: Polygon2D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(WIDTH * 0.8, HEIGHT * 0.8)
	shape.shape = rect
	shape.position = Vector2(0, -HEIGHT * 0.4)
	add_child(shape)
	# Media luna inclinada hacia donde avanza.
	visual = Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-WIDTH * 0.5, 0), Vector2(-WIDTH * 0.2, -HEIGHT * 0.6), Vector2(WIDTH * 0.15, -HEIGHT),
		Vector2(WIDTH * 0.5, -HEIGHT * 0.3), Vector2(WIDTH * 0.5, 0)])
	visual.color = COLOR_FILL
	visual.scale.x = direction
	add_child(visual)
	var edge := Line2D.new()
	edge.points = PackedVector2Array([Vector2(-WIDTH * 0.2, -HEIGHT * 0.6), Vector2(WIDTH * 0.15, -HEIGHT), Vector2(WIDTH * 0.5, -HEIGHT * 0.3)])
	edge.width = 3.0
	edge.default_color = COLOR_EDGE
	visual.add_child(edge)

func _physics_process(delta: float) -> void:
	var step := speed * delta
	position.x += direction * step
	distance_left -= step
	visual.scale.y = 1.0 + 0.15 * sin(distance_left * 0.08)
	if distance_left <= 120.0:
		modulate.a = max(distance_left / 120.0, 0.0)
	if distance_left <= 0.0:
		queue_free()
		return
	if hit_done:
		return
	for body in get_overlapping_bodies():
		if body.has_method("take_damage"):
			hit_done = true
			body.take_damage(damage, global_position + Vector2(-direction * 20.0, 30.0))
			return
