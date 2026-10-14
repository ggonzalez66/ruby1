extends Node2D

# Elige al azar el guardián final de la torre: pesado, ágil o arquero.
# "Reiniciar todo" recarga la escena, así que cada partida puede tocar uno distinto.
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
	boss_index = forced_boss if forced_boss >= 0 else randi() % BOSSES.size()
	var data: Dictionary = BOSSES[boss_index]
	boss = Area2D.new()
	boss.set_script(data["script"])
	boss.name = "TowerGuardian"
	boss.boss_name = data["name"]
	boss.boss_subtitle = data["subtitle"]
	boss.max_health = data["health"]
	boss.resist_chance = data["resist"]
	boss.block_chance = data["block"]
	boss.min_x = arena_min_x
	boss.max_x = arena_max_x
	boss.position = spawn_point
	add_child(boss)
