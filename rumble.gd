extends Node

# Autoload "Rumble": vibración del mando. Va de la mano de los efectos de sonido (Sfx avisa de cada
# sonido y aquí se decide si ese momento vibra y cuánto). Solo vibra si se está jugando con mando y la
# vibración está activada en Opciones.

# Sonido -> [motor suave (0-1), motor fuerte (0-1), duración (s)].
const PATTERNS := {
	"hit_light": [0.35, 0.0, 0.07],
	"hit_heavy": [0.55, 0.65, 0.16],
	"heavy_land": [0.4, 0.9, 0.22],
	"bounce": [0.3, 0.35, 0.1],
	"shine": [0.25, 0.0, 0.06],
	"parry": [0.7, 0.5, 0.2],
	"block": [0.35, 0.55, 0.12],
	"shine_break": [0.9, 1.0, 0.4],
	"hurt": [0.5, 0.85, 0.25],
	"death": [1.0, 1.0, 0.55],
	"land": [0.15, 0.25, 0.06],
	"enemy_die": [0.3, 0.45, 0.14],
	"zap": [0.4, 0.0, 0.1],
	"knife_hit": [0.25, 0.0, 0.05],
}

var enabled := true
# Para las pruebas: la última vibración pedida (aunque no haya mando conectado).
var last_pattern := ""

func on_sound(sound: String, strength: float = 1.0) -> void:
	if not PATTERNS.has(sound):
		return
	var pattern: Array = PATTERNS[sound]
	pulse(pattern[0] * strength, pattern[1] * strength, pattern[2], sound)

func pulse(weak: float, strong: float, duration: float, label: String = "") -> void:
	if not enabled or InputHints.device != InputHints.Device.JOYPAD:
		return
	last_pattern = label
	for device in Input.get_connected_joypads():
		Input.start_joy_vibration(device, clamp(weak, 0.0, 1.0), clamp(strong, 0.0, 1.0), duration)

func stop_all() -> void:
	for device in Input.get_connected_joypads():
		Input.stop_joy_vibration(device)
