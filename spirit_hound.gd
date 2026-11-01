extends "res://spirit_ally.gd"

# Sabueso espiritual: corre junto a Viridy, se lanza sobre el enemigo de suelo en alerta más cercano y lo
# deja inmovilizado (aturdido y a su merced). No daña casi nada y al soltarlo recibe un contraataque. Si se
# queda lejos de Viridy reaparece a su lado.

enum Mode { FOLLOW, CHASE, LEAP, PIN }

const FOLLOW_SPEED := 340.0
const CHASE_SPEED := 400.0
const REACH := 460.0
const LEAP_RANGE := 170.0
const LEAP_TIME := 0.34
const LEAP_HEIGHT := 70.0
const PIN_TIME := 3.0
const COOLDOWN := 5.0
const GRAVITY := 1500.0
const WORLD_MASK := 2
const TELEPORT_DISTANCE := 650.0

var mode := Mode.FOLLOW
var fall_speed := 0.0
var leap_elapsed := 0.0
var leap_from := Vector2.ZERO
var pin_left := 0.0

func _ready() -> void:
	max_health = 5
	super._ready()

func _art() -> String:
	return "res://assets/sprites/enemies/hound.png"

func _art_offset() -> Vector2:
	return Vector2(0, -sprite.texture.get_height() * 0.5)

func _act(delta: float) -> void:
	match mode:
		Mode.FOLLOW:
			_ground(delta)
			var goal: float = player.global_position.x - player.facing * 70.0
			_run_to(goal, FOLLOW_SPEED, delta)
			if global_position.distance_to(player.global_position) > TELEPORT_DISTANCE:
				_revive()
			if cooldown <= 0.0:
				target = _nearest_target(REACH, true)
				if target != null:
					mode = Mode.CHASE
		Mode.CHASE:
			if not _valid_target(target):
				_back_to_follow()
				return
			_ground(delta)
			_run_to(target.global_position.x, CHASE_SPEED, delta)
			if global_position.distance_to(target.global_position) <= LEAP_RANGE:
				mode = Mode.LEAP
				leap_elapsed = 0.0
				leap_from = global_position
				Sfx.play("enemy_swing", -3.0, 0.8)
			elif global_position.distance_to(player.global_position) > TELEPORT_DISTANCE:
				_back_to_follow()
		Mode.LEAP:
			if not _valid_target(target):
				_back_to_follow()
				return
			leap_elapsed += delta
			var progress: float = minf(leap_elapsed / LEAP_TIME, 1.0)
			global_position = leap_from.lerp(target.global_position, progress) + Vector2(0, -sin(progress * PI) * LEAP_HEIGHT)
			if progress >= 1.0:
				_pin()
		Mode.PIN:
			pin_left -= delta
			if not _valid_target(target) or pin_left <= 0.0:
				var counter: bool = pin_left <= 0.0
				cooldown = COOLDOWN
				_back_to_follow()
				if counter:
					hurt(1)
				return
			global_position = target.global_position + Vector2(0, -6)
			target.get_node("RubyCore").stagger(minf(pin_left, 0.2))

func _pin() -> void:
	var core: Node = target.get_node("RubyCore")
	core.stagger(PIN_TIME)
	target.take_hit(global_position, 1, 1)
	mode = Mode.PIN
	pin_left = PIN_TIME
	Fx.text(get_parent(), global_position + Vector2(0, -70), "¡INMOVILIZADO!", JADE)
	Sfx.play("enemy_swing", 0.0, 0.6)

func _back_to_follow() -> void:
	mode = Mode.FOLLOW
	target = null
	fall_speed = 0.0

func _run_to(x: float, speed: float, delta: float) -> void:
	if absf(x - global_position.x) < 8.0:
		return
	sprite.flip_h = x < global_position.x
	global_position.x = move_toward(global_position.x, x, speed * delta)

func _ground(delta: float) -> void:
	var space := get_world_2d().direct_space_state
	var reach: float = maxf(fall_speed * delta, 0.0) + 4.0
	var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -8), global_position + Vector2(0, reach), WORLD_MASK))
	if not hit.is_empty():
		global_position.y = hit.position.y
		fall_speed = 0.0
		return
	fall_speed = minf(fall_speed + GRAVITY * delta, 900.0)
	global_position.y += fall_speed * delta

func _on_die() -> void:
	_back_to_follow()
