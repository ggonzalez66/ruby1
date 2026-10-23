extends Area2D

# Portal del Gauntlet: un óvalo de energía que gira, con su rótulo encima. Al entrar Rengar emite
# "entered" (el director decide: seguir a la siguiente ronda o terminar).

signal entered

@export var label_text := "SEGUIR"
@export var color := Color(0.4, 0.8, 1.0)
@export var confirm_finish := false

const SIZE := Vector2(70, 140)

var time := 0.0
var used := false
var waiting_for_exit := false
var confirmation_pending := false
var confirmation: CanvasLayer
var cancel_button: Button
var finish_button: Button
var previous_pause := false
var previous_focus: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	body_exited.connect(_on_body_exited)
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
	if used or waiting_for_exit or confirmation_pending or not body.is_in_group(&"player"):
		return
	if confirm_finish:
		confirmation_pending = true
		_show_confirmation.call_deferred()
		return
	used = true
	entered.emit()

func _on_body_exited(body: Node) -> void:
	if body.is_in_group(&"player"):
		waiting_for_exit = false

func _show_confirmation() -> void:
	if used or not confirmation_pending or confirmation != null:
		return
	previous_pause = get_tree().paused
	previous_focus = get_viewport().gui_get_focus_owner()
	add_to_group(&"gauntlet_finish_confirmation")
	confirmation = CanvasLayer.new()
	confirmation.layer = 60
	confirmation.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(confirmation)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.01, 0.04, 0.03, 0.80)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirmation.add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.11, 0.09)
	style.border_color = Color(0.7, 0.85, 0.45)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	var title := Label.new()
	title.text = "¿Terminar el Gauntlet?"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var description := Label.new()
	description.text = "Tu run finalizará y verás los resultados."
	description.add_theme_font_size_override("font_size", 18)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(description)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	cancel_button = Button.new()
	cancel_button.text = "Seguir jugando"
	cancel_button.custom_minimum_size = Vector2(210, 48)
	cancel_button.pressed.connect(_cancel_finish)
	buttons.add_child(cancel_button)
	finish_button = Button.new()
	finish_button.text = "Terminar run"
	finish_button.custom_minimum_size = Vector2(210, 48)
	finish_button.pressed.connect(_confirm_finish)
	buttons.add_child(finish_button)
	cancel_button.focus_neighbor_right = cancel_button.get_path_to(finish_button)
	finish_button.focus_neighbor_left = finish_button.get_path_to(cancel_button)
	get_tree().paused = true
	cancel_button.grab_focus()
	Sfx.play("ui_select")

func _input(event: InputEvent) -> void:
	if confirmation == null:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_cancel_finish()

func _cancel_finish() -> void:
	if confirmation == null:
		return
	waiting_for_exit = true
	_close_confirmation()

func _confirm_finish() -> void:
	if confirmation == null or used:
		return
	used = true
	_close_confirmation()
	entered.emit()

func _close_confirmation() -> void:
	confirmation_pending = false
	remove_from_group(&"gauntlet_finish_confirmation")
	if is_instance_valid(confirmation):
		confirmation.hide()
		confirmation.queue_free()
	confirmation = null
	get_tree().paused = previous_pause
	if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree():
		previous_focus.grab_focus()

func _exit_tree() -> void:
	if confirmation != null:
		get_tree().paused = previous_pause
