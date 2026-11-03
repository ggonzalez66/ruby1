extends Area2D

# Puerta de la fábrica en la run: empieza cerrada (cortina de acero y luz roja). El director la abre al
# vencer a todos los enemigos de la fase: la cortina sube, la luz pasa a verde y al entrar Viridy emite
# "entered" (afueras → dentro de la fábrica → sala del guardián).

signal entered

@export var label_text := "ENTRAR"
@export var size := Vector2(170, 230)
@export var locked := true

const FRAME := Color(0.2, 0.22, 0.25)
const FRAME_LIGHT := Color(0.42, 0.45, 0.5)
const SHUTTER := Color(0.47, 0.5, 0.53)
const SHUTTER_DARK := Color(0.28, 0.3, 0.33)
const INSIDE := Color(0.04, 0.05, 0.06)
const LOCKED_LIGHT := Color(1.0, 0.18, 0.12)
const OPEN_LIGHT := Color(0.35, 1.0, 0.45)
const OPEN_TIME := 1.1

var open_amount := 0.0
var used := false
var time := 0.0
var label: Label

func _ready() -> void:
	add_to_group(&"factory_doors")
	z_index = -1
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(size.x * 0.5, size.y * 0.8)
	shape.shape = rect
	shape.position = Vector2(0, -size.y * 0.4)
	add_child(shape)
	label = Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(260, 30)
	label.position = Vector2(-130, -size.y - 64)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", OPEN_LIGHT.lightened(0.3))
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.03))
	label.add_theme_constant_override("outline_size", 7)
	label.visible = not locked
	add_child(label)
	if not locked:
		open_amount = 1.0

func open() -> void:
	if not locked:
		return
	locked = false
	label.visible = true
	Sfx.play("boss_dash", 0.0, 0.6)
	create_tween().tween_property(self, "open_amount", 1.0, OPEN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func is_open() -> bool:
	return not locked and open_amount >= 0.8

func _physics_process(_delta: float) -> void:
	if used or not is_open():
		return
	for body in get_overlapping_bodies():
		if body.is_in_group(&"player") and not body.dead:
			used = true
			entered.emit()
			return

func _process(delta: float) -> void:
	time += delta
	if label.visible:
		label.position.y = -size.y - 64 + sin(time * 4.0) * 5.0
	queue_redraw()

func _draw() -> void:
	var half := size.x * 0.5
	var top := -size.y
	# Marco de acero con remaches.
	draw_rect(Rect2(-half - 22, top - 26, size.x + 44, size.y + 26), FRAME)
	draw_rect(Rect2(-half - 22, top - 26, size.x + 44, 6), FRAME_LIGHT)
	for x in range(int(-half - 12), int(half + 18), 24):
		draw_circle(Vector2(x, top - 14), 2.5, FRAME_LIGHT)
	# Interior oscuro y cortina que sube.
	draw_rect(Rect2(-half, top, size.x, size.y), INSIDE)
	var shutter_height := size.y * (1.0 - open_amount)
	if shutter_height > 1.0:
		draw_rect(Rect2(-half, top, size.x, shutter_height), SHUTTER)
		var y := top + 14.0
		while y < top + shutter_height:
			draw_line(Vector2(-half, y), Vector2(half, y), SHUTTER_DARK, 3.0)
			y += 16.0
		draw_rect(Rect2(-half, top + shutter_height - 10.0, size.x, 10.0), SHUTTER_DARK)
	else:
		# Abierta: luz verde que invita a entrar.
		var glow := 0.18 + 0.08 * sin(time * 3.0)
		draw_rect(Rect2(-half, top, size.x, size.y), Color(OPEN_LIGHT, glow))
		draw_colored_polygon(PackedVector2Array([Vector2(-18, -size.y * 0.5 - 22), Vector2(14, -size.y * 0.5), Vector2(-18, -size.y * 0.5 + 22)]), Color(OPEN_LIGHT, 0.7))
	# Franjas de peligro a los lados.
	for side in [-1.0, 1.0]:
		var x0: float = side * (half + 11.0) - 8.0
		var y := top
		while y < 0.0:
			draw_rect(Rect2(x0, y, 16, 12), Color(0.95, 0.72, 0.12) if int((y - top) / 12.0) % 2 == 0 else Color(0.1, 0.09, 0.08))
			y += 12.0
	# Luz de estado.
	var light: Color = LOCKED_LIGHT if locked else OPEN_LIGHT
	var pulse := 0.6 + 0.4 * sin(time * (6.0 if locked else 2.5))
	draw_circle(Vector2(0, top - 40), 18.0, Color(light, 0.25 * pulse))
	draw_circle(Vector2(0, top - 40), 9.0, light.darkened(0.3 * (1.0 - pulse)))
