extends Control

# Panel de Ferocity arriba a la derecha (estilo ULTRAKILL): el rango como inicial del nombre
# ([D]esatado, [SS]anguinario...), barra de progreso, aviso de IMPARABLE y el registro de acciones
# (+PARRY, +REBOTE x3...) que se desvanece.
# - Cada vez que una acción encadenada suma (x2, x3...), su línea destella en dorado y da un salto.
# - Si un golpe quita estilo, la barra se marca en rojo; al bajar de rango, rango y barra tiemblan
#   y se desmoronan en astillas.
# - Si una acción no puede subir de rango (acrobacia desde S, golpe débil, correr) y la barra está en
#   el tope, el final de la barra destella en blanco: hace falta daño, un parry o un shine.

const PANEL_WIDTH := 280.0
const BAR_WIDTH := 200.0
const LOG_LIFETIME := 2.6
const LOG_MAX := 7
# Repetir la misma acción dentro de este tiempo la agrupa en la misma línea.
const MERGE_TIME := 1.6
const LETTER_SIZE := 54
const REST_SIZE := 26
const CHAIN_GOLD := Color(1.0, 0.82, 0.25)
const LOSS_COLOR := Color(1.0, 0.16, 0.12)
const FLASH_TIME := 0.45
const POP_TIME := 0.28
const LOSS_TIME := 0.7
const SHAKE_TIME := 0.6

var airtime_label: Label
var rank_row: Control
var special_label: Label
var letter: Label
var rest: Label
var bar_root: Control
var bar_fill: ColorRect
var bar_loss: ColorRect
var bar_cap: ColorRect
var cap_flash := 0.0
var unstoppable_label: Label
var log_box: VBoxContainer
var shard_layer: Control
var logs: Array = []
var shards: Array = []
var shown_alpha := 0.0
var shown_rank := -1
var bar_flash := 0.0
var loss_timer := 0.0
var loss_from := 0.0
var shake_timer := 0.0

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
	# Letra grande y el resto del nombre a continuación, alineados por la base del texto.
	rank_row = Control.new()
	rank_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rank_row.size = Vector2(PANEL_WIDTH, 70)
	add_child(rank_row)
	letter = _label("D", LETTER_SIZE, Color.WHITE)
	rank_row.add_child(letter)
	rest = _label("", REST_SIZE, Color.WHITE)
	rank_row.add_child(rest)
	special_label = _label("Wrath of Nature", 27, Color(1.0, 0.15, 0.25))
	special_label.position = Vector2(14, 32)
	special_label.hide()
	add_child(special_label)
	bar_root = Control.new()
	bar_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_root.position = _bar_home()
	bar_root.size = Vector2(BAR_WIDTH, 6)
	add_child(bar_root)
	var bar_back := ColorRect.new()
	bar_back.color = Color(0.05, 0.03, 0.03, 0.75)
	bar_back.size = Vector2(BAR_WIDTH, 6)
	bar_root.add_child(bar_back)
	# Tramo perdido: rojo, se encoge hasta el nuevo valor.
	bar_loss = ColorRect.new()
	bar_loss.color = LOSS_COLOR
	bar_loss.size = Vector2(0, 6)
	bar_root.add_child(bar_loss)
	bar_fill = ColorRect.new()
	bar_fill.size = Vector2(0, 6)
	bar_root.add_child(bar_fill)
	# Tope de la barra: destella cuando una acción no puede pasar al rango siguiente.
	bar_cap = ColorRect.new()
	bar_cap.color = Color(1, 1, 1, 0)
	bar_cap.position = Vector2(BAR_WIDTH - 4, -3)
	bar_cap.size = Vector2(4, 12)
	bar_root.add_child(bar_cap)
	unstoppable_label = _label("IMPARABLE", 15, Color.WHITE)
	unstoppable_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	unstoppable_label.position = Vector2(0, 92)
	unstoppable_label.size = Vector2(PANEL_WIDTH, 20)
	add_child(unstoppable_label)
	airtime_label = _label("", 16, Color(0.6, 0.9, 1.0))
	airtime_label.position = Vector2(0, 115)
	airtime_label.size = Vector2(PANEL_WIDTH, 22)
	airtime_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(airtime_label)
	log_box = VBoxContainer.new()
	log_box.position = Vector2(0, 142)
	log_box.size = Vector2(PANEL_WIDTH, 200)
	log_box.add_theme_constant_override("separation", 0)
	add_child(log_box)
	shard_layer = Control.new()
	shard_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shard_layer)
	modulate.a = 0.0
	_layout_rank(Ferocity.rank)
	Ferocity.logged.connect(_on_logged)
	Ferocity.rank_changed.connect(_on_rank_changed)
	Ferocity.penalized.connect(_on_penalized)
	Ferocity.promotion_blocked.connect(func(): cap_flash = 0.4)

