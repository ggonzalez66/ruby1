extends Area2D

# Portal del Gauntlet: un óvalo de energía que gira, con su rótulo encima. Al entrar Rengar emite
# "entered" (el director decide: seguir a la siguiente ronda o terminar).

signal entered

@export var label_text := "SEGUIR"
@export var color := Color(0.4, 0.8, 1.0)

const SIZE := Vector2(70, 140)

var time := 0.0
var used := false

func _ready() -> void:
	z_index = 3
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE * Vector2(0.6, 0.9)
	shape.shape = rect
	shape.position = Vector2(0, -SIZE.y * 0.5)
	add_child(shape)
	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(200, 30)
	label.position = Vector2(-100, -SIZE.y - 42)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", color.lightened(0.4))
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.06))
	label.add_theme_constant_override("outline_size", 7)
	add_child(label)
	body_entered.connect(_on_body_entered)
	scale = Vector2(0.1, 0.1)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	var center := Vector2(0, -SIZE.y * 0.5)
	var radii := SIZE * 0.5
	draw_set_transform(center, 0.0, Vector2(1.0, radii.y / radii.x))
	draw_circle(Vector2.ZERO, radii.x, Color(color.darkened(0.6), 0.85))
	draw_circle(Vector2.ZERO, radii.x * 0.7, Color(color, 0.25 + 0.1 * sin(time * 4.0)))
	# Arcos que giran hacia dentro.
	for index in range(4):
		var start: float = time * 3.0 + TAU * index / 4.0
		draw_arc(Vector2.ZERO, radii.x * (0.45 + 0.13 * index), start, start + 2.2, 18, Color(color.lightened(0.3), 0.9), 3.0, true)
	draw_arc(Vector2.ZERO, radii.x, 0.0, TAU, 40, color.lightened(0.5), 4.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _on_body_entered(body: Node) -> void:
	if used or not body.is_in_group(&"player"):
		return
	used = true
	entered.emit()
