extends RefCounted

# Datos de balance independientes del controlador y de las poses provisionales.
const IDS := [&"unarmed", &"sword", &"axe", &"hammer", &"glaive"]
const NAMES := {&"unarmed": "Desarmado", &"sword": "Espada", &"axe": "Hacha de guerra", &"hammer": "Martillo", &"glaive": "Lanza / Guja"}
const DESCRIPTIONS := {
	&"unarmed": "Daño − · Velocidad + · Stagger +",
	&"sword": "Daño · Velocidad · Alcance: base",
	&"axe": "Daño + · Stagger + · Alcance + · Velocidad −",
	&"hammer": "Daño ++ · Stagger ++ · Velocidad −− · Superarmadura",
	&"glaive": "Alcance ++ · Control de grupos",
}

static func texture(id: StringName) -> Texture2D:
	if id == &"unarmed":
		return null
	return load("res://assets/weapons/%s.svg" % id)

static func hit(kind: String, damage: int, duration: float, reach: float, height: float, stagger := 0.0, push := 180.0, pulses := 1) -> Dictionary:
	return {"kind": kind, "damage": damage, "duration": duration, "reach": reach, "height": height,
		"stagger": stagger, "push": push, "pulses": pulses}

static func chain(id: StringName, heavy: bool) -> Array:
	match id:
		&"sword":
			if heavy:
				return [hit("stab", 3, 0.36, 124, 38), hit("flurry", 2, 0.62, 132, 100, 0.35, 280, 3)]
			return [hit("slash", 2, 0.22, 98, 86), hit("slash", 2, 0.22, 98, 86), hit("slash", 2, 0.24, 106, 92), hit("slash", 3, 0.32, 115, 100, 0.35, 340)]
		&"axe":
			if heavy:
				return [hit("chop", 5, 0.58, 145, 155, 0.7, 450)]
			return [hit("slash", 3, 0.34, 128, 120, 0.3, 300), hit("slash", 3, 0.36, 132, 125, 0.35, 330), hit("spin", 3, 0.76, 140, 135, 0.45, 420, 2)]
		&"hammer":
			if heavy:
				return [hit("slam", 7, 0.78, 170, 155, 1.1, 540)]
			return [hit("slash", 5, 0.52, 138, 130, 0.55, 380), hit("slam", 6, 0.65, 150, 145, 0.65, 460)]
		&"glaive":
			if heavy:
				return [hit("lunge", 4, 0.46, 180, 45, 0.3, 460), hit("spin", 3, 0.48, 165, 125, 0.4, 360)]
			return [hit("stab", 2, 0.22, 168, 38), hit("slash", 2, 0.25, 145, 98), hit("slash", 2, 0.25, 150, 100), hit("spin", 3, 0.42, 158, 120, 0.4, 360)]
		_:
			if heavy:
				return [hit("kick", 2, 0.25, 105, 62, 0.35, 300), hit("kick", 2, 0.27, 112, 70, 0.4, 360), hit("kick", 3, 0.32, 122, 78, 0.55, 460)]
			return [hit("claw", 1, 0.16, 80, 80), hit("claw", 1, 0.16, 80, 80), hit("claw", 2, 0.22, 105, 100), hit("kick", 2, 0.23, 118, 65, 0.35, 340), hit("kick", 2, 0.28, 132, 75, 0.5, 440)]

static func chargeable(id: StringName, heavy: bool, index: int) -> bool:
	return heavy and index == 0 and id in [&"axe", &"hammer", &"glaive"]

# Common actions: damage bonus per pulse, stagger seconds, and hitbox scale.
# Heavy weapons slow timed actions; cancel rules remain shared.
const COMMON := {
	&"unarmed": {"speed": 1.0, "bonus": 0, "reach": 1.0, "stagger": 0.0, "pulses": 1},
	&"sword": {"speed": 1.0, "bonus": 0, "reach": 1.0, "stagger": 0.1, "pulses": 2},
	&"axe": {"speed": 0.8, "bonus": 2, "reach": 1.25, "stagger": 0.4, "pulses": 1},
	&"hammer": {"speed": 0.65, "bonus": 4, "reach": 1.35, "stagger": 0.7, "pulses": 1},
	&"glaive": {"speed": 1.0, "bonus": 0, "reach": 1.6, "stagger": 0.15, "pulses": 2},
}
