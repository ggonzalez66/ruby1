extends Node2D

# Elementos que las variantes de enemigos le aplican a Viridy al dañarla (solo en el Gauntlet):
# - Fuego: daño en el tiempo; no puede matarla.
# - Hielo: la ralentiza y acumula; con 3 queda congelada un instante.
# - Electricidad: acumula marcas; con 3 queda electrocutada un instante.
# Temple elemental reduce todos los tiempos a la mitad.

const FIRE := Color(1.0, 0.5, 0.15)
const ICE := Color(0.55, 0.85, 1.0)
const ELECTRIC := Color(1.0, 0.92, 0.35)
const STACKS_TO_PROC := 3
const BURN_TIME := 2.4
const BURN_TICK := 0.6
const BURN_DAMAGE := 2
const SLOW_TIME := 2.5
const SLOW_SCALE := 0.65
const STACK_TIME := 5.0
const STUN_TIME := 0.9
const TEMPER_SCALE := 0.5

var player: CharacterBody2D
var burn_left := 0.0
var burn_wait := 0.0
var slow_left := 0.0
var ice_stacks := 0
var ice_left := 0.0
var marks := 0
var marks_left := 0.0
var sparks: CPUParticles2D

func _ready() -> void:
	player = get_parent()
	position = Vector2(0, -30)
	z_index = 6
	sparks = CPUParticles2D.new()
	sparks.emitting = false
	sparks.amount = 14
	sparks.lifetime = 0.4
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 20.0
	sparks.direction = Vector2.UP
	sparks.gravity = Vector2(0, -60)
	sparks.initial_velocity_min = 20.0
	sparks.initial_velocity_max = 60.0
	sparks.scale_amount_min = 2.0
	sparks.scale_amount_max = 4.0
	add_child(sparks)

func _span(time: float) -> float:
	return time * (TEMPER_SCALE if Upgrades.has("temper") else 1.0)

func movement_scale() -> float:
	return SLOW_SCALE if slow_left > 0.0 else 1.0

func apply(element: String) -> void:
	match element:
		"fire":
			burn_left = _span(BURN_TIME)
			if burn_wait <= 0.0:
				burn_wait = BURN_TICK
			_say("¡QUEMADA!", FIRE)
		"ice":
			slow_left = _span(SLOW_TIME)
			ice_left = _span(STACK_TIME)
			ice_stacks += 1
			if ice_stacks >= STACKS_TO_PROC:
				ice_stacks = 0
				player.apply_element_stun(_span(STUN_TIME))
				_say("¡CONGELADA!", ICE)
		"electric":
			marks_left = _span(STACK_TIME)
			marks += 1
			Sfx.play("zap", -6.0, 1.4)
			if marks >= STACKS_TO_PROC:
				marks = 0
				player.apply_element_stun(_span(STUN_TIME))
				_say("¡ELECTROCUTADA!", ELECTRIC)
				Sfx.play("zap", 0.0, 0.8)
	queue_redraw()

func clear() -> void:
	burn_left = 0.0
	burn_wait = 0.0
	slow_left = 0.0
	ice_stacks = 0
	ice_left = 0.0
	marks = 0
	marks_left = 0.0
	sparks.emitting = false
	queue_redraw()

func _say(text: String, color: Color) -> void:
	Fx.text(player.get_parent(), player.global_position + Vector2(0, -74), text, color)

func _physics_process(delta: float) -> void:
	if player.dead:
		clear()
		return
	slow_left = maxf(slow_left - delta, 0.0)
	if ice_left > 0.0:
		ice_left = maxf(ice_left - delta, 0.0)
		if ice_left == 0.0:
			ice_stacks = 0
			queue_redraw()
	if marks_left > 0.0:
		marks_left = maxf(marks_left - delta, 0.0)
		if marks_left == 0.0:
			marks = 0
			queue_redraw()
	if burn_left > 0.0:
		burn_left = maxf(burn_left - delta, 0.0)
		burn_wait -= delta
		if burn_wait <= 0.0:
			burn_wait = BURN_TICK
			player.take_element_burn(BURN_DAMAGE)
	sparks.emitting = burn_left > 0.0 or slow_left > 0.0
	sparks.color = FIRE if burn_left > 0.0 else ICE

func _draw() -> void:
	# Marcas acumuladas sobre la cabeza.
	var pips: Array = [[marks, ELECTRIC], [ice_stacks, ICE]]
	var y := -62.0
	for pip in pips:
		for index in range(int(pip[0])):
			draw_circle(Vector2((index - (pip[0] - 1) * 0.5) * 11.0, y), 4.0, pip[1])
		if pip[0] > 0:
			y -= 11.0
