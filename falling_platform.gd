extends StaticBody2D

# Plataforma del mundo del sol que se desmorona: al pisarla tiembla `delay` segundos, cae y reaparece al
# rato en su sitio. Hay que seguir avanzando sin detenerse.

@export var size := Vector2(150, 24)
@export var delay := 0.55
@export var respawn_time := 2.8

const STONE := Color(1.0, 0.7, 0.28)
const STONE_DARK := Color(0.72, 0.36, 0.1)
const CREST := Color(1.0, 0.96, 0.75)
const CRACK := Color(0.45, 0.18, 0.05)

var home := Vector2.ZERO
var timer := -1.0
var fallen := false
var collision: CollisionShape2D
var sensor: Area2D

func _ready() -> void:
	add_to_group(&"falling_platforms")
	collision_layer = 2
	home = position
	collision = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	collision.shape = rect
	add_child(collision)
	# Sensor fino sobre la superficie: detecta a Viridy de pie encima.
	sensor = Area2D.new()
	sensor.collision_layer = 0
	sensor.collision_mask = 1
	var sensor_shape := CollisionShape2D.new()
	var sensor_rect := RectangleShape2D.new()
	sensor_rect.size = Vector2(size.x - 6.0, 10.0)
	sensor_shape.shape = sensor_rect
	sensor_shape.position = Vector2(0, -size.y * 0.5 - 5.0)
	sensor.add_child(sensor_shape)
	add_child(sensor)

func _physics_process(delta: float) -> void:
	if fallen:
		return
	if timer < 0.0:
		for body in sensor.get_overlapping_bodies():
			if body.is_in_group(&"player") and body.velocity.y >= -1.0:
				timer = delay
				Sfx.play("step", -4.0, 0.6)
				break
		return
	timer -= delta
	# Tiembla antes de caer.
	position = home + Vector2(randf_range(-2.0, 2.0), randf_range(-1.0, 1.0))
	queue_redraw()
	if timer <= 0.0:
		_fall()

func _fall() -> void:
	fallen = true
	timer = -1.0
	collision.set_deferred("disabled", true)
	Fx.dust(get_parent(), global_position + Vector2(0, size.y * 0.5), Vector2.DOWN, 6, 1.2)
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "position", home + Vector2(0, 520), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.9)
	tween.chain().tween_interval(respawn_time)
	tween.chain().tween_callback(_respawn)

func _respawn() -> void:
	position = home
	fallen = false
	collision.set_deferred("disabled", false)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.35)
	Fx.puff(get_parent(), global_position, CREST)

func _draw() -> void:
	var half := size * 0.5
	var shaking := timer >= 0.0
	draw_rect(Rect2(-half, size), STONE_DARK)
	draw_rect(Rect2(-half.x, -half.y, size.x, size.y * 0.6), STONE.lightened(0.15) if shaking else STONE)
	draw_rect(Rect2(-half.x, -half.y, size.x, 3), CREST)
	# Grietas que avisan de que se cae.
	var cracks := 3 if not shaking else 6
	for index in range(cracks):
		var x := -half.x + (index + 0.5) * size.x / cracks
		draw_line(Vector2(x, -half.y + 3), Vector2(x + 6, half.y - 2), CRACK, 2.0)
	# Gotas de luz debajo.
	draw_rect(Rect2(-half.x + 8, half.y, 4, 4), Color(CREST, 0.7))
	draw_rect(Rect2(half.x - 12, half.y, 4, 4), Color(CREST, 0.7))
