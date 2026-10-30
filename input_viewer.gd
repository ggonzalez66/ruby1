extends CanvasLayer

# Autoload "InputViewer": visor de inputs (se activa en Opciones). Abajo a la derecha dibuja lo que se
# está pulsando según el dispositivo en uso (InputHints): un mando de Xbox (gatillos, bumpers, sticks,
# cruceta y A/B/X/Y con sus colores) o el teclado y el ratón (las teclas asignadas a cada acción, con las
# de movimiento en T, y un ratón si alguna acción va en sus botones).

const MARGIN := 14.0
const PAD_SIZE := Vector2(236, 124)
const KEYS_SIZE := Vector2(312, 112)
const BG := Color(0.03, 0.05, 0.04, 0.72)
const BORDER := Color(0.55, 0.85, 0.5, 0.55)
const KEY_IDLE := Color(0.16, 0.2, 0.18, 0.95)
const KEY_ON := Color(0.98, 0.84, 0.36)
const TEXT := Color(0.88, 0.95, 0.86)
const TEXT_ON := Color(0.08, 0.06, 0.02)
const FACE := {"A": Color(0.36, 0.8, 0.28), "B": Color(0.9, 0.26, 0.24), "X": Color(0.25, 0.5, 0.95), "Y": Color(0.98, 0.78, 0.18)}
# Acciones del teclado que se muestran (además del movimiento) y su rótulo.
const ACTIONS := [["jump", "Salto"], ["attack", "Ataque"], ["heavy_attack", "Pesado"], ["dash", "Dash"], ["throw_knife", "Aim / lanza"], ["roar", "Parry"]]

var enabled := false
var panel: Control
var font: Font

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = ThemeDB.fallback_font
	panel = Control.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.draw.connect(_draw_panel)
	add_child(panel)
	InputHints.device_changed.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	set_enabled(enabled)

func set_enabled(on: bool) -> void:
	enabled = on
	visible = on
	_layout()

func _process(_delta: float) -> void:
	if visible:
		panel.queue_redraw()

func _layout() -> void:
	if panel == null:
		return
	var size: Vector2 = PAD_SIZE if _joypad() else KEYS_SIZE
	var screen: Vector2 = get_viewport().get_visible_rect().size
	panel.size = size
	panel.position = Vector2(screen.x - size.x - MARGIN, screen.y - size.y - MARGIN)

func _joypad() -> bool:
	return InputHints.device == InputHints.Device.JOYPAD

func _draw_panel() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = BG
	box.border_color = BORDER
	box.set_border_width_all(2)
	box.set_corner_radius_all(10)
	panel.draw_style_box(box, Rect2(Vector2.ZERO, panel.size))
	if _joypad():
		_draw_pad()
	else:
		_draw_keyboard()

# ---------- Mando

func _draw_pad() -> void:
	var device: int = Input.get_connected_joypads()[0] if not Input.get_connected_joypads().is_empty() else 0
	var lt: float = Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT)
	var rt: float = Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT)
	_trigger(Rect2(14, 8, 42, 14), "LT", lt)
	_bumper(Rect2(60, 8, 42, 14), "LB", Input.is_joy_button_pressed(device, JOY_BUTTON_LEFT_SHOULDER))
	_bumper(Rect2(134, 8, 42, 14), "RB", Input.is_joy_button_pressed(device, JOY_BUTTON_RIGHT_SHOULDER))
	_trigger(Rect2(180, 8, 42, 14), "RT", rt)
	var left := Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y))
	var right := Vector2(Input.get_joy_axis(device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y))
	_stick(Vector2(40, 60), left, Input.is_joy_button_pressed(device, JOY_BUTTON_LEFT_STICK))
	_stick(Vector2(146, 96), right, Input.is_joy_button_pressed(device, JOY_BUTTON_RIGHT_STICK), 13.0)
	# Cruceta.
	var dpad := Vector2(86, 96)
	for entry in [[Vector2(0, -1), JOY_BUTTON_DPAD_UP], [Vector2(0, 1), JOY_BUTTON_DPAD_DOWN], [Vector2(-1, 0), JOY_BUTTON_DPAD_LEFT], [Vector2(1, 0), JOY_BUTTON_DPAD_RIGHT]]:
		var center: Vector2 = dpad + entry[0] * 11.0
		panel.draw_rect(Rect2(center - Vector2(5.5, 5.5), Vector2(11, 11)), KEY_ON if Input.is_joy_button_pressed(device, entry[1]) else KEY_IDLE)
	panel.draw_rect(Rect2(dpad - Vector2(5.5, 5.5), Vector2(11, 11)), KEY_IDLE)
	# Back y Start.
	_small_button(Vector2(104, 52), Input.is_joy_button_pressed(device, JOY_BUTTON_BACK))
	_small_button(Vector2(128, 52), Input.is_joy_button_pressed(device, JOY_BUTTON_START))
	# A, B, X, Y.
	var face := Vector2(192, 62)
	_face(face + Vector2(0, 16), "A", Input.is_joy_button_pressed(device, JOY_BUTTON_A))
	_face(face + Vector2(16, 0), "B", Input.is_joy_button_pressed(device, JOY_BUTTON_B))
	_face(face + Vector2(-16, 0), "X", Input.is_joy_button_pressed(device, JOY_BUTTON_X))
	_face(face + Vector2(0, -16), "Y", Input.is_joy_button_pressed(device, JOY_BUTTON_Y))

