extends Node

# Hechizo de RB en el Gauntlet: es un toggle (un toque lo activa y otro lo apaga). Activo gasta Enfoque
# (Upgrades.focus) y pone cámara lenta; se apaga solo al vaciarse el Enfoque o al morir Viridy.
# Con la mejora Reloj detenido, en cambio, enemigos y proyectiles se paran y Viridy sigue a velocidad normal.
# El Enfoque vuelve solo, despacio, y sobre todo golpeando y ejecutando (Upgrades).
# Gasta en tiempo real: la cámara lenta no alarga el hechizo.

const SLOW_DRAIN := 25.0
const STOP_DRAIN := 34.0
const REGEN := 2.0
const MIN_CAST := 20.0
const MAX_STEP := 0.1
const BAR_WIDTH := 236.0
const COLOR := Color(0.6, 0.9, 1.0)
const STOP_TINT := Color(0.45, 0.7, 1.0, 0.14)

var player: Node
var casting := false
var world_stopped := false
var last_usec := 0
var was_held := false
var overlay: ColorRect
var bar_fill: ColorRect
var bar_min: ColorRect
var bar_label: Label

func _ready() -> void:
	_build_hud()
	last_usec = Time.get_ticks_usec()

func _exit_tree() -> void:
	cancel()

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var step: float = minf((now - last_usec) / 1000000.0, MAX_STEP)
	last_usec = now
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player")
		return
	var held: bool = Input.is_action_pressed("slow_motion") and not player.dead
	var pressed: bool = held and not was_held and not get_tree().paused
	was_held = held
	if casting:
		Upgrades.add_focus(-(STOP_DRAIN if world_stopped else SLOW_DRAIN) * step)
		if pressed or player.dead or Upgrades.focus <= 0.0:
			cancel()
		elif world_stopped:
			# También lo que aparezca durante el hechizo.
			_hold_world(true)
	elif pressed and Upgrades.focus >= MIN_CAST:
		_cast()
	else:
		Upgrades.add_focus(REGEN * step)
	_update_hud()

func _cast() -> void:
	casting = true
	world_stopped = Upgrades.has("time_stop")
	# Reloj de PixelFX que se abre alrededor de Viridy.
	Fx.time_stop(player.get_parent(), player.global_position + Vector2(0, -30), COLOR)
	if world_stopped:
		_hold_world(true)
		overlay.show()
		Sfx.play("time_stop")
	else:
		TimeControl.set_slow_motion(true)
		Sfx.play("time_stop", -6.0, 1.5)

func cancel() -> void:
	if not casting:
		return
	casting = false
	if world_stopped:
		_hold_world(false)
		overlay.hide()
	else:
		TimeControl.set_slow_motion(false)
	world_stopped = false

func _hold_world(on: bool) -> void:
	for enemy in get_tree().get_nodes_in_group(&"ruby_enemies"):
		var core: Node = enemy.get_node_or_null("RubyCore")
		if core != null:
			core.time_stopped = on
	for group in [&"projectiles", &"time_stoppable"]:
		for thing in get_tree().get_nodes_in_group(group):
			# Lo que Viridy devolvió sigue siendo suyo.
			thing.set_physics_process(not on or thing.get("reflected") == true)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 11
	add_child(layer)
	overlay = ColorRect.new()
	overlay.color = STOP_TINT
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.hide()
	layer.add_child(overlay)
	bar_label = Label.new()
	bar_label.position = Vector2(28, 108)
	bar_label.add_theme_font_size_override("font_size", 14)
	bar_label.add_theme_color_override("font_color", COLOR)
	bar_label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.08))
	bar_label.add_theme_constant_override("outline_size", 5)
	layer.add_child(bar_label)
	var back := ColorRect.new()
	back.color = Color(0.05, 0.05, 0.07, 0.85)
	back.position = Vector2(28, 130)
	back.size = Vector2(BAR_WIDTH, 8)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(back)
	bar_fill = ColorRect.new()
	bar_fill.color = COLOR
	bar_fill.position = Vector2(29, 131)
	bar_fill.size = Vector2(0, 6)
	bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bar_fill)
	# Lo mínimo para lanzarlo.
	bar_min = ColorRect.new()
	bar_min.color = Color(1, 1, 1, 0.6)
	bar_min.size = Vector2(2, 8)
	bar_min.position = Vector2(28, 130)
	bar_min.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bar_min)

func _update_hud() -> void:
	var capacity: float = Upgrades.focus_capacity()
	bar_fill.size.x = (BAR_WIDTH - 2.0) * Upgrades.focus / capacity
	bar_min.position.x = 28.0 + BAR_WIDTH * MIN_CAST / capacity
	var button: String = InputHints.binding("slow_motion").get_slice(" / ", 0)
	bar_label.text = "TIEMPO DETENIDO" if world_stopped else ("ENFOQUE · %s" % button if button != "" else "ENFOQUE")
	bar_fill.modulate.a = 1.0 if Upgrades.focus >= MIN_CAST or casting else 0.45
