extends Control

# Panel de Ferocity arriba a la derecha (estilo ULTRAKILL): letra del rango, nombre, barra de
# progreso, aviso de IMPARABLE y el registro de acciones (+PARRY, +REBOTE...) que se desvanece.

const PANEL_WIDTH := 250.0
const LOG_LIFETIME := 2.6
const LOG_MAX := 7
const MERGE_TIME := 1.0

var letter: Label
var rank_name: Label
var bar_fill: ColorRect
var unstoppable_label: Label
var log_box: VBoxContainer
var logs: Array = []
var shown_alpha := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Anclado a la esquina superior derecha (se mantiene al cambiar el tamaño de la ventana).
	anchor_left = 1.0
	anchor_right = 1.0
	offset_left = -PANEL_WIDTH - 18.0
	offset_right = -18.0
	offset_top = 66.0
	offset_bottom = 466.0
	var title := _label("FEROCITY", 13, Color(1.0, 0.92, 0.8, 0.8))
	title.position = Vector2(0, 0)
	title.size = Vector2(PANEL_WIDTH, 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(title)
	letter = _label("D", 54, Color.WHITE)
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	letter.position = Vector2(PANEL_WIDTH - 130, 10)
	letter.size = Vector2(130, 64)
	letter.pivot_offset = Vector2(110, 34)
	add_child(letter)
	rank_name = _label("", 16, Color.WHITE)
	rank_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rank_name.position = Vector2(0, 72)
	rank_name.size = Vector2(PANEL_WIDTH, 20)
	add_child(rank_name)
	var bar_back := ColorRect.new()
	bar_back.color = Color(0.05, 0.03, 0.03, 0.75)
	bar_back.position = Vector2(PANEL_WIDTH - 200, 96)
	bar_back.size = Vector2(200, 6)
	add_child(bar_back)
	bar_fill = ColorRect.new()
	bar_fill.position = bar_back.position
	bar_fill.size = Vector2(0, 6)
	add_child(bar_fill)
	unstoppable_label = _label("IMPARABLE", 15, Color.WHITE)
	unstoppable_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	unstoppable_label.position = Vector2(0, 106)
	unstoppable_label.size = Vector2(PANEL_WIDTH, 20)
	add_child(unstoppable_label)
	log_box = VBoxContainer.new()
	log_box.position = Vector2(0, 130)
	log_box.size = Vector2(PANEL_WIDTH, 200)
	log_box.add_theme_constant_override("separation", 0)
	add_child(log_box)
	modulate.a = 0.0
	Ferocity.logged.connect(_on_logged)
	Ferocity.rank_changed.connect(_on_rank_changed)

func _process(delta: float) -> void:
	var real_delta: float = delta / max(Engine.time_scale, 0.01)
	var info: Dictionary = Ferocity.rank_info()
	var color: Color = info["color"]
	if Ferocity.rank == Ferocity.RANKS.size() - 1:
		# SSS: el dorado parpadea hacia blanco.
		color = color.lerp(Color.WHITE, 0.35 + 0.35 * sin(Time.get_ticks_msec() / 90.0))
	letter.text = info["letter"]
	letter.add_theme_color_override("font_color", color)
	rank_name.text = info["name"]
	rank_name.add_theme_color_override("font_color", color.lightened(0.2))
	bar_fill.color = color
	bar_fill.size.x = 200.0 * Ferocity.rank_progress()
	letter.scale = letter.scale.lerp(Vector2.ONE, clamp(10.0 * real_delta, 0.0, 1.0))
	unstoppable_label.visible = Ferocity.is_unstoppable()
	unstoppable_label.add_theme_color_override("font_color", Color.WHITE if int(Time.get_ticks_msec() / 120) % 2 == 0 else color)
	# Visible solo con algo de estilo (o mientras quedan logs).
	var wanted: float = 1.0 if Ferocity.points > 1.0 or not logs.is_empty() else 0.0
	shown_alpha = move_toward(shown_alpha, wanted, real_delta * 3.0)
	modulate.a = shown_alpha
	for entry in logs.duplicate():
		entry["age"] += real_delta
		var label: Label = entry["label"]
		label.modulate.a = clamp((LOG_LIFETIME - entry["age"]) / 0.6, 0.0, 1.0)
		if entry["age"] >= LOG_LIFETIME:
			label.queue_free()
			logs.erase(entry)

func _on_logged(text: String, color: Color) -> void:
	# El mismo texto seguido se agrupa como "+REBOTE x3".
	if not logs.is_empty():
		var last: Dictionary = logs[0]
		if last["text"] == text and last["age"] < MERGE_TIME:
			last["count"] += 1
			last["age"] = 0.0
			last["label"].text = "%s x%d" % [text, last["count"]]
			return
	var label := _label(text, 15, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.custom_minimum_size = Vector2(PANEL_WIDTH, 18)
	log_box.add_child(label)
	log_box.move_child(label, 0)
	logs.push_front({"text": text, "label": label, "age": 0.0, "count": 1})
	while logs.size() > LOG_MAX:
		var old: Dictionary = logs.pop_back()
		old["label"].queue_free()

func _on_rank_changed(rank: int, previous: int) -> void:
	if rank > previous:
		letter.scale = Vector2.ONE * 1.45

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.02, 0.02))
	label.add_theme_constant_override("outline_size", 6 if font_size < 30 else 10)
	return label
