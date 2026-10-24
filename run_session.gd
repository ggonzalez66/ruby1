extends CanvasLayer

# Inicio común de modos, cronómetro por etapa y récord local con replay visual a 30 Hz.
# El replay nunca participa en la física. Reloj y replay usan segundos reales de juego activo.
const STAGES := ["res://main.tscn", "res://stage2.tscn", "res://stage3.tscn", "res://stage4.tscn"]
const MODES := ["res://main.tscn", "res://stage2.tscn", "res://stage3.tscn", "res://stage4.tscn", "res://gauntlet.tscn", "res://sky_stairs.tscn"]
const SKY_STAGE := "res://sky_stairs.tscn"
const TIMED_STAGES := ["res://main.tscn", "res://stage2.tscn", "res://stage3.tscn", "res://stage4.tscn", SKY_STAGE]
const RECORD_DIR := "user://records_v1"
const SAMPLE_INTERVAL := 1.0 / 30.0
const COUNTDOWN_SECONDS := 3.0

var storage_directory := RECORD_DIR
var records_previous_focus: Control
var player: Node2D
var level: Node
var stage_path := ""
var elapsed := 0.0
var running := false
var finished := false
var countdown_active := false
var countdown_left := 0.0
var countdown_tick := 3
var samples: Array = []
var sample_wait := 0.0
var best_frames: Array = []
var ghost_index := 0
var ghost: Sprite2D
var record: Dictionary = {}
var result: Dictionary = {}
var overlay: Control
var ready_label: Label
var countdown_label: Label
var go_left := 0.0
var records_panel: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 40
	_build_countdown()

func attach_player(new_player: Node2D) -> void:
	var scene := new_player.get_parent()
	# Escenas instanciadas por herramientas o pruebas no inician una partida de la aplicación.
	if scene != get_tree().current_scene or scene.scene_file_path not in MODES:
		return
	begin_run(new_player, OS.get_environment("RUBY1_SKIP_COUNTDOWN") != "1")

func begin_run(new_player: Node2D, with_countdown: bool = true) -> void:
	_clear_run()
	player = new_player
	level = player.get_parent()
	stage_path = level.scene_file_path
	elapsed = 0.0
	finished = false
	result = {}
	samples = []
	sample_wait = 0.0
	ghost_index = 0
	record = load_record(stage_path)
	best_frames = record.get("frames", [])
	if not best_frames.is_empty():
		ghost = Sprite2D.new()
		var palette := ShaderMaterial.new()
		palette.shader = preload("res://shaders/charge_glow.gdshader")
		ghost.material = palette
		ghost.name = "BestTimeGhost"
		ghost.modulate = Color(0.35, 0.85, 1.0, 0.38)
		ghost.z_index = 2
		level.add_child(ghost)
		_update_ghost()
	if with_countdown:
		countdown_active = true
		countdown_left = COUNTDOWN_SECONDS
		countdown_tick = 3
		ready_label.text = "Ready"
		ready_label.add_theme_color_override("font_color", Color(1.0, 0.12, 0.16))
		countdown_label.text = "3.00"
		overlay.show()
		get_tree().paused = true
		Sfx.play("ready")
	else:
		_start_clock()

func _clear_run() -> void:
	if countdown_active:
		get_tree().paused = false
	countdown_active = false
	running = false
	go_left = 0.0
	overlay.hide()
	if is_instance_valid(ghost):
		ghost.queue_free()
	ghost = null
	player = null
	level = null
	samples = []
	best_frames = []
	record = {}
	result = {}
	stage_path = ""
	elapsed = 0.0
	finished = false

func _process(delta: float) -> void:
	if level != null and (not is_instance_valid(level) or not level.is_inside_tree()):
		_clear_run()
		return
	var real_delta: float = delta / max(Engine.time_scale, 0.0001)
	if countdown_active:
		countdown_left = max(countdown_left - real_delta, 0.0)
		countdown_label.text = "%.2f" % countdown_left
		while countdown_tick > 1 and countdown_left <= countdown_tick - 1:
			countdown_tick -= 1
			Sfx.play("countdown_tick", 0.0, 1.0 + (3 - countdown_tick) * 0.08)
		if countdown_left <= 0.0:
			_start_clock()
	elif go_left > 0.0:
		go_left = max(go_left - real_delta, 0.0)
		if go_left == 0.0:
			overlay.hide()

