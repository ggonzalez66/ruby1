extends Node2D

const Catalog := preload("res://weapon_catalog.gd")
@export var weapon_id: StringName = &"sword"
var sprite: Sprite2D
var label: Label
var prompt: Label
var clock := 0.0

func _ready() -> void:
	add_to_group(&"weapon_pickups")
	z_index = 4
	sprite = Sprite2D.new()
	sprite.texture = Catalog.texture(weapon_id)
	sprite.scale = Vector2.ONE * 0.65
	sprite.rotation = -0.55
	sprite.position.y = -74
	add_child(sprite)
	label = Label.new()
	label.text = Catalog.NAMES[weapon_id]
	label.position = Vector2(-100, -139)
	label.size = Vector2(200, 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color("123129"))
	add_child(label)
	prompt = Label.new()
	prompt.position = Vector2(-185, -180)
	prompt.size = Vector2(370, 34)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 14)
	prompt.add_theme_constant_override("outline_size", 4)
	prompt.add_theme_color_override("font_outline_color", Color("123129"))
	add_child(prompt)

func _physics_process(delta: float) -> void:
	clock += delta
	sprite.position.y = -74 + sin(clock * 2) * 7
	var player := get_tree().get_first_node_in_group(&"player")
	var near: bool = player != null and player.global_position.distance_to(global_position) < 75.0
	prompt.visible = near
	if near:
		prompt.text = "%s · %s" % [InputHints.binding("move_up"), Catalog.DESCRIPTIONS[weapon_id]]
		if Input.is_action_just_pressed("move_up") and not Input.is_action_pressed("heavy_attack"):
			if player.weapons.equip(weapon_id):
				Sfx.play("knife_catch")
	queue_redraw()

func _draw() -> void:
	draw_ellipse(Vector2(0, -4), Vector2(40, 8), Color(0.28, 0.75, 0.55, 0.25))
	draw_arc(Vector2(0, -65), 43, 0, TAU, 40, Color(0.45, 1, 0.7, 0.22), 2, true)
	if weapon_id == &"unarmed":
		for i in range(3):
			draw_line(Vector2(-18 + i * 12, -86), Vector2(-28 + i * 12, -50), Color(0.6, 1, 0.75), 4, true)

func draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	draw_set_transform(center, 0, radii)
	draw_circle(Vector2.ZERO, 1, color)
	draw_set_transform(Vector2.ZERO)
