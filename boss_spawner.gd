extends Node2D

# Elige al azar el guardián final de la torre: pesado, ágil o arquero; a veces salen los tres juntos
# (con menos vida cada uno). Cada reinicio (volver al checkpoint o "Reiniciar todo") cambia a un
# combate distinto del actual. El spawner debe estar en el origen para que las coordenadas del jefe
# sean las globales.

@export var spawn_point := Vector2(6800, 0)
@export var arena_min_x := 5400.0
@export var arena_max_x := 8800.0
# -1 = aleatorio; 0 pesado, 1 ágil, 2 arquero, 3 los tres juntos (para pruebas).
@export var forced_boss := -1
@export var trio_chance := 0.2
# En el trío cada guardián tiene esta fracción de su vida normal.
@export var trio_health_factor := 0.6

const BOSSES := [
	{"script": preload("res://boss_heavy.gd"), "name": "GUARDIÁN PESADO", "subtitle": "El coloso del espadón", "health": 105, "resist": 0.35, "block": 0.2},
	{"script": preload("res://boss_agile.gd"), "name": "GUARDIÁN ÁGIL", "subtitle": "Estoque y daga", "health": 80, "resist": 0.2, "block": 0.35},
	{"script": preload("res://boss_archer.gd"), "name": "GUARDIÁN ARQUERO", "subtitle": "El gigante del arco", "health": 90, "resist": 0.25, "block": 0.0},
]

const TRIO := 3
# Posiciones del trío respecto al punto de aparición: el pesado en el centro, el ágil más cerca de la
# entrada (Rengar llega por la derecha) y el arquero al fondo, a distancia.
const TRIO_OFFSETS := [Vector2(0, 0), Vector2(650, 0), Vector2(-1000, 0)]

var bosses: Array = []
var boss_index := 0

func _ready() -> void:
	_spawn(_pick_next(int(Stats.get_meta(&"last_boss", -1))))
	_connect_player.call_deferred()

func _connect_player() -> void:
	var player := get_tree().get_first_node_in_group(&"player")
	if player:
		player.respawned.connect(_on_player_respawned)

func _on_player_respawned() -> void:
	_spawn(_pick_next(boss_index))

func _pick_next(previous: int) -> int:
	if forced_boss >= 0:
		return forced_boss
	# El trío no se repite dos veces seguidas.
	if previous != TRIO and randf() < trio_chance:
		return TRIO
	if previous < 0 or previous == TRIO:
		return randi() % BOSSES.size()
	# Uno de los otros dos, al azar.
	return (previous + 1 + randi() % (BOSSES.size() - 1)) % BOSSES.size()

func _spawn(index: int) -> void:
	for old in bosses:
		# Fuera de los grupos ya mismo para que el HUD y las estadísticas no lo encuentren este frame.
		old._on_reset()
		old.remove_from_group(&"boss")
		old.remove_from_group(&"training_dummies")
		old.queue_free()
	bosses.clear()
	boss_index = index
	Stats.set_meta(&"last_boss", index)
	if index == TRIO:
		for which in range(BOSSES.size()):
			_add_boss(which, spawn_point + TRIO_OFFSETS[which], trio_health_factor)
	else:
		_add_boss(index, spawn_point, 1.0)

func _add_boss(which: int, at: Vector2, health_factor: float) -> void:
	var data: Dictionary = BOSSES[which]
	var boss := Area2D.new()
	boss.set_script(data["script"])
	boss.boss_name = data["name"]
	boss.boss_subtitle = data["subtitle"]
	boss.max_health = int(round(data["health"] * health_factor))
	boss.resist_chance = data["resist"]
	boss.block_chance = data["block"]
	boss.min_x = arena_min_x
	boss.max_x = arena_max_x
	boss.position = Vector2(clamp(at.x, arena_min_x + 100.0, arena_max_x - 100.0), at.y)
	add_child(boss)
	bosses.append(boss)
