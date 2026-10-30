extends Node2D

# Elige el guardián del final de la etapa. En la partida de tres etapas se va venciendo a los tres:
# la torre trae uno al azar (pesado, ágil o arquero), la etapa 2 uno de los que quedan y la etapa 3 el
# último (con una probabilidad de que salgan los tres juntos como gran final). El Gauntlet trae siempre
# el trío. Cada reinicio (volver al checkpoint o "Reiniciar todo") cambia, si se puede, a un combate
# distinto del actual. El spawner debe estar en el origen para que las coordenadas del jefe sean las
# globales.

@export var spawn_point := Vector2(6800, 0)
@export var arena_min_x := 5400.0
@export var arena_max_x := 8800.0
# -1 = aleatorio; 0 pesado, 1 ágil, 2 arquero, 3 mecha, 4 uno de los que aún no se vencieron en esta
# partida, 5 el trío (pesado, ágil y arquero juntos).
@export var forced_boss := -1
@export var trio_chance := 0.2
# En el trío cada guardián tiene esta fracción de su vida normal.
@export var trio_health_factor := 0.6
# Las posiciones del trío piensan en que Rengar entra por la derecha (torre); si entra por la izquierda
# se reflejan: el ágil más cerca de la entrada y el arquero al fondo.
@export var entry_from_left := false
# Gauntlet: no aparece solo; el director de oleadas lo llama con spawn_round() y lo quita con
# clear_bosses().
@export var auto_spawn := true

const BOSSES := [
	{"script": preload("res://boss_heavy.gd"), "name": "GUARDIÁN PESADO", "subtitle": "El coloso del espadón", "health": 105, "block": 0.2},
	{"script": preload("res://boss_agile.gd"), "name": "GUARDIÁN ÁGIL", "subtitle": "Estoque y daga", "health": 80, "block": 0.35},
	{"script": preload("res://boss_archer.gd"), "name": "GUARDIÁN ARQUERO", "subtitle": "El gigante del arco", "health": 90, "block": 0.0},
	{"script": preload("res://boss_mecha.gd"), "name": "GUARDIÁN MECHA", "subtitle": "Puño de hierro y misiles", "health": 120, "block": 0.0},
]

const TRIO := 5
const TRIO_MEMBERS := [0, 1, 2]
const NEXT_UNDEFEATED := 4
# Guardianes vencidos en la partida actual (índices de BOSSES); el menú principal la vacía.
const DEFEATED_META := &"defeated_bosses"
# Posiciones del trío respecto al punto de aparición: el pesado en el centro, el ágil más cerca de la
# entrada (Rengar llega por la derecha) y el arquero al fondo, a distancia.
const TRIO_OFFSETS := [Vector2(0, 0), Vector2(650, 0), Vector2(-1000, 0)]

var bosses: Array = []
var boss_index := 0

func _ready() -> void:
	if auto_spawn:
		_spawn(_pick_next(int(Stats.get_meta(&"last_boss", -1))))
	_connect_player.call_deferred()

func _connect_player() -> void:
	var player := get_tree().get_first_node_in_group(&"player")
	if player:
		player.respawned.connect(_on_player_respawned)

func _on_player_respawned() -> void:
	if auto_spawn:
		_spawn(_pick_next(boss_index))
	else:
		clear_bosses()

func spawn_round() -> void:
	_spawn(_pick_next(boss_index if not bosses.is_empty() else int(Stats.get_meta(&"last_boss", -1))))

func clear_bosses() -> void:
	for old in bosses:
		# Un guardián que otro código ya liberó no se toca.
		if not is_instance_valid(old):
			continue
		old._on_reset()
		old.remove_from_group(&"boss")
		old.remove_from_group(&"training_dummies")
		old.queue_free()
	bosses.clear()

func _pick_next(previous: int) -> int:
	if forced_boss == NEXT_UNDEFEATED:
		return _pick_undefeated(previous)
	if forced_boss >= 0:
		return forced_boss
	# El trío no se repite dos veces seguidas.
	if previous != TRIO and randf() < trio_chance:
		return TRIO
	if previous < 0 or previous >= BOSSES.size():
		return randi() % BOSSES.size()
	# Uno de los otros dos, al azar.
	return (previous + 1 + randi() % (BOSSES.size() - 1)) % BOSSES.size()

func _spawn(index: int) -> void:
	# Los anteriores, fuera de los grupos ya mismo para que el HUD y las estadísticas no los encuentren.
	clear_bosses()
	boss_index = index
	Stats.set_meta(&"last_boss", index)
	if index == TRIO:
		for which in TRIO_MEMBERS:
			_add_boss(which, spawn_point + _entry_offset(TRIO_OFFSETS[which]), trio_health_factor)
	else:
		_add_boss(index, spawn_point, 1.0)

func _entry_offset(offset: Vector2) -> Vector2:
	return Vector2(-offset.x, offset.y) if entry_from_left else offset

func _pick_undefeated(previous: int) -> int:
	# Uno de los guardianes que faltan por vencer (distinto del actual si hay más de uno); cuando ya
	# solo queda uno, a veces salen los tres juntos (trio_chance), sin repetir el trío dos veces seguidas.
	var remaining := []
	for index in range(BOSSES.size()):
		if not index in Stats.get_meta(DEFEATED_META, []):
			remaining.append(index)
	if remaining.is_empty():
		remaining = range(BOSSES.size())
	if remaining.size() == 1 and previous != TRIO and randf() < trio_chance:
		return TRIO
	if remaining.size() > 1:
		remaining.erase(previous)
	return remaining[randi() % remaining.size()]

func _on_boss_defeated() -> void:
	# Se apunta quién cayó: las etapas siguientes traen a los que faltan.
	for boss in bosses:
		if not boss.is_defeated():
			return
	var defeated: Array = Stats.get_meta(DEFEATED_META, []).duplicate()
	for index in (TRIO_MEMBERS if boss_index == TRIO else [boss_index]):
		if not index in defeated:
			defeated.append(index)
	Stats.set_meta(DEFEATED_META, defeated)

func _add_boss(which: int, at: Vector2, health_factor: float) -> void:
	var data: Dictionary = BOSSES[which]
	var boss := Area2D.new()
	boss.set_script(data["script"])
	boss.boss_name = data["name"]
	boss.boss_subtitle = data["subtitle"]
	boss.max_health = int(round(data["health"] * health_factor))
	boss.block_chance = data["block"]
	boss.min_x = arena_min_x
	boss.max_x = arena_max_x
	boss.position = Vector2(clamp(at.x, arena_min_x + 100.0, arena_max_x - 100.0), at.y)
	if not auto_spawn:
		var director := get_tree().get_first_node_in_group(&"gauntlet_director")
		if director:
			boss.set_meta(&"spawn_grace", director.spawn_grace_time)
	add_child(boss)
	bosses.append(boss)
	boss.boss_defeated.connect(_on_boss_defeated)
