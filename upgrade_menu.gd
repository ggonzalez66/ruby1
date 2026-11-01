extends CanvasLayer

# Pantalla de mejoras al superar una ronda del Gauntlet: primero una mejora gratis de tres (con reroll
# pagado en rubíes) y después una tienda para gastar los que queden. Cambiar de arma a distancia pide
# confirmación porque reemplaza la actual. Pausa el juego hasta cerrarse.

signal closed

const CARDS := 3
const BACKGROUND := Color(0.03, 0.05, 0.05, 0.86)
const CARD_COLOR := Color(0.07, 0.1, 0.1, 0.98)
const TITLE_COLOR := Color(1.0, 0.88, 0.55)

enum Stage { FREE, SHOP }

var stage := Stage.FREE
var cards: Array = []
var bought: Array = []
var root_control: Control
var title_label: Label
var rubies_label: Label
var card_row: HBoxContainer
var reroll_button: Button
var continue_button: Button
var main_column: VBoxContainer
var confirm_box: VBoxContainer
var confirm_label: Label
var confirm_accept: Button
var confirm_back: Button
var pending_index := -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	_build()
	root_control.hide()

func is_open() -> bool:
	return root_control.visible

func is_confirming() -> bool:
	return pending_index >= 0

func open() -> void:
	stage = Stage.FREE
	cards = Upgrades.offers(CARDS)
	if cards.is_empty():
		closed.emit()
		return
	bought.clear()
	root_control.show()
	get_tree().paused = true
	_render()

func close() -> void:
	root_control.hide()
	get_tree().paused = false
	closed.emit()

func _input(event: InputEvent) -> void:
	# Aquí no se puede abrir la pausa ni salir sin decidir; cancelar solo vuelve de la confirmación.
	if is_open() and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		if is_confirming() and event.is_action_pressed("ui_cancel"):
			cancel_replace()

func choose(index: int) -> void:
	if Upgrades.replaces_weapon(cards[index]) and _can_choose(index):
		_ask_replace(index)
		return
	_take(index)

func _can_choose(index: int) -> bool:
	var card: Dictionary = cards[index]
	if not Upgrades.can_take(card):
		return false
	return stage == Stage.FREE or (not index in bought and Upgrades.rubies >= int(card["price"]))

func _ask_replace(index: int) -> void:
	pending_index = index
	confirm_label.text = "¿Reemplazar %s por %s?" % [Upgrades.weapon_title(), cards[index]["title"]]
	main_column.hide()
	confirm_box.show()
	confirm_back.grab_focus()

func accept_replace() -> void:
	var index := pending_index
	_hide_confirm()
	_take(index)

func cancel_replace() -> void:
	_hide_confirm()
	_render()

func _hide_confirm() -> void:
	pending_index = -1
	confirm_box.hide()
	main_column.show()

func _take(index: int) -> void:
	if not _can_choose(index):
		return
	var card: Dictionary = cards[index]
	if stage == Stage.FREE:
		Upgrades.grant(card)
		Sfx.play("upgrade_pick")
		_open_shop()
		return
	if not Upgrades.buy(card):
		return
	bought.append(index)
	Sfx.play("upgrade_pick")
	_render()

func reroll() -> void:
	if not Upgrades.spend(Upgrades.REROLL_COST):
		return
	Sfx.play("ui_select")
	bought.clear()
	cards = Upgrades.offers(CARDS)
	_render()

func _open_shop() -> void:
	stage = Stage.SHOP
	bought.clear()
	cards = Upgrades.offers(CARDS)
	if cards.is_empty():
		close()
		return
	_render()

