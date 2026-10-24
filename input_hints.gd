extends Node

# Autoload "InputHints": sabe si el jugador usa teclado/ratón o mando y da el nombre de la
# tecla o botón asignado a cada acción, para mostrarlo en los tutoriales.

signal device_changed

enum Device { KEYBOARD, JOYPAD }

const JOY_BUTTON_NAMES := {
	0: "A", 1: "B", 2: "X", 3: "Y", 4: "Select", 5: "Guide", 6: "Start", 7: "L3", 8: "R3",
	9: "LB", 10: "RB", 11: "D-pad ↑", 12: "D-pad ↓", 13: "D-pad ←", 14: "D-pad →",
}
const JOY_AXIS_NAMES := {0: "Stick izq.", 1: "Stick izq.", 2: "Stick der.", 3: "Stick der.", 4: "LT", 5: "RT"}
const MOUSE_NAMES := {1: "Clic izq.", 2: "Clic der.", 3: "Clic central", 4: "Rueda ↑", 5: "Rueda ↓"}

var device := Device.KEYBOARD

func _input(event: InputEvent) -> void:
	var new_device := device
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and abs(event.axis_value) > 0.4):
		new_device = Device.JOYPAD
	elif event is InputEventKey or event is InputEventMouseButton:
		new_device = Device.KEYBOARD
	if new_device != device:
		device = new_device
		device_changed.emit()

func binding(action: String) -> String:
	var names := []
	for event in InputMap.action_get_events(action):
		var name := _event_name(event)
		if name != "" and not name in names:
			names.append(name)
	return " / ".join(names) if not names.is_empty() else "?"

func movement() -> String:
	if device == Device.JOYPAD:
		return "Stick izq."
	# Parejas izquierda/derecha: "A/D o ←/→".
	var lefts := _names("move_left")
	var rights := _names("move_right")
	var pairs := []
	for index in range(min(lefts.size(), rights.size())):
		pairs.append("%s/%s" % [lefts[index], rights[index]])
	pairs.reverse()
	return " o ".join(pairs)

func _names(action: String) -> Array:
	var names := []
	for event in InputMap.action_get_events(action):
		var name := _event_name(event)
		if name != "":
			names.append(name)
	return names

# Sustituye {acción} por el nombre de su tecla/botón, resaltado para un RichTextLabel.
func format(text: String) -> String:
	var result := text.replace("{move}", _chip(movement()))
	for action in ["jump", "attack", "heavy_attack", "dash", "throw_knife", "roar", "move_up", "move_down", "taunt", "pause"]:
		result = result.replace("{%s}" % action, _chip(binding(action)))
	return result

func _chip(text: String) -> String:
	return "[color=#ffd66b][b]%s[/b][/color]" % text

func _event_name(event: InputEvent) -> String:
	if device == Device.KEYBOARD:
		if event is InputEventKey:
			var key_name := OS.get_keycode_string(event.physical_keycode)
			return {"Left": "←", "Right": "→", "Up": "↑", "Down": "↓", "Space": "Espacio"}.get(key_name, key_name)
		if event is InputEventMouseButton:
			return MOUSE_NAMES.get(event.button_index, "Ratón %d" % event.button_index)
		return ""
	if event is InputEventJoypadButton:
		return JOY_BUTTON_NAMES.get(event.button_index, "Botón %d" % event.button_index)
	if event is InputEventJoypadMotion:
		return JOY_AXIS_NAMES.get(event.axis, "Eje %d" % event.axis)
	return ""
