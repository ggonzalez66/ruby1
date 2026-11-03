extends Area2D

# Salida de un territorio de la run (y del Árbol Madre): un poste con una flecha hacia la derecha y su
# rótulo. Al llegar Viridy emite "entered" una sola vez.

signal entered

@export var label_text := "SALIDA"
@export var color := Color(0.55, 1.0, 0.6)
@export var height := 260.0

var used := false
var time := 0.0

func _ready() -> void:
	z_index = -1
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(90, height)
	shape.shape = rect
	shape.position = Vector2(0, -height * 0.5)
	add_child(shape)
	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(300, 30)
	label.position = Vector2(-150, -height - 40)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", color.lightened(0.3))
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.03))
	label.add_theme_constant_override("outline_size", 7)
	add_child(label)

func _physics_process(_delta: float) -> void:
	if used:
		return
	for body in get_overlapping_bodies():
		if body.is_in_group(&"player") and not body.dead:
			used = true
			Sfx.play("ui_select")
			entered.emit()
			return

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	# Poste de madera y flecha que late hacia la derecha.
	draw_rect(Rect2(-8, -height * 0.62, 16, height * 0.62), Color(0.38, 0.25, 0.15))
	var nudge := sin(time * 4.0) * 8.0
	var y := -height * 0.62
	var arrow := PackedVector2Array([Vector2(-60 + nudge, y - 22), Vector2(30 + nudge, y - 22), Vector2(30 + nudge, y - 44),
		Vector2(80 + nudge, y), Vector2(30 + nudge, y + 44), Vector2(30 + nudge, y + 22), Vector2(-60 + nudge, y + 22)])
	draw_colored_polygon(arrow, Color(color.darkened(0.45), 0.95))
	arrow.append(arrow[0])
	draw_polyline(arrow, color, 4.0, true)
	draw_circle(Vector2(0, -height * 0.5), 60.0 + 6.0 * sin(time * 3.0), Color(color, 0.06))
