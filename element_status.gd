extends Node2D

# Estados elementales de un enemigo (lo crea Upgrades al primer golpe con elemento):
# - Electricidad: más daño, salta a los cercanos; 3 marcas aturden y el aturdimiento también salta.
# - Fuego: daño en el tiempo (la lanza ardiente usa el mismo); más daño contra bestias.
# - Hielo: ralentiza y acumula; con 3 queda congelado, y un pesado aéreo rompe el hielo y pega mucho.
#   Después queda un tiempo inmune al hielo.

const ELECTRIC_FX := preload("res://electric_fx.gd")
const ELECTRIC := Color(1.0, 0.92, 0.35)
const FIRE := Color(1.0, 0.5, 0.15)
const ICE := Color(0.55, 0.85, 1.0)
const STACKS_TO_PROC := 3

const ELECTRIC_BONUS := 1.25
const MACHINE_BONUS := 1.5
const ARC_RADIUS := 190.0
const ARC_TARGETS := 2
const MARK_TIME := 5.0
const STUN_TIME := 1.0
const MACHINE_STUN_TIME := 1.6

const BURN_TIME := 2.8
const BURN_TICK := 0.7
const BURN_DAMAGE := 1
const BEAST_BONUS := 1.5

const ICE_TIME := 5.0
const SLOW_TIME := 2.5
const FREEZE_TIME := 3.0
const ICE_COOLDOWN := 6.0
const SHATTER_BONUS := 10

var enemy: Node2D
var core: Node
var marks := 0
var marks_left := 0.0
var burn_left := 0.0
var burn_wait := 0.0
var ice_stacks := 0
var ice_left := 0.0
var slow_left := 0.0
var frozen_left := 0.0
var ice_cooldown := 0.0
var flames: CPUParticles2D
# Estados visibles con PixelFX: llamas (quemándose) y bloque de hielo (congelado), en bucle sobre el enemigo.
var burn_fx: AnimatedSprite2D
var ice_fx: AnimatedSprite2D

func _ready() -> void:
	enemy = get_parent()
	core = enemy.get_node_or_null("RubyCore")
	position = enemy.impact_offset
	z_index = 5
	flames = CPUParticles2D.new()
	flames.emitting = false
	flames.amount = 18
	flames.lifetime = 0.45
	flames.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	flames.emission_sphere_radius = 16.0
	flames.direction = Vector2.UP
	flames.spread = 25.0
	flames.gravity = Vector2(0, -60)
	flames.initial_velocity_min = 30.0
	flames.initial_velocity_max = 70.0
	flames.scale_amount_min = 2.0
	flames.scale_amount_max = 5.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.9, 0.4))
	ramp.set_color(1, Color(FIRE.darkened(0.3), 0.0))
	flames.color_ramp = ramp
	# El fuego se ve con la hoja "burning"; las partículas quedan solo como estado (emitting).
	flames.visible = false
	add_child(flames)

# Escala de las hojas de estado según el alto del enemigo (impact_offset ≈ medio cuerpo).
func _body_scale(base: float) -> float:
	var half: float = absf(enemy.impact_offset.y) if enemy.get("impact_offset") != null else 26.0
	return base * clampf(half / 26.0, 0.7, 2.2)

func _drop_burn() -> void:
	if is_instance_valid(burn_fx):
		burn_fx.queue_free()
	burn_fx = null

func _drop_ice() -> void:
	if is_instance_valid(ice_fx):
		ice_fx.queue_free()
	ice_fx = null

func is_frozen() -> bool:
	return frozen_left > 0.0

func apply(element: String, damage: int) -> int:
	# Una variante no sufre su propio elemento.
	if enemy.get_meta(&"element", "") == element:
		return damage
	match element:
		"electric":
			return _electric(damage)
		"fire":
			ignite()
			return ceili(damage * (BEAST_BONUS if Upgrades.kind_of(enemy) == &"beast" else 1.0))
		"ice":
			_chill()
	return damage

