extends "res://spirit_ally.gd"

# Halcón espiritual: vuela sobre Viridy y se lanza en picado contra el enemigo en alerta más cercano que
# tenga a la vista (sin paredes ni plataformas en medio); si algo se interpone durante el picado, lo deja.
# Cada ataque a un enemigo que no esté aturdido le cuesta un contraataque.

const HOVER := Vector2(-60, -110)
const FOLLOW_SPEED := 8.0
const DIVE_SPEED := 900.0
const REACH := 480.0
const DAMAGE := 3
const COOLDOWN := 1.6
const CONTACT := 30.0
const MAX_DIVE_TIME := 1.2
const BLOCKED_COOLDOWN := 0.3

var dive_left := 0.0

func _ready() -> void:
	max_health = 4
	super._ready()

func _art() -> String:
	return "res://assets/sprites/enemies/hawk.png"

func _act(delta: float) -> void:
	if dive_left > 0.0 and _valid_target(target):
		dive_left -= delta
		var goal := _center(target)
		if not in_sight(goal):
			# Una pared o plataforma se interpuso: no la atraviesa.
			dive_left = 0.0
			target = null
			cooldown = BLOCKED_COOLDOWN
			return
		_look_at_x(goal.x)
		global_position = global_position.move_toward(goal, DIVE_SPEED * delta)
		if global_position.distance_to(goal) <= CONTACT:
			_strike()
		return
	dive_left = 0.0
	target = null
	var home: Vector2 = player.global_position + Vector2(HOVER.x * player.facing, HOVER.y)
	global_position = global_position.lerp(home, minf(FOLLOW_SPEED * delta, 1.0))
	_look_at_x(player.global_position.x + player.facing * 100.0)
	if cooldown <= 0.0:
		target = _nearest_target(REACH, false, true)
		if target != null:
			dive_left = MAX_DIVE_TIME
			Sfx.play("hawk_dive", -4.0, 1.3)

func _strike() -> void:
	var direction := 1 if target.global_position.x >= global_position.x else -1
	var core: Node = target.get_node("RubyCore")
	var counter: bool = not core.holds_actor()
	target.take_hit(global_position, direction, DAMAGE)
	Fx.impact(get_parent(), global_position, Fx.GOLD, 0.8)
	dive_left = 0.0
	target = null
	cooldown = COOLDOWN
	if counter:
		hurt(1)

func _look_at_x(x: float) -> void:
	sprite.flip_h = x < global_position.x

func _on_die() -> void:
	dive_left = 0.0