func _trigger(rect: Rect2, label: String, value: float) -> void:
	panel.draw_rect(rect, KEY_IDLE)
	var amount: float = clamp(value, 0.0, 1.0)
	if amount > 0.02:
		panel.draw_rect(Rect2(rect.position, Vector2(rect.size.x * amount, rect.size.y)), KEY_ON)
	_text(rect.get_center(), label, 10, TEXT_ON if amount > 0.5 else TEXT)

func _bumper(rect: Rect2, label: String, pressed: bool) -> void:
	panel.draw_rect(rect, KEY_ON if pressed else KEY_IDLE)
	_text(rect.get_center(), label, 10, TEXT_ON if pressed else TEXT)

func _stick(center: Vector2, axis: Vector2, clicked: bool, radius: float = 17.0) -> void:
	panel.draw_circle(center, radius, KEY_IDLE)
	panel.draw_arc(center, radius, 0.0, TAU, 24, BORDER, 1.5)
	var knob: Vector2 = center + axis.limit_length(1.0) * radius * 0.6
	panel.draw_circle(knob, radius * 0.45, KEY_ON if clicked or axis.length() > 0.25 else TEXT.darkened(0.35))

func _small_button(center: Vector2, pressed: bool) -> void:
	panel.draw_circle(center, 5.0, KEY_ON if pressed else KEY_IDLE)

func _face(center: Vector2, label: String, pressed: bool) -> void:
	var color: Color = FACE[label]
	panel.draw_circle(center, 8.5, color if pressed else color.darkened(0.62))
	if pressed:
		panel.draw_arc(center, 8.5, 0.0, TAU, 20, Color.WHITE, 1.5)
	_text(center, label, 10, Color.WHITE if pressed else color.lightened(0.2))

# ---------- Teclado y ratón

func _draw_keyboard() -> void:
	# Movimiento en T invertida.
	var cell := Vector2(28, 24)
	var origin := Vector2(14, 30)
	_key(Rect2(origin + Vector2(cell.x + 2, 0), cell), "move_up")
	_key(Rect2(origin + Vector2(0, cell.y + 3), cell), "move_left")
	_key(Rect2(origin + Vector2(cell.x + 2, cell.y + 3), cell), "move_down")
	_key(Rect2(origin + Vector2((cell.x + 2) * 2, cell.y + 3), cell), "move_right")
	# Acciones en dos filas de tres.
	for index in range(ACTIONS.size()):
		var column: int = index % 3
		var row: int = index / 3
		var rect := Rect2(Vector2(112 + column * 66, 10 + row * 50), Vector2(58, 26))
		_key(rect, ACTIONS[index][0])
		_text(rect.get_center() + Vector2(0, 21), ACTIONS[index][1], 9, TEXT.darkened(0.15))

func _key(rect: Rect2, action: String) -> void:
	# Muestra la tecla con letra asignada a la acción (WASD antes que las flechas), o el botón del ratón; se
	# ilumina con cualquiera de sus teclas o botones.
	var event: InputEvent = null
	for candidate in InputMap.action_get_events(action):
		if candidate is InputEventMouseButton and event == null:
			event = candidate
		elif candidate is InputEventKey:
			var is_letter: bool = OS.get_keycode_string(candidate.physical_keycode).length() == 1
			if event == null or event is InputEventMouseButton or (is_letter and not OS.get_keycode_string(event.physical_keycode).length() == 1):
				event = candidate
	var pressed: bool = Input.is_action_pressed(action)
	if event is InputEventMouseButton:
		_mouse(rect, event.button_index, pressed)
		return
	var box := StyleBoxFlat.new()
	box.bg_color = KEY_ON if pressed else KEY_IDLE
	box.set_corner_radius_all(4)
	box.border_color = BORDER
	box.set_border_width_all(1)
	panel.draw_style_box(box, rect)
	var label := "?"
	if event is InputEventKey:
		label = OS.get_keycode_string(event.physical_keycode)
		label = {"Left": "←", "Right": "→", "Up": "↑", "Down": "↓", "Space": "Espacio", "Shift": "Shift", "Escape": "Esc"}.get(label, label)
	_text(rect.get_center(), label, 10 if label.length() <= 3 else 9, TEXT_ON if pressed else TEXT)

func _mouse(rect: Rect2, button: int, pressed: bool) -> void:
	# Ratón: cuerpo redondeado con sus dos botones; se ilumina el que tiene la acción si se pulsa.
	var body := Rect2(rect.get_center() - Vector2(9, 13), Vector2(18, 26))
	var box := StyleBoxFlat.new()
	box.bg_color = KEY_IDLE
	box.set_corner_radius_all(8)
	box.border_color = BORDER
	box.set_border_width_all(1)
	panel.draw_style_box(box, body)
	var half := Rect2(body.position + Vector2(1, 1), Vector2(8, 10))
	if button == MOUSE_BUTTON_RIGHT:
		half.position.x += 8
	panel.draw_rect(half, KEY_ON if pressed else BORDER.darkened(0.3))
	panel.draw_line(body.position + Vector2(9, 1), body.position + Vector2(9, 11), BG, 1.0)

func _text(center: Vector2, text: String, size: int, color: Color) -> void:
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	panel.draw_string(font, center + Vector2(-width * 0.5, size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
