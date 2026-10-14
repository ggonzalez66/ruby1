extends Node

# Estadísticas de la partida (autoload "Stats"). Los contadores se suman desde el juego con add();
# los tiempos se miden aquí mirando el estado de Rengar cada frame.

signal counter_added(key: String, amount: int)

var counters := {}
var total_time := 0.0
var running_time := 0.0
var wallride_time := 0.0
var idle_time := 0.0
var boss_fight_time := 0.0

# Medallas: [clave, umbral, nombre, descripción]. Se consiguen al llegar al umbral de la estadística.
const ACHIEVEMENTS := [
	["parries", 3, "Parrygod de Sekiro", "Parrea 3 ataques"],
	["projectiles_reflected", 5, "Devuelto al remitente", "Devuelve 5 proyectiles"],
	["knife_throws", 12, "Cuchillo boomerang", "Lanza el cuchillo 12 veces"],
	["backflips", 10, "Leon Scott Kennedy", "Más backflips innecesarios que Leon (10)"],
	["frontflips", 10, "Maromas en el aire", "Haz 10 frontflips"],
	["sun_hits_dealt", 8, "Mata-soles (fallido)", "Intenta matar al sol 8 veces: es inmortal"],
	["sun_hits_taken", 3, "Bronceado extremo", "Que el sol te queme 3 veces"],
	["wallride_seconds", 3, "Segundo piso", "3 segundos de wallride"],
	["running_walljumps", 20, "Paredes = escaleras", "20 running walljumps"],
	["mantles", 10, "Buen felino", "Trepa 10 bordes"],
	["bunnyhops", 15, "Counter-Strike", "Encadena 15 bunnyhops"],
	["roars", 30, "Rey León", "Ruge 30 veces"],
	["dummies_killed", 25, "Ni un dummy sano", "Derrota 25 dummies"],
	["idle_seconds", 60, "Contemplando la jungla", "1 minuto quieto"],
	["running_seconds", 60, "Sonic estaría orgulloso", "1 minuto corriendo"],
	["deaths", 5, "Morir es entrenar", "Muere 5 veces"],
	["wall_embeds", 5, "Pared de mantequilla", "Clava el cuchillo en 5 paredes"],
	["ferocity_sss", 1, "Supremacía felina", "Alcanza Ferocity SSS"],
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
	counter_added.emit(key, amount)

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
	# Con varios guardianes (trío), el combate dura mientras quede alguno en pie y alguno haya empezado.
	var started := false
	var standing := false
	for boss in get_tree().get_nodes_in_group(&"boss"):
		started = started or boss.combat_started
		standing = standing or not boss.is_defeated()
	if started and standing:
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

func medals() -> Array:
	# Lista de medallas con su estado: {"name", "description", "earned"}.
	var result := []
	for achievement in ACHIEVEMENTS:
		result.append({"name": achievement[2], "description": achievement[3], "earned": get_value(achievement[0]) >= float(achievement[1])})
	result.append({"name": "Intocable", "description": "Termina la demo sin morir", "earned": get_count("deaths") == 0})
	result.append({"name": "Ni lo vio venir", "description": "Derrota al guardián en menos de 45 s", "earned": boss_fight_time > 0.0 and boss_fight_time < 45.0})
	result.append({"name": "Speedrunner", "description": "Termina la demo en menos de 5 minutos", "earned": total_time < 300.0})
	return result

func congratulation_message() -> String:
	return "¡GUAU! ¡ERES UN CRACK!"

static func format_time(seconds: float) -> String:
	var millis: int = int(seconds * 1000.0)
	return "%02d:%02d.%03d" % [millis / 60000, (millis / 1000) % 60, millis % 1000]
