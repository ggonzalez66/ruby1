extends Area2D

# Onda de choque que recorre el suelo. Es baja: hay que saltarla, o devolverla con el rugido.

const HEIGHT := 26.0
const WIDTH := 34.0
const COLOR_FILL := Color(1.0, 0.55, 0.2, 0.75)
const COLOR_EDGE := Color(1.0, 0.9, 0.6, 0.95)
const REFLECTED_FILL := Color(1.0, 0.85, 0.3, 0.85)
const REFLECTED_DAMAGE := 6

var direction := 1
var speed := 430.0
var distance_left := 720.0
var damage := 20
var hit_done := false
var reflected := false
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
	if reflected:
		for area in get_overlapping_areas():
			if area.has_method("take_hit") and area.visible:
				area.take_hit(global_position, direction, REFLECTED_DAMAGE)
				Fx.impact(get_parent(), global_position + Vector2(0, -14), Fx.ROAR, 1.4)
				queue_free()
				return
		return
	var player := get_tree().get_first_node_in_group(&"player")
	if player and player.is_roar_aura_active() and global_position.distance_to(player.get_roar_center()) <= player.roar_radius + 10.0:
		_reflect(player)
		return
	if hit_done:
		return
	for body in get_overlapping_bodies():
		if body.has_method("take_damage"):
			hit_done = true
			body.take_damage(damage, global_position + Vector2(-direction * 20.0, 30.0))
			return

func _reflect(player: Node) -> void:
	# El rugido la devuelve: cambia de sentido, acelera y ahora daña a los enemigos.
	reflected = true
	direction = -direction
	speed *= 1.4
	distance_left = 900.0
	modulate.a = 1.0
	visual.scale.x = direction
	visual.color = REFLECTED_FILL
	set_deferred("collision_mask", 8)
	Fx.impact(get_parent(), global_position + Vector2(0, -14), Fx.ROAR, 1.2)
	if player.has_method("on_projectile_reflected"):
		player.on_projectile_reflected()