func _physics_process(delta: float) -> void:
	if not running or countdown_active or get_tree().paused or not is_instance_valid(player):
		return
	elapsed += delta / max(Engine.time_scale, 0.0001)
	if stage_path in TIMED_STAGES:
		sample_wait -= delta / max(Engine.time_scale, 0.0001)
		if sample_wait <= 0.0:
			sample_wait += SAMPLE_INTERVAL
			_record_frame()
		_update_ghost()

func _start_clock() -> void:
	var show_go := countdown_active
	countdown_active = false
	get_tree().paused = false
	running = true
	_record_frame()
	if show_go:
		ready_label.text = "GO!"
		ready_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.35))
		countdown_label.text = "0.00"
		go_left = 0.75
		Sfx.play("go")

func _input(event: InputEvent) -> void:
	if is_instance_valid(records_panel) and records_panel.visible and event.is_action_pressed("ui_cancel"):
		_close_records()
		get_viewport().set_input_as_handled()
	elif countdown_active:
		get_viewport().set_input_as_handled()

func finish_stage() -> Dictionary:
	if finished or not running:
		return result
	_record_frame()
	running = false
	finished = true
	if stage_path not in TIMED_STAGES:
		return result
	var previous_best := float(record.get("best", INF))
	var is_best := elapsed < previous_best
	var times: Array = record.get("times", []).duplicate()
	times.append(elapsed)
	times.sort()
	if times.size() > 10:
		times.resize(10)
	record["times"] = times
	if is_best:
		record["best"] = elapsed
		record["frames"] = samples.duplicate(true)
	var saved := _save_record(stage_path, record)
	result = {"time": elapsed, "best": is_best, "saved": saved}
	return result

func _record_frame() -> void:
	if not is_instance_valid(player) or stage_path not in TIMED_STAGES:
		return
	var sprite: AnimatedSprite2D = player.animated_sprite
	var frame := [elapsed, player.position.x, player.position.y, String(sprite.animation), sprite.frame,
		sprite.scale.x, sprite.scale.y, sprite.position.x, sprite.position.y, sprite.rotation, sprite.flip_h]
	if not samples.is_empty() and is_equal_approx(float(samples[-1][0]), elapsed):
		samples[-1] = frame
	else:
		samples.append(frame)

func _update_ghost() -> void:
	if not is_instance_valid(ghost) or best_frames.is_empty() or not is_instance_valid(player):
		return
	if elapsed > float(record.get("best", 0.0)):
		ghost.hide()
		return
	while ghost_index + 1 < best_frames.size() and float(best_frames[ghost_index + 1][0]) <= elapsed:
		ghost_index += 1
	var a: Array = best_frames[ghost_index]
	var b: Array = best_frames[min(ghost_index + 1, best_frames.size() - 1)]
	var weight := clampf((elapsed - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001), 0.0, 1.0)
	var frames: SpriteFrames = player.animated_sprite.sprite_frames
	var animation := StringName(a[3])
	if not frames.has_animation(animation):
		return
	ghost.texture = frames.get_frame_texture(animation, clampi(int(a[4]), 0, frames.get_frame_count(animation) - 1))
	ghost.material.set_shader_parameter("jade_amount", 1.0 if player.uses_jade_palette(ghost.texture) else 0.0)
	var feet := Vector2(float(a[1]), float(a[2])).lerp(Vector2(float(b[1]), float(b[2])), weight)
	ghost.position = feet + Vector2(float(a[7]), float(a[8])).lerp(Vector2(float(b[7]), float(b[8])), weight)
	ghost.scale = Vector2(float(a[5]), float(a[6]))
	ghost.rotation = lerp_angle(float(a[9]), float(b[9]), weight)
	if animation in [&"uppercut", &"charge"]:
		# Los replays anteriores guardaron el giro/escala del uppercut líquido o del dash con arma.
		# La trayectoria se conserva; las poses actuales mantienen sus proporciones y orientación.
		ghost.scale = Vector2.ONE * player.CHARACTER_VISUAL_SCALE * player.ANIMATION_VISUAL_SCALES[animation]
		ghost.position = feet + Vector2(0.0, -ghost.texture.get_height() * ghost.scale.y * 0.5)
		ghost.rotation = 0.0
	if animation in player.ARCADE_ANIMATIONS:
		var layout: Transform2D = player.arcade_frame_layout(animation, ghost.texture)
		ghost.scale = layout.get_scale()
		ghost.position = feet + layout.origin
		if animation not in [&"heavy_aerial", &"liquid_launch", &"ruby_spin"]:
			ghost.rotation = 0.0
	ghost.flip_h = bool(a[10])
	ghost.show()

