extends Node2D

# Sigilo del Gauntlet: alarma global, invisibilidad de Viridy y su HUD.
# - Alarma: cada enemigo que descubre a Viridy la carga (uno más la carga más rápido). Golpearlo la pausa y
#   matarlo la hace bajar. Llena, todos saben dónde está. Para apagarla hay que huir o esconderse: baja
#   cuando nadie la ve durante EVASION_TIME.
# - Precaución: al apagarse queda una marca en la última posición conocida y durante CAUTION_TIME ven más
#   lejos, y que uno la descubra activa la alarma al instante.
# - Bush: dentro es invisible. Tras CLOAK_CHARGE dentro, al salir conserva la invisibilidad CLOAK_TIME.
#   Cualquier ataque la corta, pero ese ataque aún puede ejecutar a un enemigo normal.

enum Alert { CALM, ALARM, CAUTION }

const BUSH_SCRIPT := preload("res://bush.gd")
const FILL_TIME := 7.0
const EXTRA_SPOTTER_RATE := 0.6
const DRAIN_TIME := 5.0
const EVASION_TIME := 6.0
const CAUTION_TIME := 25.0
const CAUTION_VISION := 1.25
const SIREN_INTERVAL := 1.5
const CLOAK_CHARGE := 2.0
const CLOAK_TIME := 6.0
const STRIKE_WINDOW := 0.6
const REVEAL_TIME := 0.8
const CLOAK_TINT := Color(0.55, 1.0, 0.75, 0.35)
const ALARM_COLOR := Color(1.0, 0.18, 0.15)
const FILL_COLOR := Color(1.0, 0.6, 0.2)
const CAUTION_COLOR := Color(1.0, 0.85, 0.3)
const CLOAK_COLOR := Color(0.5, 1.0, 0.72)

var player: CharacterBody2D
var running := false
var alert := Alert.CALM
var level := 0.0
var evasion_left := 0.0
var caution_left := 0.0
var last_known := Vector2.ZERO
var siren_wait := 0.0
var bush_time := 0.0
var in_bush := false
var cloak_left := 0.0
var strike_left := 0.0
var reveal_left := 0.0
var bushes: Array = []
var last_known_mark: Node2D
var hud_root: Control
var alarm_panel: PanelContainer
var alarm_fill: ColorRect
var alarm_label: Label
var cloak_panel: PanelContainer
var cloak_fill: ColorRect
var cloak_label: Label

func _ready() -> void:
	add_to_group(&"stealth_director")
	_build_hud()

func spawn_bushes(points: Array, parent: Node) -> void:
	for at in points:
		var bush: Node2D = BUSH_SCRIPT.new()
		bush.position = at
		parent.add_child.call_deferred(bush)
		bushes.append(bush)

func begin_wave() -> void:
	running = true
	player = get_tree().get_first_node_in_group(&"player") as CharacterBody2D
	_clear_alert()

func stand_down() -> void:
	# Fin de la oleada: los guardianes no entienden de sigilo.
	running = false
	_clear_alert()
	bush_time = 0.0
	in_bush = false
	cloak_left = 0.0
	strike_left = 0.0
	_apply_tint()
	_update_hud()

func _clear_alert() -> void:
	alert = Alert.CALM
	level = 0.0
	evasion_left = 0.0
	caution_left = 0.0
	_clear_mark()

func _clear_mark() -> void:
	if is_instance_valid(last_known_mark):
		last_known_mark.queue_free()
	last_known_mark = null

# ---------- Consultas de los agentes

func alarm_active() -> bool:
	return alert == Alert.ALARM

func caution_active() -> bool:
	return alert == Alert.CAUTION

func vision_scale() -> float:
	return CAUTION_VISION if alert == Alert.CAUTION else 1.0

func player_cloaked() -> bool:
	return running and ((in_bush and reveal_left <= 0.0) or cloak_left > 0.0)

func cloak_strike() -> bool:
	return running and (player_cloaked() or strike_left > 0.0)

func on_discovered() -> void:
	if alert == Alert.CAUTION:
		trigger_alarm()

func trigger_alarm() -> void:
	if not running or alert == Alert.ALARM:
		return
	alert = Alert.ALARM
	level = 1.0
	evasion_left = EVASION_TIME
	siren_wait = 0.0
	_clear_mark()
	if is_instance_valid(player):
		last_known = player.global_position
	var director := get_parent()
	if director.has_method("_show_banner"):
		director._show_banner("¡ALARMA!", ALARM_COLOR)

# ---------- Tiempo

func _physics_process(delta: float) -> void:
	if not running or not is_instance_valid(player):
		return
	_update_cloak(delta)
	_update_alarm(delta)
	_update_hud()

func _update_alarm(delta: float) -> void:
	var spotters := 0
	var paused := false
	var seen := false
	for agent in get_tree().get_nodes_in_group(&"stealth_agents"):
		if agent.charging():
			spotters += 1
		elif agent.paused():
			paused = true
		seen = seen or agent.seeing
	if seen:
		last_known = player.global_position
	match alert:
		Alert.CALM:
			if spotters > 0:
				level += (1.0 + EXTRA_SPOTTER_RATE * (spotters - 1)) * delta / FILL_TIME
				if level >= 1.0:
					trigger_alarm()
			elif not paused:
				level = maxf(level - delta / DRAIN_TIME, 0.0)
		Alert.ALARM:
			evasion_left = EVASION_TIME if seen else evasion_left - delta
			siren_wait -= delta
			if siren_wait <= 0.0:
				siren_wait = SIREN_INTERVAL
				Sfx.play("alarm_siren")
			if evasion_left <= 0.0:
				_end_alarm()
		Alert.CAUTION:
			caution_left -= delta
			if caution_left <= 0.0:
				alert = Alert.CALM
				_clear_mark()

