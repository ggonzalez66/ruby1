extends Node

# Autoload "Ferocity": medidor de estilo al estilo ULTRAKILL.
# - Se gana estilo corriendo, con trucos de movimiento y con combate; repetir el mismo truco rinde menos.
# - El estilo baja solo (más rápido cuanto más alto) y cae fuerte al recibir golpes.
# - Desde el rango A Rengar es IMPARABLE: los golpes le quitan vida pero no lo frenan, a cambio de
#   bajar dos rangos (en A y S aguanta un golpe; en SS y SSS, dos).
# - Cuanto más estilo, más daño e impacto (hitstop) tienen sus golpes.

signal rank_changed(rank: int, previous: int)
signal logged(text: String, color: Color)
signal unstoppable_changed(active: bool)

const RANK_POINTS := 100.0
const RANKS := [
	{"letter": "D", "name": "DESATADO", "color": Color(0.45, 0.75, 1.0)},
	{"letter": "C", "name": "CRUEL", "color": Color(0.45, 1.0, 0.55)},
	{"letter": "B", "name": "BRUTAL", "color": Color(1.0, 0.9, 0.3)},
	{"letter": "A", "name": "ATROZ", "color": Color(1.0, 0.6, 0.2)},
	{"letter": "S", "name": "SALVAJE", "color": Color(1.0, 0.32, 0.22)},
	{"letter": "SS", "name": "SANGUINARIO", "color": Color(1.0, 0.18, 0.4)},
	{"letter": "SSS", "name": "SUPREMACÍA", "color": Color(1.0, 0.86, 0.4)},
]
const UNSTOPPABLE_RANK := 3
const MAX_POINTS := RANK_POINTS * 7.0 - 0.01
# Puntos al correr a toda velocidad; solo corriendo se llega a B, para más hacen falta trucos.
const RUNNING_GAIN := 15.0
const DRAIN_BASE := 2.0
const DRAIN_PER_POINT := 0.045
const DRAIN_GRACE := 0.8
# Daño y "peso" del golpe (hitstop) por rango.
const DAMAGE_MULTIPLIER := [1.0, 1.0, 1.1, 1.2, 1.35, 1.5, 1.75]
const IMPACT_MULTIPLIER := [1.0, 1.05, 1.15, 1.3, 1.45, 1.6, 1.8]

# Eventos registrados en Stats que dan estilo: [puntos, texto del log ("" = sin log)].
const STAT_EVENTS := {
	"parries": [45.0, "PARRY"],
	"projectiles_reflected": [35.0, "DEVUELTO"],
	"frontflips": [18.0, "FRONTFLIP"],
	"backflips": [20.0, "BACKFLIP"],
	"bunnyhops": [16.0, "BUNNYHOP"],
	"running_walljumps": [18.0, "RUNNING WALLJUMP"],
	"running_bounces": [30.0, "REBOTE EN CARRERA"],
	"wall_embeds": [25.0, "EMPALADO"],
	"mantles": [6.0, ""],
	"dummies_killed": [20.0, "CAZADO"],
}
const GOOD_COLOR := Color(1.0, 0.95, 0.85)
const BONUS_COLOR := Color(1.0, 0.82, 0.35)
const PENALTY_COLOR := Color(1.0, 0.3, 0.25)

var points := 0.0
var rank := 0
var grace := 0.0
var freshness := {}
var unstoppable := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	Stats.counter_added.connect(_on_stat)

func _physics_process(delta: float) -> void:
	for key in freshness.keys():
		freshness[key] = min(freshness[key] + 0.2 * delta, 1.0)
	if grace > 0.0:
		grace -= delta
	elif points > 0.0:
		_set_points(points - (DRAIN_BASE + points * DRAIN_PER_POINT) * delta)

# ---------- Entradas

func add(key: String, amount: float, label: String = "", color: Color = GOOD_COLOR) -> void:
	# Cada repetición del mismo evento rinde un 20 % menos; se recupera con el tiempo.
	var fresh: float = freshness.get(key, 1.0)
	freshness[key] = max(fresh - 0.2, 0.3)
	var gained: float = amount * fresh
	grace = DRAIN_GRACE
	_set_points(points + gained)
	if label != "":
		logged.emit("+" + label + ("" if fresh > 0.55 else " (repetido)"), color if fresh > 0.55 else color.darkened(0.35))

func add_running(delta: float) -> void:
	_set_points(points + RUNNING_GAIN * delta)

func player_hit() -> bool:
	# Golpe recibido. Devuelve true si Rengar lo aguanta sin frenarse (estado imparable).
	if unstoppable:
		logged.emit("-IMPARABLE", PENALTY_COLOR)
		_set_points(_rank_floor(rank - 2) + RANK_POINTS * 0.5)
		grace = 0.0
		return true
	logged.emit("-GOLPEADO", PENALTY_COLOR)
	_set_points(_rank_floor(rank - 1) + RANK_POINTS * 0.3 if rank > 0 else points * 0.3)
	grace = 0.0
	return false

func reset() -> void:
	freshness.clear()
	grace = 0.0
	_set_points(0.0)

# ---------- Consultas

func damage_multiplier() -> float:
	return DAMAGE_MULTIPLIER[rank]

func impact_multiplier() -> float:
	return IMPACT_MULTIPLIER[rank]

func is_unstoppable() -> bool:
	return unstoppable

func rank_info(index: int = -1) -> Dictionary:
	return RANKS[rank if index < 0 else index]

func rank_progress() -> float:
	# Progreso dentro del rango actual (0..1) para la barra del HUD.
	return clamp((points - rank * RANK_POINTS) / RANK_POINTS, 0.0, 1.0)

# ---------- Interno

func _on_stat(key: String, _amount: int) -> void:
	if STAT_EVENTS.has(key):
		var data: Array = STAT_EVENTS[key]
		add(key, data[0], data[1])

func _rank_floor(index: int) -> float:
	return max(index, 0) * RANK_POINTS

func _set_points(value: float) -> void:
	points = clamp(value, 0.0, MAX_POINTS)
	var new_rank: int = clamp(int(points / RANK_POINTS), 0, RANKS.size() - 1)
	if new_rank != rank:
		var previous := rank
		rank = new_rank
		if rank > Stats.get_count("ferocity_peak"):
			Stats.add("ferocity_peak", rank - Stats.get_count("ferocity_peak"))
		if rank == RANKS.size() - 1 and Stats.get_count("ferocity_sss") == 0:
			Stats.add("ferocity_sss")
		rank_changed.emit(rank, previous)
	var now_unstoppable: bool = rank >= UNSTOPPABLE_RANK
	if now_unstoppable != unstoppable:
		unstoppable = now_unstoppable
		unstoppable_changed.emit(unstoppable)
