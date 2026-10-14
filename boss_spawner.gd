extends Node2D

# Elige al azar el guardián final de la torre: pesado, ágil o arquero.
# Cada reinicio (volver al checkpoint o "Reiniciar todo") cambia a uno distinto del actual.
# El spawner debe estar en el origen para que las coordenadas del jefe sean las globales.

@export var spawn_point := Vector2(6800, 0)
@export var arena_min_x := 5400.0
@export var arena_max_x := 8800.0
# -1 = aleatorio; 0 pesado, 1 ágil, 2 arquero (para pruebas).
@export var forced_boss := -1

const BOSSES := [
	{"script": preload("res://boss_heavy.gd"), "name": "GUARDIÁN PESADO", "subtitle": "El coloso del espadón", "health": 105, "resist": 0.35, "block": 0.2},
	{"script": preload("res://boss_agile.gd"), "name": "GUARDIÁN ÁGIL", "subtitle": "Estoque y daga", "health": 80, "resist": 0.2, "block": 0.35},
	{"script": preload("res://boss_archer.gd"), "name": "GUARDIÁN ARQUERO", "subtitle": "El gigante del arco", "health": 90, "resist": 0.25, "block": 0.0},
]

var boss: Area2D
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
	if previous < 0:
		return randi() % BOSSES.size()
	# Uno de los otros dos, al azar.
	return (previous + 1 + randi() % (BOSSES.size() - 1)) % BOSSES.size()

func _spawn(index: int) -> void:
	if boss:
		# Fuera de los grupos ya mismo para que el HUD y las estadísticas no lo encuentren este frame.
		boss._on_reset()
		boss.remove_from_group(&"boss")
		boss.remove_from_group(&"training_dummies")
		boss.queue_free()
	boss_index = index
	Stats.set_meta(&"last_boss", index)
	var data: Dictionary = BOSSES[boss_index]
	boss = Area2D.new()
	boss.set_script(data["script"])
	boss.boss_name = data["name"]
	boss.boss_subtitle = data["subtitle"]
	boss.max_health = data["health"]
	boss.resist_chance = data["resist"]
	boss.block_chance = data["block"]
	boss.min_x = arena_min_x
	boss.max_x = arena_max_x
	boss.position = spawn_point
	add_child(boss)