func _record_path(scene: String) -> String:
	return storage_directory.path_join(scene.get_file().get_basename() + ".json")

func load_record(scene: String) -> Dictionary:
	if scene not in TIMED_STAGES:
		return {}
	var path := _record_path(scene)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or parsed.get("version", 0) != 1:
		return {}
	var times = parsed.get("times", [])
	var frames = parsed.get("frames", [])
	if not times is Array or not frames is Array:
		return {}
	var best = parsed.get("best", 0.0)
	if not (best is float or best is int) or not is_finite(float(best)) or float(best) <= 0.0:
		return {}
	for time in times:
		if not (time is float or time is int) or not is_finite(float(time)) or float(time) <= 0.0:
			return {}
	var previous_time := -1.0
	for frame in frames:
		if not frame is Array or frame.size() != 11 or not frame[3] is String or not frame[10] is bool:
			return {}
		for index in [0, 1, 2, 4, 5, 6, 7, 8, 9]:
			if not (frame[index] is float or frame[index] is int) or not is_finite(float(frame[index])):
				return {}
		if float(frame[0]) < previous_time:
			return {}
		previous_time = float(frame[0])
	return parsed

func _save_record(scene: String, data: Dictionary) -> bool:
	if DirAccess.make_dir_recursive_absolute(storage_directory) != OK:
		return false
	var path := _record_path(scene)
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	data["version"] = 1
	file.store_string(JSON.stringify(data))
	file.flush()
	var success := file.get_error() == OK
	file.close()
	if not success:
		return false
	return DirAccess.rename_absolute(path + ".tmp", path) == OK

func _build_countdown() -> void:
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(column)
	ready_label = _label("Ready", 80, Color(1.0, 0.12, 0.16))
	countdown_label = _label("3.00", 42, Color.WHITE)
	column.add_child(ready_label)
	column.add_child(countdown_label)
	overlay.hide()

func _close_records() -> void:
	records_panel.hide()
	if is_instance_valid(records_previous_focus) and records_previous_focus.is_inside_tree():
		records_previous_focus.grab_focus()

func show_records() -> void:
	records_previous_focus = get_viewport().gui_get_focus_owner()
	if is_instance_valid(records_panel):
		records_panel.queue_free()
	records_panel = PanelContainer.new()
	records_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(records_panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.06, 0.05, 0.98)
	style.set_content_margin_all(24)
	records_panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	records_panel.add_child(column)
	column.add_child(_label("TOP 10 · TORRE Y ESCALERA AL CIELO", 32, Color(1.0, 0.78, 0.35)))
	column.add_child(_label("El fantasma de tu mejor tiempo aparece al jugar cada etapa.", 16, Color(0.6, 0.9, 1.0)))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var columns := HBoxContainer.new()
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 20)
	scroll.add_child(columns)
	for index in range(TIMED_STAGES.size()):
		var board := VBoxContainer.new()
		board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_child(board)
		board.add_child(_label("ESCALERA AL CIELO" if TIMED_STAGES[index] == SKY_STAGE else "ETAPA %d" % (index + 1), 22, Color(1.0, 0.78, 0.35)))
		var times: Array = load_record(TIMED_STAGES[index]).get("times", [])
		for place in range(10):
			var time_text := Stats.format_time(float(times[place])) if place < times.size() else "—"
			board.add_child(_label("%2d.  %s" % [place + 1, time_text], 20, Color.WHITE))
	var close := Button.new()
	close.text = "Volver"
	close.custom_minimum_size.y = 46
	close.pressed.connect(_close_records)
	column.add_child(close)
	close.grab_focus()

func _label(value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.03))
	label.add_theme_constant_override("outline_size", 6)
	return label
