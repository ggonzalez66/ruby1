extends Area2D

# Géiser de lava del mundo del sol: burbujea avisando y lanza una columna de fuego (PixelFX flame-pillar)
# que devuelve al checkpoint a quien la toque. Se repite cada `period` segundos.

@export var period := 3.2
@export var phase := 0.0
@export var warn_time := 0.8
@export var burst_time := 1.3
@export var height := 300.0

const WARN := Color(1.0, 0.75, 0.25)

var time := 0.0
var erupting := false
var shape: CollisionShape2D

func _ready() -> void:
	add_to_group(&"lava")
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	z_index = 5
	time = phase
	shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(56, height)
	shape.shape = rect
	shape.position = Vector2(0, -height * 0.5)
	shape.disabled = true
	add_child(shape)

func _physics_process(delta: float) -> void:
	var before := fposmod(time, period)
	time += delta
	var now := fposmod(time, period)
	var burst_start := warn_time
	if before < burst_start and now >= burst_start:
		erupting = true
		shape.disabled = false
		if is_visible_in_tree() and get_viewport_rect().grow(400.0).has_point(get_global_transform_with_canvas().origin):
			PixelFx.play(get_parent(), "flame_pillar", global_position, height / 230.0, [], {"speed": 1.8, "z": 5})
			Sfx.play("fire_breath", -6.0, 0.8)
	if erupting and now >= burst_start + burst_time or now < before:
		erupting = false
		shape.disabled = true
	if erupting:
		for body in get_overlapping_bodies():
			if body.has_method("return_to_checkpoint"):
				body.return_to_checkpoint(0)
	queue_redraw()

func is_warning() -> bool:
	return fposmod(time, period) < warn_time

func _draw() -> void:
	# Boca del géiser y burbujeo de aviso.
	draw_rect(Rect2(-30, -6, 60, 8), Color(0.5, 0.12, 0.04))
	draw_rect(Rect2(-22, -10, 44, 6), Color(1.0, 0.45, 0.1))
	if is_warning():
		var t := fposmod(time, period) / warn_time
		for index in range(4):
			var y := -10.0 - fposmod(t * 60.0 + index * 15.0, 60.0)
			draw_rect(Rect2(-14 + index * 9, y, 4, 4), Color(WARN, 1.0 - t * 0.5))
