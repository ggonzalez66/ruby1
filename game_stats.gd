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
# Los umbrales cuentan toda la partida (las cuatro etapas): están pensados para que cueste conseguirlas.
const ACHIEVEMENTS := [
	["parries", 15, "Parrygod de Sekiro", "Parrea 15 ataques"],
	["projectiles_reflected", 25, "Devuelto al remitente", "Devuelve 25 proyectiles"],
	["knife_shines", 10, "Malabarista", "Devuelve 10 veces el fuego jade con el rugido"],
	["knife_throws", 60, "Fuego de retorno", "Lanza el fuego jade 60 veces"],
	["backflips", 40, "Leon Scott Kennedy", "Unnecessary backflips (40)"],
	["frontflips", 50, "Maromas en el aire", "Haz 50 frontflips"],
	["sun_hits_dealt", 25, "Mata-soles (fallido)", "Intenta matar al sol 25 veces: es inmortal"],
	["sun_hits_taken", 8, "Bronceado extremo", "Que el sol te queme 8 veces"],
	["wallride_seconds", 15, "Segundo piso", "15 segundos de wallride"],
	["running_walljumps", 60, "Paredes = escaleras", "60 running walljumps"],
	["mantles", 40, "Buen felino", "Trepa 40 bordes"],
	["bunnyhops", 50, "Counter-Strike", "Encadena 50 bunnyhops"],
	["roars", 120, "Rey León", "Ruge 120 veces"],
	["dummies_killed", 80, "Ni un dummy sano", "Derrota 80 dummies"],
	["idle_seconds", 180, "Contemplando la jungla", "3 minutos quieto"],
	["running_seconds", 240, "Sonic estaría orgulloso", "4 minutos corriendo"],
	["deaths", 15, "Morir es entrenar", "Muere 15 veces"],
	["wall_embeds", 20, "Pared de mantequilla", "Clava el cuchillo en 20 paredes"],
	["ferocity_sss", 1, "Supremacía felina", "Alcanza Ferocity SSS"],
]
# Medallas especiales (ver medals()).
const BOSS_RUSH_SECONDS := 100.0
const SPEEDRUN_SECONDS := 720.0

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
	result.append({"name": "Ni lo vio venir", "description": "Vence a los guardianes en menos de %d s sumando todos los combates" % int(BOSS_RUSH_SECONDS), "earned": boss_fight_time > 0.0 and boss_fight_time < BOSS_RUSH_SECONDS})
	result.append({"name": "Speedrunner", "description": "Termina la demo en menos de %d minutos" % int(SPEEDRUN_SECONDS / 60.0), "earned": total_time < SPEEDRUN_SECONDS})
	return result

func congratulation_message() -> String:
	return "¡GUAU! ¡ERES UN CRACK!"

static func format_time(seconds: float) -> String:
	var millis: int = int(seconds * 1000.0)
	return "%02d:%02d.%03d" % [millis / 60000, (millis / 1000) % 60, millis % 1000]
