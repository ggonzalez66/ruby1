extends Node

# Estadísticas de la partida (autoload "Stats"). Los contadores se suman desde el juego con add();
# los tiempos se miden aquí mirando el estado de Rengar cada frame.

var counters := {}
var total_time := 0.0
var running_time := 0.0
var wallride_time := 0.0
var idle_time := 0.0
var boss_fight_time := 0.0

# Logros: [clave, umbral, texto]. Se desbloquean al llegar al umbral; en la pantalla final
# se muestran los 3 más destacados (valor / umbral más alto).
const ACHIEVEMENTS := [
	["parries", 3, "parece que eres un parrygod de Sekiro"],
	["projectiles_reflected", 5, "devuelves los proyectiles a su remitente"],
	["knife_throws", 12, "lanzas el cuchillo como si fuera un boomerang"],
	["backflips", 10, "hiciste más backflips innecesarios que Leon Scott Kennedy"],
	["frontflips", 10, "eres un maromas en el aire"],
	["sun_hits_dealt", 8, "intentaste matar al sol (spoiler: sigue ahí, inmortal)"],
	["sun_hits_taken", 3, "el sol te ganó más veces que el guardián"],
	["wallride_seconds", 3, "las paredes son tu segundo piso"],
	["running_walljumps", 20, "subes paredes como si fueran escaleras"],
	["mantles", 10, "trepas bordes como buen felino"],
	["bunnyhops", 15, "el bunnyhop de Counter-Strike te queda chico"],
	["roars", 30, "rugiste más que el Rey León"],
	["dummies_killed", 25, "no queda dummy sano en la torre"],
	["idle_seconds", 60, "te tomaste tu tiempo para contemplar la jungla"],
	["running_seconds", 60, "Sonic estaría orgulloso"],
	["deaths", 5, "morir también es parte del entrenamiento"],
	["wall_embeds", 5, "clavas el cuchillo en las paredes como si fueran de mantequilla"],
]

func _ready() -> void:
	reset()

func reset() -> void:
	counters.clear()
	total_time = 0.0
	running_time = 0.0
	wallride_time = 0.0
	idle_time = 0.0
	boss_fight_time = 0.0

func add(key: String, amount: int = 1) -> void:
	counters[key] = get_count(key) + amount

func get_count(key: String) -> int:
	return int(counters.get(key, 0))

func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group(&"player")
	if player == null:
		return
	total_time += delta
	if player.is_on_floor() and player.is_sprinting and abs(player.velocity.x) > 10.0:
		running_time += delta
	if player.wallride_active:
		wallride_time += delta
	if player.is_on_floor() and player.velocity.length() < 5.0 and not player._is_attack_active():
		idle_time += delta
	var boss := get_tree().get_first_node_in_group(&"boss")
	if boss and boss.combat_started and not boss.is_defeated():
		boss_fight_time += delta

func get_value(key: String) -> float:
	match key:
		"wallride_seconds":
			return wallride_time
		"idle_seconds":
			return idle_time
		"running_seconds":
			return running_time
		_:
			return float(get_count(key))

func top_achievements(limit: int = 3) -> Array:
	var unlocked := []
	for achievement in ACHIEVEMENTS:
		var ratio: float = get_value(achievement[0]) / float(achievement[1])
		if ratio >= 1.0:
			unlocked.append([ratio, achievement[2]])
	# Logros que no dependen de contadores.
	if get_count("deaths") == 0:
		unlocked.append([1.5, "llegaste hasta el final sin morir ni una vez"])
	if boss_fight_time > 0.0 and boss_fight_time < 45.0:
		unlocked.append([2.0, "el guardián no supo ni qué lo golpeó"])
	if total_time < 300.0:
		unlocked.append([1.2, "tienes madera de speedrunner"])
	unlocked.sort_custom(func(a, b): return a[0] > b[0])
	var texts := []
	for entry in unlocked.slice(0, limit):
		texts.append(entry[1])
	return texts

func congratulation_message() -> String:
	var texts := top_achievements()
	var message := "¡GUAU! ¡ERES UN CRACK!"
	if texts.is_empty():
		return message
	var joined: String = texts[0]
	if texts.size() == 2:
		joined = "%s y %s" % [texts[0], texts[1]]
	elif texts.size() >= 3:
		joined = "%s, %s y %s" % [texts[0], texts[1], texts[2]]
	return "%s %s." % [message, joined.substr(0, 1).to_upper() + joined.substr(1)]

static func format_time(seconds: float) -> String:
	var millis: int = int(seconds * 1000.0)
	return "%02d:%02d.%03d" % [millis / 60000, (millis / 1000) % 60, millis % 1000]
