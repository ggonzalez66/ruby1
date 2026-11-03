extends Area2D

# Lava del mundo espiritual del sol: una franja de magma que burbujea. Tocarla devuelve a Viridy al último
# checkpoint (sin daño con damage = 0: en la run morir la terminaría). El origen es la superficie.

@export var size := Vector2(400, 60)
@export var damage := 0

const DEEP := Color(0.62, 0.08, 0.02)
const HOT := Color(1.0, 0.42, 0.06)
const CREST := Color(1.0, 0.86, 0.35)
const GLOW := Color(1.0, 0.55, 0.15, 0.22)

var time := 0.0
var bubbles: Array = []
var cooldown := 0.0

func _ready() -> void:
	add_to_group(&"lava")
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	z_index = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	# Un poco por debajo de la cresta, para que rozar la superficie al saltar no cuente.
	rect.size = Vector2(maxf(size.x - 10.0, 4.0), size.y)
	shape.shape = rect
	shape.position = Vector2(0, size.y * 0.5 + 8.0)
	add_child(shape)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(position.x * 3.0 + position.y)
	for index in range(maxi(int(size.x / 70.0), 2)):
		bubbles.append([rng.randf_range(-size.x * 0.5 + 10.0, size.x * 0.5 - 10.0), rng.randf_range(0.0, 3.0), rng.randf_range(2.0, 3.5)])

func _physics_process(delta: float) -> void:
	time += delta
	cooldown = maxf(cooldown - delta, 0.0)
	for body in get_overlapping_bodies():
		if body.has_method("return_to_checkpoint") and cooldown <= 0.0:
			cooldown = 0.3
			Fx.explosion(get_parent(), body.global_position + Vector2(0, -6), 0.3)
			Sfx.play("sun_hit", -4.0, 1.2)
			body.return_to_checkpoint(damage)
	if is_visible_in_tree() and get_viewport_rect().grow(size.x).has_point(get_global_transform_with_canvas().origin):
		queue_redraw()

func _draw() -> void:
	var half := size.x * 0.5
	# Resplandor sobre la superficie.
	draw_rect(Rect2(-half, -34.0, size.x, 34.0), Color(GLOW, 0.10))
	draw_rect(Rect2(-half, -16.0, size.x, 16.0), Color(GLOW, 0.18))
	# Superficie ondulada en escalones de pixel.
	var top := PackedVector2Array()
	var step := 8.0
	var x := -half
	while x <= half:
		var wave := sin(x * 0.045 + time * 2.2) * 3.0 + sin(x * 0.11 - time * 3.1) * 1.5
		top.append(Vector2(x, roundf(wave / 2.0) * 2.0))
		x += step
	var body := top.duplicate()
	body.append(Vector2(half, size.y))
	body.append(Vector2(-half, size.y))
	draw_colored_polygon(body, DEEP)
	# Banda caliente bajo la cresta.
	var hot := top.duplicate()
	for index in range(top.size() - 1, -1, -1):
		hot.append(top[index] + Vector2(0, 14))
	draw_colored_polygon(hot, HOT)
	draw_polyline(top, CREST, 3.0)
	# Vetas y burbujas.
	for index in range(int(size.x / 120.0)):
		var vx := -half + fposmod(index * 120.0 + time * 18.0, size.x)
		draw_line(Vector2(vx, 24), Vector2(vx + 40, 30), Color(HOT, 0.6), 2.0)
	for bubble in bubbles:
		var phase: float = fposmod(time + bubble[1], bubble[2]) / bubble[2]
		if phase < 0.7:
			var radius: float = 2.0 + phase * 6.0
			draw_circle(Vector2(bubble[0], 2.0 - phase * 4.0), radius, Color(CREST, 0.9 - phase))
		else:
			var pop: float = (phase - 0.7) / 0.3
			for spark in range(3):
				var a := -PI * (0.25 + spark * 0.25)
				draw_rect(Rect2(Vector2(bubble[0], -4.0) + Vector2.from_angle(a) * (6.0 + pop * 14.0), Vector2(3, 3)), Color(CREST, 1.0 - pop))