# ---------- Electricidad

func _electric(damage: int) -> int:
	var machine: bool = Upgrades.kind_of(enemy) == &"machine"
	var total := ceili(damage * ELECTRIC_BONUS * (MACHINE_BONUS if machine else 1.0))
	var near := _neighbours()
	var center: Vector2 = enemy.global_position + enemy.impact_offset
	for other in near.slice(0, ARC_TARGETS):
		_bolt(center, other.global_position + other.impact_offset)
		other.take_hit(center, 1 if other.global_position.x >= center.x else -1, maxi(1, total / 2))
	marks += 1
	marks_left = MARK_TIME
	if marks >= STACKS_TO_PROC:
		marks = 0
		_stun(enemy, MACHINE_STUN_TIME if machine else STUN_TIME)
		for other in near:
			_bolt(center, other.global_position + other.impact_offset)
			_stun(other, MACHINE_STUN_TIME if Upgrades.kind_of(other) == &"machine" else STUN_TIME)
		Fx.text(enemy.get_parent(), center + Vector2(0, -44), "¡ELECTROCUTADO!", ELECTRIC)
		Sfx.play("zap", 0.0, 0.8)
	else:
		Sfx.play("zap", -6.0, 1.4)
	queue_redraw()
	return total

func _stun(target: Node2D, time: float) -> void:
	var target_core: Node = target.get_node_or_null("RubyCore")
	if target_core == null:
		return
	target_core.stagger(time)
	# Estrellas de aturdido sobre la cabeza mientras dura.
	var stars: AnimatedSprite2D = Fx.status(target, "stunned", target.impact_offset + Vector2(0, -30), 1.0)
	if stars != null:
		stars.create_tween().tween_callback(stars.queue_free).set_delay(time)
	var fx: Node2D = ELECTRIC_FX.new()
	fx.target = target
	fx.center_offset = target.impact_offset
	fx.duration = time
	target.get_parent().add_child(fx)

func _neighbours() -> Array:
	var center := enemy.global_position
	var found: Array = []
	for other in get_tree().get_nodes_in_group(&"ruby_enemies"):
		if other == enemy or not other.visible or other.global_position.distance_to(center) > ARC_RADIUS:
			continue
		var other_core: Node = other.get_node_or_null("RubyCore")
		if other_core != null and other_core.alive() and not other_core.dying and not other_core.locked:
			found.append(other)
	found.sort_custom(func(a, b): return a.global_position.distance_squared_to(center) < b.global_position.distance_squared_to(center))
	return found

func _bolt(from: Vector2, to: Vector2) -> void:
	var line := Line2D.new()
	line.width = 3.0
	line.default_color = ELECTRIC
	line.z_index = 7
	var points := PackedVector2Array([from])
	for index in range(1, 5):
		points.append(from.lerp(to, index / 5.0) + Vector2(randf_range(-12, 12), randf_range(-12, 12)))
	points.append(to)
	line.points = points
	enemy.get_parent().add_child(line)
	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.22)
	tween.tween_callback(line.queue_free)

# ---------- Fuego

func ignite() -> void:
	burn_left = BURN_TIME
	if burn_wait <= 0.0:
		burn_wait = BURN_TICK
	flames.emitting = true
	if not is_instance_valid(burn_fx):
		burn_fx = Fx.status(enemy, "burning", Vector2(0, 2), _body_scale(1.4))

# ---------- Hielo

func _chill() -> void:
	if ice_cooldown > 0.0 or is_frozen():
		return
	ice_stacks += 1
	ice_left = ICE_TIME
	slow_left = SLOW_TIME
	if ice_stacks >= STACKS_TO_PROC:
		_freeze()
	queue_redraw()