func _process(delta: float) -> void:
	var special := not Ferocity.special_name.is_empty()
	rank_row.visible = not special
	special_label.visible = special
	special_label.text = Ferocity.special_name
	var status := " · PAUSA" if Ferocity.airtime_paused else ("" if Ferocity.airtime_active else " · FIN")
	airtime_label.text = "AIRE %.2f s%s" % [Ferocity.airtime, status]
	airtime_label.visible = Ferocity.airtime > 0.0
	var real_delta: float = delta / max(Engine.time_scale, 0.01)
	if Ferocity.rank != shown_rank:
		_layout_rank(Ferocity.rank)
	var info: Dictionary = Ferocity.rank_info()
	var color: Color = info["color"]
	if special:
		color = Color(1.0, 0.12, 0.22)
	if Ferocity.rank == Ferocity.RANKS.size() - 1:
		# SSS: el dorado parpadea hacia blanco.
		color = color.lerp(Color.WHITE, 0.35 + 0.35 * sin(Time.get_ticks_msec() / 90.0))
	letter.add_theme_color_override("font_color", color)
	rest.add_theme_color_override("font_color", color.lightened(0.2))
	letter.scale = letter.scale.lerp(Vector2.ONE, clamp(10.0 * real_delta, 0.0, 1.0))
	_update_bar(color, real_delta)
	_update_shake(real_delta)
	_update_shards(real_delta)
	unstoppable_label.visible = Ferocity.is_unstoppable() or special
	unstoppable_label.add_theme_color_override("font_color", Color.WHITE if int(Time.get_ticks_msec() / 120) % 2 == 0 else color)
	# Visible solo con algo de estilo (o mientras quedan logs o astillas).
	var wanted: float = 1.0 if special or Ferocity.points > 1.0 or Ferocity.airtime > 0.0 or not logs.is_empty() or not shards.is_empty() else 0.0
	shown_alpha = move_toward(shown_alpha, wanted, real_delta * 3.0)
	modulate.a = shown_alpha
	_update_logs(real_delta)

# ---------- Rango y barra

func _layout_rank(rank: int) -> void:
	shown_rank = rank
	var info: Dictionary = Ferocity.rank_info(rank)
	letter.text = info["letter"]
	rest.text = info["rest"]
	letter.size = letter.get_minimum_size()
	rest.size = rest.get_minimum_size()
	rest.position = Vector2(PANEL_WIDTH - rest.size.x, 0)
	letter.position = Vector2(rest.position.x - letter.size.x + 2.0, 12.0)
	# Misma línea base: la parte alta del resto se baja lo que sobresale la letra grande.
	var font: Font = letter.get_theme_font("font")
	rest.position.y = letter.position.y + font.get_ascent(LETTER_SIZE) - font.get_ascent(REST_SIZE)
	letter.pivot_offset = letter.size * 0.5

func _bar_home() -> Vector2:
	return Vector2(PANEL_WIDTH - BAR_WIDTH, 82)

