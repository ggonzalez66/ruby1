extends Node2D

# Electrocutado por el shine: rayos amarillos en zigzag alrededor del enemigo, que se regeneran cada
# pocos frames mientras dura. Sigue al objetivo y se borra solo.

const BOLT_COLOR := Color(1.0, 0.95, 0.35)
const CORE_COLOR := Color(1.0, 1.0, 0.9)
const REFRESH := 0.05

var target: Node2D
var center_offset := Vector2.ZERO
var radius := 34.0
var duration := 0.5
var age := 0.0
var refresh_timer := 0.0
var bolts: Array = []

func _ready() -> void:
	z_index = 7
	for index in range(4):
		var glow := Line2D.new()
		glow.width = 5.0
		glow.default_color = Color(BOLT_COLOR, 0.45)
		add_child(glow)
		var core := Line2D.new()
		core.width = 2.0
		core.default_color = CORE_COLOR
		add_child(core)
		bolts.append([glow, core])
	_regenerate()

func _process(delta: float) -> void:
	var real_delta: float = delta / max(Engine.time_scale, 0.01)
	age += real_delta
	if age >= duration or not is_instance_valid(target):
		queue_free()
		return
	global_position = target.global_position + center_offset
	modulate.a = clamp((duration - age) / 0.15, 0.0, 1.0)
	refresh_timer -= real_delta
	if refresh_timer <= 0.0:
		refresh_timer = REFRESH
		_regenerate()

func _regenerate() -> void:
	# Cada rayo va de un punto del borde a otro pasando por el cuerpo, en zigzag.
	for pair in bolts:
		var start_angle: float = randf() * TAU
		var end_angle: float = start_angle + randf_range(2.0, 4.2)
		var from := Vector2(cos(start_angle), sin(start_angle)) * radius
		var to := Vector2(cos(end_angle), sin(end_angle)) * radius
		var points := PackedVector2Array()
		for step in range(7):
			var t: float = step / 6.0
			var point: Vector2 = from.lerp(to, t)
			if step > 0 and step < 6:
				point += (to - from).orthogonal().normalized() * randf_range(-10.0, 10.0)
			points.append(point)
		pair[0].points = points
		pair[1].points = points
