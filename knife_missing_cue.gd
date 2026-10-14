extends Node2D

# Aviso de "sin cuchillo" sobre Rengar al intentar un ataque que lo necesita: el cuchillo tachado en
# rojo, una flecha que apunta hacia donde quedó y la tecla para llamarlo. Aparece con un pequeño
# rebote y se desvanece solo.

const KNIFE_TEXTURE: Texture2D = preload("res://assets/sprites/player/rengar_knife.png")
const KNIFE_REGION := Rect2(48, 271, 243, 227)
const LIFETIME := 0.8
const WARN_COLOR := Color(1.0, 0.25, 0.2)
const ARROW_RADIUS := 26.0

var player: Node2D
var age := 0.0
var icon: Sprite2D
var hint: Label

func _ready() -> void:
	z_index = 10
	position = Vector2(0, -108)
	icon = Sprite2D.new()
	icon.texture = KNIFE_TEXTURE
	icon.region_enabled = true
	icon.region_rect = KNIFE_REGION
	icon.scale = Vector2.ONE * 0.11
	icon.modulate = Color(1.0, 0.55, 0.5)
	add_child(icon)
	hint = Label.new()
	hint.text = InputHints.binding("throw_knife")
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(1.0, 0.84, 0.42))
	hint.add_theme_color_override("font_outline_color", Color(0.1, 0.03, 0.02))
	hint.add_theme_constant_override("outline_size", 5)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size = Vector2(120, 18)
	hint.position = Vector2(-60, 16)
	add_child(hint)

func restart() -> void:
	# Otro intento mientras sigue visible: vuelve a rebotar en vez de apilar avisos.
	age = 0.0

func _process(delta: float) -> void:
	age += delta / max(Engine.time_scale, 0.01)
	if age >= LIFETIME:
		queue_free()
		return
	# Rebote al aparecer y un temblor corto de "no".
	var pop: float = 1.0 + 0.35 * max(1.0 - age / 0.15, 0.0)
	scale = Vector2.ONE * pop
	icon.position.x = sin(age * 60.0) * 3.0 * max(1.0 - age / 0.3, 0.0)
	modulate.a = clamp((LIFETIME - age) / 0.25, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	# Tachado rojo sobre el cuchillo.
	draw_line(Vector2(-13, 11), Vector2(13, -11), Color(0.15, 0.02, 0.02), 6.0, true)
	draw_line(Vector2(-13, 11), Vector2(13, -11), WARN_COLOR, 3.5, true)
	var knife: Node2D = player.thrown_knife if is_instance_valid(player) else null
	if not is_instance_valid(knife):
		return
	# Flecha alrededor del icono apuntando al cuchillo (dónde está y por dónde volverá).
	var direction: Vector2 = (knife.global_position - global_position).normalized()
	if direction == Vector2.ZERO:
		return
	var tip: Vector2 = direction * (ARROW_RADIUS + 8.0)
	var base: Vector2 = direction * ARROW_RADIUS
	var side: Vector2 = direction.orthogonal() * 6.0
	var arrow := PackedVector2Array([tip, base + side, base - side])
	draw_colored_polygon(arrow, WARN_COLOR)
	draw_polyline(PackedVector2Array([tip, base + side, base - side, tip]), Color(0.1, 0.03, 0.02), 1.5, true)