func _end_alarm() -> void:
	alert = Alert.CAUTION
	level = 0.0
	caution_left = CAUTION_TIME
	_spawn_mark()
	var director := get_parent()
	if director.has_method("_show_banner"):
		director._show_banner("PRECAUCIÓN", CAUTION_COLOR)

func _spawn_mark() -> void:
	# La silueta de Viridy donde la vieron por última vez.
	_clear_mark()
	var sprite: AnimatedSprite2D = player.animated_sprite
	var ghost := Sprite2D.new()
	ghost.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	ghost.scale = sprite.scale
	ghost.flip_h = sprite.flip_h
	ghost.position = last_known + sprite.position
	ghost.modulate = Color(1.0, 0.25, 0.2, 0.55)
	ghost.z_index = 2
	get_parent().get_parent().add_child(ghost)
	var tween := ghost.create_tween().set_loops()
	tween.tween_property(ghost, "modulate:a", 0.2, 0.7)
	tween.tween_property(ghost, "modulate:a", 0.55, 0.7)
	last_known_mark = ghost

func _update_cloak(delta: float) -> void:
	var cloaked_before := player_cloaked()
	strike_left = maxf(strike_left - delta, 0.0)
	reveal_left = maxf(reveal_left - delta, 0.0)
	var inside := false
	for bush in bushes:
		if is_instance_valid(bush) and bush.is_inside_tree() and bush.contains(player.global_position):
			inside = true
			if not in_bush:
				bush.rustle()
	if inside:
		if reveal_left <= 0.0:
			bush_time += delta
	else:
		if in_bush and bush_time >= CLOAK_CHARGE:
			cloak_left = CLOAK_TIME
		bush_time = 0.0
		cloak_left = maxf(cloak_left - delta, 0.0)
	in_bush = inside
	if player_cloaked() and _player_attacking():
		_break_cloak()
	if player_cloaked() != cloaked_before:
		Sfx.play("bush_rustle")
	_apply_tint()

func _player_attacking() -> bool:
	return player._is_attack_active() or player.combo.active or player.knife_throw_pose_timer > 0.0 or player.roar_active

func _break_cloak() -> void:
	strike_left = STRIKE_WINDOW
	cloak_left = 0.0
	bush_time = 0.0
	reveal_left = REVEAL_TIME

func _apply_tint() -> void:
	if not is_instance_valid(player):
		return
	var tint: Color = CLOAK_TINT if player_cloaked() else Color.WHITE
	if player.modulate != tint:
		player.modulate = tint

# ---------- HUD

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	hud_root = Control.new()
	hud_root.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hud_root.position.y = 100
	layer.add_child(hud_root)
	var alarm: Array = _make_bar(0.0)
	alarm_panel = alarm[0]
	alarm_fill = alarm[1]
	alarm_label = alarm[2]
	var cloak: Array = _make_bar(28.0)
	cloak_panel = cloak[0]
	cloak_fill = cloak[1]
	cloak_label = cloak[2]

func _make_bar(y: float) -> Array:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.07, 0.85)
	style.set_border_width_all(2)
	style.border_color = Color(1.0, 1.0, 1.0, 0.35)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(300, 24)
	panel.position = Vector2(-150, y)
	panel.hide()
	hud_root.add_child(panel)
	var fill := ColorRect.new()
	fill.size = Vector2(0, 20)
	fill.position = Vector2(2, 2)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(fill)
	panel.add_child(holder)
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.03))
	label.add_theme_constant_override("outline_size", 5)
	panel.add_child(label)
	return [panel, fill, label]

func _set_bar(panel: PanelContainer, fill: ColorRect, label: Label, text: String, ratio: float, color: Color) -> void:
	panel.show()
	label.text = text
	fill.color = Color(color, 0.8)
	fill.size = Vector2(296.0 * clampf(ratio, 0.0, 1.0), 20)

func _update_hud() -> void:
	match alert:
		Alert.ALARM:
			var blink: bool = int(Time.get_ticks_msec() / 250) % 2 == 0
			_set_bar(alarm_panel, alarm_fill, alarm_label, "¡ALARMA! · ESCÓNDETE", evasion_left / EVASION_TIME, ALARM_COLOR if blink else ALARM_COLOR.darkened(0.35))
		Alert.CAUTION:
			_set_bar(alarm_panel, alarm_fill, alarm_label, "PRECAUCIÓN", caution_left / CAUTION_TIME, CAUTION_COLOR)
		_:
			if level > 0.0:
				_set_bar(alarm_panel, alarm_fill, alarm_label, "ALARMA %d %%" % roundi(level * 100.0), level, FILL_COLOR)
			else:
				alarm_panel.hide()
	if not running:
		alarm_panel.hide()
		cloak_panel.hide()
	elif cloak_left > 0.0:
		_set_bar(cloak_panel, cloak_fill, cloak_label, "INVISIBLE %.1f s" % cloak_left, cloak_left / CLOAK_TIME, CLOAK_COLOR)
	elif in_bush and reveal_left <= 0.0:
		var charged: bool = bush_time >= CLOAK_CHARGE
		_set_bar(cloak_panel, cloak_fill, cloak_label, "OCULTA · LISTA PARA SALIR" if charged else "OCULTA", bush_time / CLOAK_CHARGE, CLOAK_COLOR)
	else:
		cloak_panel.hide()