func _freeze() -> void:
	ice_stacks = 0
	slow_left = 0.0
	if core == null:
		return
	core.stagger(FREEZE_TIME)
	if core.stagger_left <= 0.0:
		return
	frozen_left = core.stagger_left
	if not is_instance_valid(ice_fx):
		ice_fx = Fx.status(enemy, "ice_block", Vector2(0, 4), _body_scale(1.4), Color(1, 1, 1, 0.62))
	Fx.text(enemy.get_parent(), enemy.global_position + enemy.impact_offset + Vector2(0, -44), "¡CONGELADO!", ICE)
	Sfx.play("guard_break", -3.0, 1.5)

func shatter(damage: int) -> int:
	frozen_left = 0.0
	ice_cooldown = ICE_COOLDOWN
	if core != null:
		core.stagger_left = 0.0
	var center: Vector2 = enemy.global_position + enemy.impact_offset
	_drop_ice()
	Fx.ice_shatter(enemy.get_parent(), enemy.global_position + Vector2(0, 4), _body_scale(1.1))
	Fx.text(enemy.get_parent(), center + Vector2(0, -44), "¡HIELO ROTO!", ICE.lightened(0.3))
	Sfx.play("guard_break", 2.0, 1.3)
	queue_redraw()
	return damage * 2 + SHATTER_BONUS

# ---------- Tiempo

func _physics_process(delta: float) -> void:
	if not enemy.visible or core == null or not core.alive():
		_clear()
		return
	if core.time_stopped:
		return
	if marks_left > 0.0:
		marks_left = maxf(marks_left - delta, 0.0)
		if marks_left == 0.0:
			marks = 0
			queue_redraw()
	if ice_left > 0.0:
		ice_left = maxf(ice_left - delta, 0.0)
		if ice_left == 0.0:
			ice_stacks = 0
			queue_redraw()
	ice_cooldown = maxf(ice_cooldown - delta, 0.0)
	if frozen_left > 0.0:
		frozen_left = maxf(frozen_left - delta, 0.0)
		if frozen_left == 0.0:
			ice_cooldown = ICE_COOLDOWN
			_drop_ice()
	slow_left = maxf(slow_left - delta, 0.0)
	# Ralentizado: el enemigo se salta un tick de cada dos.
	core.slow_skip = slow_left > 0.0 and not core.slow_skip
	_update_burn(delta)
	_update_tint()

func _update_burn(delta: float) -> void:
	if burn_left <= 0.0:
		return
	burn_left = maxf(burn_left - delta, 0.0)
	burn_wait -= delta
	if burn_wait <= 0.0:
		burn_wait = BURN_TICK
		var damage: int = BURN_DAMAGE * (2 if Upgrades.kind_of(enemy) == &"beast" else 1)
		core.apply_element_burn(damage)
	if burn_left == 0.0:
		flames.emitting = false
		_drop_burn()

func _update_tint() -> void:
	var tint: Color = enemy.get_meta(&"tint", Color.WHITE)
	if is_frozen():
		tint = Color(0.6, 0.85, 1.5)
	elif slow_left > 0.0:
		tint = Color(0.75, 0.9, 1.15)
	if enemy.modulate != tint:
		enemy.modulate = tint

func _clear() -> void:
	burn_left = 0.0
	slow_left = 0.0
	frozen_left = 0.0
	marks = 0
	ice_stacks = 0
	flames.emitting = false
	_drop_burn()
	_drop_ice()
	if core != null:
		core.slow_skip = false
	var tint: Color = enemy.get_meta(&"tint", Color.WHITE)
	if enemy.modulate != tint:
		enemy.modulate = tint

func _draw() -> void:
	# Marcas acumuladas sobre la cabeza.
	var pips: Array = [[marks, ELECTRIC], [ice_stacks, ICE]]
	var y := -46.0
	for pip in pips:
		for index in range(int(pip[0])):
			draw_circle(Vector2((index - (pip[0] - 1) * 0.5) * 11.0, y), 4.0, pip[1])
		if pip[0] > 0:
			y -= 11.0
