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

# Sprites en pixel art (tools/art/weapon_art.py): mango a la izquierda; GRIP es el punto de agarre.
const GRIP := {&"sword": Vector2(18, 40), &"axe": Vector2(14, 60), &"glaive": Vector2(14, 60), &"hammer": Vector2(14, 60)}

static func texture(id: StringName) -> Texture2D:
	if id == &"unarmed":
		return null
	return load("res://assets/weapons/%s.png" % id)

static func grip(id: StringName) -> Vector2:
	return GRIP.get(id, Vector2(18, 40))

# Timings at 60 Hz: startup / active / recovery. Runtime uses seconds.
static func hit(kind: String, damage: int, frames: Vector3i, reach: float, height: float, stagger := 0.0, push := 180.0, pulses := 1, upward := false) -> Dictionary:
	return {"upward": upward, "kind": kind, "damage": damage, "duration": (frames.x + frames.y + frames.z) / 60.0,
		"startup": frames.x / 60.0, "active_time": frames.y / 60.0, "recovery": frames.z / 60.0, "reach": reach, "height": height,
		"stagger": stagger, "push": push, "pulses": pulses}

static func chain(id: StringName, heavy: bool) -> Array:
	match id:
		&"sword":
			if heavy:
				return [hit("stab", 3, Vector3i(6, 7, 9), 124, 38), hit("flurry", 2, Vector3i(6, 18, 13), 132, 100, 0.35, 280, 3)]
			return [hit("slash", 2, Vector3i(4, 5, 5), 98, 86), hit("slash", 2, Vector3i(4, 5, 5), 98, 86), hit("slash", 2, Vector3i(4, 6, 5), 106, 92), hit("slash", 3, Vector3i(5, 7, 8), 115, 100, 0.35, 340)]
		&"axe":
			if heavy:
				return [hit("chop", 5, Vector3i(9, 6, 20), 145, 155, 0.7, 450)]
			return [hit("slash", 3, Vector3i(6, 4, 11), 128, 120, 0.3, 300), hit("slash", 3, Vector3i(7, 4, 12), 132, 125, 0.35, 330), hit("spin", 3, Vector3i(8, 12, 26), 140, 135, 0.45, 420, 2)]
		&"hammer":
			if heavy:
				return [hit("slam", 7, Vector3i(11, 7, 29), 170, 155, 1.1, 540)]
			return [hit("slash", 5, Vector3i(8, 5, 19), 138, 130, 0.55, 380), hit("slam", 6, Vector3i(9, 6, 24), 150, 145, 0.65, 460, 1, true)]
		&"glaive":
			if heavy:
				return [hit("lunge", 4, Vector3i(7, 8, 13), 180, 45, 0.3, 460), hit("spin", 3, Vector3i(6, 10, 13), 165, 125, 0.4, 360)]
			return [hit("stab", 2, Vector3i(4, 5, 5), 168, 38), hit("slash", 2, Vector3i(4, 6, 5), 145, 98), hit("slash", 2, Vector3i(4, 6, 5), 150, 100), hit("spin", 3, Vector3i(5, 10, 10), 158, 120, 0.4, 360)]
		_:
			if heavy:
				return [hit("kick", 2, Vector3i(4, 5, 6), 105, 62, 0.35, 300), hit("kick", 2, Vector3i(4, 5, 7), 112, 70, 0.4, 360), hit("kick", 3, Vector3i(5, 6, 8), 122, 78, 0.55, 460)]
			return [hit("claw", 1, Vector3i(2, 3, 5), 80, 80), hit("claw", 1, Vector3i(2, 3, 5), 80, 80), hit("claw", 2, Vector3i(3, 4, 6), 105, 100), hit("kick", 2, Vector3i(3, 4, 7), 118, 65, 0.35, 340), hit("kick", 2, Vector3i(4, 5, 8), 132, 75, 0.5, 440)]

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
