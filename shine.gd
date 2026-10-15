class_name Shine
extends RefCounted

# Regla general de lo que se devuelve con un shine (proyectiles, flechas, el cuchillo de Rengar y
# la daga del guardián ágil): cada vez que alguien lo shinea sube su nivel, pega un poco más y se ve
# más grande y más caliente. El nivel 1 es el primer shine (daño base).
# Los enemigos que pueden shinear implementan try_shine(cosa) -> bool.

const DAMAGE_STEP := 0.35
const MAX_VISUAL_LEVEL := 6
# Del dorado del rugido al blanco incandescente.
const PLAYER_COLORS: Array[Color] = [Color(1.0, 0.8, 0.28), Color(1.0, 0.62, 0.18), Color(1.0, 0.42, 0.12), Color(1.0, 0.92, 0.85)]
# Del magenta enemigo al rojo sangre.
const ENEMY_COLORS: Array[Color] = [Color(0.85, 0.25, 0.55), Color(1.0, 0.2, 0.4), Color(1.0, 0.1, 0.18), Color(1.0, 0.75, 0.8)]

static func enemy_feedback(tree: SceneTree, point: Vector2) -> void:
	# Un enemigo shineó algo: Rengar lo siente (hitstop y cámara).
	var player := tree.get_first_node_in_group(&"player")
	if player and player.has_method("on_enemy_shine"):
		player.on_enemy_shine(point)

static func multiplier(level: int) -> float:
	return 1.0 + DAMAGE_STEP * max(level - 1, 0)

static func damage(base: int, level: int) -> int:
	return max(int(round(base * multiplier(level))), base)

static func visual_scale(level: int) -> float:
	return 1.0 + 0.16 * clamp(level - 1, 0, MAX_VISUAL_LEVEL)

static func color(level: int, player_side: bool) -> Color:
	var palette: Array[Color] = PLAYER_COLORS if player_side else ENEMY_COLORS
	return palette[clamp(level - 1, 0, palette.size() - 1)]