func _update_bar(color: Color, real_delta: float) -> void:
	var fill_width: float = BAR_WIDTH * (Ferocity.special_progress if not Ferocity.special_name.is_empty() else Ferocity.rank_progress())
	bar_fill.size.x = fill_width
	bar_flash = max(bar_flash - real_delta, 0.0)
	if bar_flash > 0.0:
		# Destello rojo al perder estilo, parpadeando hacia blanco al principio.
		var blink: bool = int(bar_flash * 30.0) % 2 == 0 and bar_flash > FLASH_TIME * 0.5
		bar_fill.color = Color(1.0, 0.85, 0.8) if blink else LOSS_COLOR
	else:
		bar_fill.color = color
	cap_flash = max(cap_flash - real_delta, 0.0)
	bar_cap.color = Color(1, 1, 1, cap_flash / 0.4)
	if cap_flash > 0.0 and bar_flash <= 0.0:
		bar_fill.color = bar_fill.color.lerp(Color.WHITE, cap_flash)
	loss_timer = max(loss_timer - real_delta, 0.0)
	var loss_width: float = lerp(fill_width, loss_from, ease(loss_timer / LOSS_TIME, 0.6)) if loss_timer > 0.0 else fill_width
	bar_loss.size.x = max(loss_width, fill_width)
	bar_loss.color = Color(LOSS_COLOR, clamp(loss_timer / LOSS_TIME * 1.5, 0.0, 1.0))

func _update_shake(real_delta: float) -> void:
	shake_timer = max(shake_timer - real_delta, 0.0)
	if shake_timer <= 0.0:
		rank_row.position = Vector2.ZERO
		rank_row.rotation = 0.0
		bar_root.position = _bar_home()
		bar_root.rotation = 0.0
		return
	# Temblor que se apaga, con un leve hundimiento como si se viniera abajo.
	var strength: float = shake_timer / SHAKE_TIME
	var sag: float = sin((1.0 - strength) * PI) * 5.0
	rank_row.position = Vector2(randf_range(-7.0, 7.0), randf_range(-4.0, 4.0) + sag) * Vector2(strength, 1.0)
	rank_row.rotation = randf_range(-0.03, 0.03) * strength
	bar_root.position = _bar_home() + Vector2(randf_range(-6.0, 6.0), randf_range(-3.0, 3.0) + sag * 0.6) * strength
	bar_root.rotation = randf_range(-0.05, 0.05) * strength

func _on_rank_changed(rank: int, previous: int) -> void:
	if rank > previous:
		letter.scale = Vector2.ONE * 1.45
		return
	# Bajada de rango: tiembla y suelta astillas del color del rango perdido.
	shake_timer = SHAKE_TIME
	letter.scale = Vector2(1.15, 0.85)
	var lost_color: Color = Ferocity.rank_info(previous)["color"]
	var letter_rect := Rect2(letter.position, letter.size)
	for index in range(14):
		var from := letter_rect.position + Vector2(randf() * letter_rect.size.x, randf_range(0.25, 0.85) * letter_rect.size.y)
		_spawn_shard(from, lost_color, randf_range(4.0, 9.0))
	for index in range(8):
		var from := _bar_home() + Vector2(randf() * BAR_WIDTH, 3.0)
		_spawn_shard(from, lost_color, randf_range(2.5, 5.0))

func _on_penalized(before: float, after: float) -> void:
	bar_flash = FLASH_TIME
	loss_timer = LOSS_TIME
	# Si el golpe bajó de rango, el tramo rojo parte de la barra llena.
	var same_rank: bool = int(before / Ferocity.RANK_POINTS) == int(after / Ferocity.RANK_POINTS)
	loss_from = BAR_WIDTH * clamp((before - Ferocity.rank * Ferocity.RANK_POINTS) / Ferocity.RANK_POINTS, 0.0, 1.0) if same_rank else BAR_WIDTH

func _spawn_shard(from: Vector2, color: Color, size: float) -> void:
	var shard := Polygon2D.new()
	# Fragmento irregular (triángulo o cuadrilátero torcido).
	var points := PackedVector2Array()
	var corners: int = 3 + randi() % 2
	for index in range(corners):
		var angle: float = TAU * index / corners + randf_range(-0.4, 0.4)
		points.append(Vector2(cos(angle), sin(angle)) * size * randf_range(0.6, 1.0))
	shard.polygon = points
	shard.color = color
	shard.position = from
	shard_layer.add_child(shard)
	shards.append({"node": shard, "velocity": Vector2(randf_range(-90.0, 90.0), randf_range(-120.0, -20.0)), "spin": randf_range(-9.0, 9.0), "age": 0.0})

