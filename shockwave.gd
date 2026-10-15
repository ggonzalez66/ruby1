extends Area2D

# Proyectil del guardián pesado: un gran arco de energía azul que recorre el suelo. Es alto: hay que
# saltarlo con doble salto, o devolverlo con el rugido (si nace dentro del aura en un parry, vuelve
# al instante como perfect devolución).

const COLOR_FILL := Color(0.25, 0.55, 1.0, 0.72)
const COLOR_EDGE := Color(0.78, 0.92, 1.0, 0.95)
const REFLECTED_FILL := Color(1.0, 0.85, 0.3, 0.85)
const REFLECTED_EDGE := Color(1.0, 0.97, 0.8, 0.95)
const REFLECTED_DAMAGE := 6

@export var height := 130.0
@export var width := 52.0

var direction := 1
var speed := 430.0
var distance_left := 720.0
var damage := 20
var hit_done := false
var reflected := false
var visual: Polygon2D
var edge: Line2D

func _ready() -> void:
	add_to_group(&"projectiles")
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width * 0.6, height * 0.88)
	shape.shape = rect
	shape.position = Vector2(0, -height * 0.44)
	add_child(shape)
	# Media luna alta curvada hacia donde avanza.
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for index in range(11):
		var t: float = index / 10.0
		var y: float = -height * t
		var bulge: float = sin(t * PI)
		outer.append(Vector2(width * 0.5 * bulge, y))
		inner.append(Vector2(-width * 0.15 + width * 0.2 * bulge, y))
	inner.reverse()
	var points := outer.duplicate()
	points.append_array(inner)
	visual = Polygon2D.new()
	visual.polygon = points
	visual.color = COLOR_FILL
	visual.scale.x = direction
	add_child(visual)
	edge = Line2D.new()
	edge.points = outer
	edge.width = 4.0
	edge.default_color = COLOR_EDGE
	visual.add_child(edge)

func _physics_process(delta: float) -> void:
	var step := speed * delta
	position.x += direction * step
	distance_left -= step
	visual.scale.y = 1.0 + 0.06 * sin(distance_left * 0.08)
	if distance_left <= 120.0:
		modulate.a = max(distance_left / 120.0, 0.0)
	if distance_left <= 0.0:
		queue_free()
		return
	if reflected:
		for area in get_overlapping_areas():
			if area.has_method("take_hit") and area.visible:
				area.take_hit(global_position, direction, REFLECTED_DAMAGE)
				Fx.impact(get_parent(), global_position + Vector2(0, -height * 0.5), Fx.ROAR, 1.4)
				queue_free()
				return
		return
	var player := get_tree().get_first_node_in_group(&"player")
	if player and player.is_roar_aura_active() and _touches_aura(player):
		_reflect(player)
		return
	if hit_done:
		return
	for body in get_overlapping_bodies():
		if body.has_method("take_damage"):
			hit_done = true
			body.take_damage(damage, global_position + Vector2(-direction * 20.0, 30.0))
			return

func _touches_aura(player: Node) -> bool:
	# El arco es alto: cuenta cualquier punto de su altura dentro del aura.
	var center: Vector2 = player.get_roar_center()
	var closest := Geometry2D.get_closest_point_to_segment(center, global_position, global_position + Vector2(0, -height))
	return closest.distance_to(center) <= player.roar_radius + 10.0

func _destroy() -> void:
	Fx.puff(get_parent(), global_position + Vector2(0, -height * 0.5), COLOR_FILL)
	queue_free()

func _reflect(player: Node) -> void:
	# El rugido la devuelve: cambia de sentido, acelera y ahora daña a los enemigos.
	reflected = true
	Stats.add("projectiles_reflected")
	var perfect: bool = player.has_method("is_perfect_shine") and player.is_perfect_shine()
	direction = -direction
	speed *= 1.4 * (player.perfect_reflect_speed if perfect else 1.0)
	distance_left = 900.0
	modulate.a = 1.0
	visual.scale.x = direction
	visual.color = REFLECTED_FILL
	edge.default_color = REFLECTED_EDGE
	set_deferred("collision_mask", 8)
	Fx.impact(get_parent(), global_position + Vector2(0, -height * 0.5), Fx.ROAR, 1.8 if perfect else 1.2)
	if player.has_method("on_projectile_reflected"):
		player.on_projectile_reflected(perfect)