func _render() -> void:
	var free: bool = stage == Stage.FREE
	title_label.text = "ELIGE UNA MEJORA GRATIS" if free else "TIENDA · GASTA TUS RUBÍES"
	rubies_label.text = "RUBÍES: %d" % Upgrades.rubies
	for child in card_row.get_children():
		card_row.remove_child(child)
		child.queue_free()
	var first: Button
	for index in range(cards.size()):
		var button := _make_card(index)
		card_row.add_child(button)
		if first == null and not button.disabled:
			first = button
	reroll_button.text = "Reroll (−%d rubíes)" % Upgrades.REROLL_COST
	reroll_button.disabled = Upgrades.rubies < Upgrades.REROLL_COST
	continue_button.visible = not free
	if first != null:
		first.grab_focus()
	elif not reroll_button.disabled:
		reroll_button.grab_focus()
	elif continue_button.visible:
		continue_button.grab_focus()

func _make_card(index: int) -> Button:
	var card: Dictionary = cards[index]
	var free: bool = stage == Stage.FREE
	var sold: bool = index in bought
	var button := Button.new()
	button.custom_minimum_size = Vector2(290, 250)
	button.disabled = not _can_choose(index)
	button.add_theme_stylebox_override("normal", _card_style(card["color"], 2))
	button.add_theme_stylebox_override("hover", _card_style(card["color"], 3))
	button.add_theme_stylebox_override("pressed", _card_style(card["color"], 3))
	button.add_theme_stylebox_override("disabled", _card_style(Color(0.35, 0.35, 0.35), 2))
	button.add_theme_stylebox_override("focus", _card_style(Color.WHITE, 4))
	button.pressed.connect(choose.bind(index))
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 16
	column.offset_right = -16
	column.offset_top = 14
	column.offset_bottom = -14
	column.add_theme_constant_override("separation", 10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(column)
	column.add_child(_text(card["title"], 22, card["color"]))
	var body := _text(card["text"], 16, Color(0.9, 0.93, 0.9))
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	var footer := "GRATIS" if free else ("COMPRADA" if sold else ("OCUPADO" if not Upgrades.can_take(card) else "%d RUBÍES" % int(card["price"])))
	column.add_child(_text(footer, 18, TITLE_COLOR if not button.disabled else Color(0.6, 0.6, 0.6)))
	return button

func _card_style(color: Color, border: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_COLOR
	style.border_color = color
	style.set_border_width_all(border)
	style.set_corner_radius_all(8)
	return style

func _text(value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.03))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _build() -> void:
	root_control = Control.new()
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root_control)
	var dim := ColorRect.new()
	dim.color = BACKGROUND
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	center.add_child(column)
	main_column = column
	_build_confirm(center)
	title_label = _text("", 36, TITLE_COLOR)
	column.add_child(title_label)
	rubies_label = _text("", 22, Upgrades.RUBY_COLOR.lightened(0.2))
	column.add_child(rubies_label)
	card_row = HBoxContainer.new()
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	card_row.add_theme_constant_override("separation", 16)
	column.add_child(card_row)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	column.add_child(buttons)
	reroll_button = Button.new()
	reroll_button.custom_minimum_size = Vector2(240, 46)
	reroll_button.pressed.connect(reroll)
	buttons.add_child(reroll_button)
	continue_button = Button.new()
	continue_button.text = "Continuar"
	continue_button.custom_minimum_size = Vector2(240, 46)
	continue_button.pressed.connect(close)
	buttons.add_child(continue_button)

func _build_confirm(parent: Control) -> void:
	confirm_box = VBoxContainer.new()
	confirm_box.add_theme_constant_override("separation", 24)
	confirm_box.hide()
	parent.add_child(confirm_box)
	confirm_label = _text("", 30, TITLE_COLOR)
	confirm_box.add_child(confirm_label)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	confirm_box.add_child(buttons)
	confirm_accept = Button.new()
	confirm_accept.text = "Reemplazar"
	confirm_accept.custom_minimum_size = Vector2(240, 46)
	confirm_accept.pressed.connect(accept_replace)
	buttons.add_child(confirm_accept)
	confirm_back = Button.new()
	confirm_back.text = "Volver"
	confirm_back.custom_minimum_size = Vector2(240, 46)
	confirm_back.pressed.connect(cancel_replace)
	buttons.add_child(confirm_back)