func _update_shards(real_delta: float) -> void:
	for shard in shards.duplicate():
		shard["age"] += real_delta
		var node: Polygon2D = shard["node"]
		shard["velocity"].y += 520.0 * real_delta
		node.position += shard["velocity"] * real_delta
		node.rotation += shard["spin"] * real_delta
		node.modulate.a = clamp(1.0 - shard["age"] / 0.8, 0.0, 1.0)
		if shard["age"] >= 0.8:
			node.queue_free()
			shards.erase(shard)

# ---------- Registro

func _on_logged(text: String, color: Color, stale: bool, chain: String, count: int) -> void:
	var entry: Dictionary = _find_merge_target(text, chain)
	if not entry.is_empty() and (chain == "" or count > 1):
		# Suma a la cadena: destello dorado y salto.
		entry["count"] = count if chain != "" else entry["count"] + 1
		entry["text"] = text
		entry["color"] = color
		entry["stale"] = stale
		entry["age"] = 0.0
		entry["flash"] = 1.0
		entry["pop"] = 1.0
		_refresh_entry_text(entry)
		if logs[0] != entry:
			logs.erase(entry)
			logs.push_front(entry)
			log_box.move_child(entry["wrapper"], 0)
		return
	var wrapper := Control.new()
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.custom_minimum_size = Vector2(PANEL_WIDTH, 18)
	var label := _label(text, 15, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.size = Vector2(PANEL_WIDTH, 18)
	label.pivot_offset = Vector2(PANEL_WIDTH, 9)
	wrapper.add_child(label)
	log_box.add_child(wrapper)
	log_box.move_child(wrapper, 0)
	var new_entry := {"text": text, "color": color, "stale": stale, "chain": chain, "label": label, "wrapper": wrapper,
		"age": 0.0, "count": max(count, 1), "flash": 0.0, "pop": 0.0}
	_refresh_entry_text(new_entry)
	logs.push_front(new_entry)
	while logs.size() > LOG_MAX:
		var old: Dictionary = logs.pop_back()
		old["wrapper"].queue_free()

func _find_merge_target(text: String, chain: String) -> Dictionary:
	for entry in logs:
		if chain != "":
			if entry["chain"] == chain:
				return entry
		elif entry["chain"] == "" and entry["text"] == text and entry["age"] < MERGE_TIME:
			return entry
	return {}

func _refresh_entry_text(entry: Dictionary) -> void:
	var label: Label = entry["label"]
	label.text = entry["text"] + (" x%d" % entry["count"] if entry["count"] > 1 else "") + (" (repetido)" if entry["stale"] else "")

func _update_logs(real_delta: float) -> void:
	for entry in logs.duplicate():
		entry["age"] += real_delta
		entry["flash"] = max(entry["flash"] - real_delta / FLASH_TIME, 0.0)
		entry["pop"] = max(entry["pop"] - real_delta / POP_TIME, 0.0)
		var label: Label = entry["label"]
		label.add_theme_color_override("font_color", entry["color"].lerp(CHAIN_GOLD, entry["flash"]))
		# Salto: sube y vuelve a su sitio, un poco más grande en el aire.
		var hop: float = sin((1.0 - entry["pop"]) * PI) if entry["pop"] > 0.0 else 0.0
		label.position.y = -hop * 8.0
		label.scale = Vector2.ONE * (1.0 + 0.22 * hop)
		label.modulate.a = clamp((LOG_LIFETIME - entry["age"]) / 0.6, 0.0, 1.0)
		if entry["age"] >= LOG_LIFETIME:
			entry["wrapper"].queue_free()
			logs.erase(entry)

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.02, 0.02))
	label.add_theme_constant_override("outline_size", 6 if font_size < 30 else 10)
	return label
