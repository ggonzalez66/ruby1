extends "res://boss_base.gd"

# La Araña Colosal: el último guardián de la Torre (llega tras vencer al trío). Un robot araña enorme sobre
# cuatro patas articuladas (IK de dos segmentos, pisadas plantadas en el suelo).
# - Un ruby en cada pata (spider_leg.gd): golpéalo hasta exponerlo y ejecútalo con un pesado.
# - El ruby central del abdomen está protegido mientras le quede alguna pata. Al perder las cuatro se
#   desploma, llama una vez a unos esbirros pequeños y el núcleo queda expuesto: muere solo cuando se
#   rompe el ruby central (vida a cero → remate con un pesado, como cualquier guardián).
# - Lenta y muy resistente. No se aturde: el parry anula el golpe pero no la interrumpe ni le baja postura.
# Ataques:
# - Estocada: levanta una pata delantera (brilla la punta) y la clava donde estaba Viridy.
# - Arremetida: se agazapa cargando energía y embiste hacia delante a toda velocidad.
# - Railgun: la torreta del lomo apunta con un láser y, tras fijar, dispara tres veces.
# - Desplomada solo le quedan la railgun y un golpe de abdomen contra el suelo de corto alcance.

@export var leg_health := 36
@export var walk_speed := 45.0
@export var stab_windup := 0.95
@export var stab_damage := 22
@export var charge_windup := 1.15
@export var charge_speed := 820.0
@export var charge_distance := 950.0
@export var charge_damage := 30
@export var rail_aim_time := 1.5
@export var rail_lock_time := 0.32
@export var rail_retrack_time := 0.55
@export var rail_damage := 18
@export var rail_cooldown_time := 7.0
@export var slam_windup := 0.9
@export var slam_damage := 16
@export var slam_radius := 210.0
@export var minion_count := 4

const SPIDER_CORE := preload("res://spider_core.gd")
const LEG_SCRIPT := preload("res://spider_leg.gd")
const CHASER_SCRIPT := preload("res://chaser_dummy.gd")
const STINGER_SCRIPT := preload("res://stinger.gd")
const WORLD_MASK := 2

const ARMOR := Color(0.27, 0.28, 0.31)
const ARMOR_DARK := Color(0.15, 0.16, 0.18)
const ARMOR_LIGHT := Color(0.48, 0.5, 0.54)
const FAR_TINT := Color(0.62, 0.62, 0.66)
const GLOW := Color(1.0, 0.22, 0.16)
const SHIELD := Color(1.0, 0.55, 0.35)
const RAIL_COLOR := Color(1.0, 0.25, 0.2)

const THIGH := 270.0
const SHIN := 345.0
const BODY_HEIGHT := 290.0
const COLLAPSED_HEIGHT := 92.0
const STRIDE := 120.0
# Patas: 0 delantera cercana, 1 trasera cercana, 2 delantera lejana, 3 trasera lejana.
const LEG_FRONT := [true, false, true, false]
const LEG_NEAR := [true, true, false, false]
const LEG_REST := [300.0, 300.0, 190.0, 190.0]
const LEG_GROUP := [0, 1, 1, 0]
const ABDOMEN := Vector2(-125, -8)
const HEAD := Vector2(118, 8)
const TURRET := Vector2(20, -58)
const BARREL := 112.0

enum State { IDLE, WALK, STAB_WINDUP, STAB, CHARGE_WINDUP, CHARGE, RAIL_AIM, RAIL_LOCK, RAIL_RETRACK, RECOVER, COLLAPSE, SLAM_WINDUP }

var state := State.IDLE
var state_timer := 1.0
var decision_timer := 0.0
var rail_cooldown := 3.0
var charge_cooldown := 2.0
var shots_left := 0
var hit_done := false
var charge_left := 0.0
var stab_leg := -1
var stab_target := Vector2.ZERO
var stab_from := Vector2.ZERO
var body_height := BODY_HEIGHT
var body_shift := Vector2.ZERO
var face_x := -1.0
var aim_angle := PI
var sight_end := Vector2.ZERO
var collapsed := false
var minions_called := false
var shield_feedback_left := 0.0
var clock := 0.0
var charge_glow: AnimatedSprite2D

var legs: Array = []
var feet: Array = []
var stepping: Array = []
var step_from: Array = []
var step_to: Array = []
var step_t: Array = []
var knees: Array = []
var hips: Array = []

var drawer: Node2D
var hurt_shape: CollisionShape2D
var bar: Node2D

func _core_script() -> Script:
	return SPIDER_CORE

func _configure() -> void:
	body_size = Vector2(150, 130)
	impact_offset = Vector2(0, -BODY_HEIGHT)
	engage_distance = 1500.0

# Núcleo central más grande que el de un guardián normal (ruby_core.core_radius lo lee).
var core_size := 24.0

func _ready() -> void:
	super()
	add_to_group(&"spider_boss")
	z_index = 2
	face_x = float(facing)
	for child in get_children():
		if child is CollisionShape2D:
			hurt_shape = child
	drawer = Node2D.new()
	drawer.name = "SpiderDraw"
	drawer.draw.connect(_draw_spider)
	visual.add_child(drawer)
	for index in range(4):
		var foot := Vector2(position.x + _rest_offset(index), position.y)
		feet.append(foot)
		stepping.append(false)
		step_from.append(foot)
		step_to.append(foot)
		step_t.append(0.0)
		knees.append(foot)
		hips.append(foot)
		var leg: Area2D = LEG_SCRIPT.new()
		leg.name = "SpiderLeg%d" % index
		leg.spider = self
		leg.index = index
		leg.max_health = leg_health
		legs.append(leg)
		get_parent().add_child.call_deferred(leg)
	_update_legs(0.0)
	_sync_parts.call_deferred()

func _build_ui() -> void:
	warning_label = Label.new()
	warning_label.text = "!"
	warning_label.add_theme_font_size_override("font_size", 52)
	warning_label.add_theme_color_override("font_color", WARNING_COLOR)
	warning_label.add_theme_color_override("font_outline_color", Color(0.1, 0.02, 0.02))
	warning_label.add_theme_constant_override("outline_size", 8)
	warning_label.visible = false
	add_child(warning_label)
	bar = Node2D.new()
	add_child(bar)
	var name_label := Label.new()
	name_label.text = boss_name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.7))
	name_label.add_theme_color_override("font_outline_color", Color(0.1, 0.03, 0.02))
	name_label.add_theme_constant_override("outline_size", 5)
	name_label.position = Vector2(-90, -30)
	bar.add_child(name_label)

# ---------- Estado común

func legs_alive() -> int:
	var count := 0
	for leg in legs:
		if is_instance_valid(leg) and not leg.broken:
			count += 1
	return count

func _leg_alive(index: int) -> bool:
	return index >= 0 and index < legs.size() and is_instance_valid(legs[index]) and not legs[index].broken

func is_warning() -> bool:
	return state in [State.STAB_WINDUP, State.CHARGE_WINDUP, State.RAIL_AIM, State.RAIL_LOCK, State.SLAM_WINDUP]

func _physics_process(delta: float) -> void:
	clock += delta
	flash_timer = maxf(flash_timer - delta, 0.0)
	shield_feedback_left = maxf(shield_feedback_left - delta, 0.0)
	face_x = move_toward(face_x, float(facing), 2.5 * delta)
	if defeated:
		_update_legs(delta)
		_sync_parts()
		drawer.queue_redraw()
		return
	# Ejecutando un ruby (de una pata o el central) o el núcleo en remate: queda quieta.
	if ruby_core.holds_actor() or _leg_claimed():
		_sync_parts()
		drawer.queue_redraw()
		return
	var warning: bool = is_warning()
	if warning and not was_warning:
		Sfx.play("boss_alert")
	was_warning = warning
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if not combat_started and (_player_engaged(player) or _ally_in_combat()):
		combat_started = true
	_boss_process(delta, player)
	_update_legs(delta)
	_sync_parts()
	drawer.queue_redraw()

func _leg_claimed() -> bool:
	for leg in legs:
		if is_instance_valid(leg) and leg.ruby_core != null and leg.ruby_core.locked:
			return true
	return false

func _player_engaged(player: Node2D) -> bool:
	if player == null:
		return false
	var offset := player.global_position - global_position
	return absf(offset.x) < engage_distance and absf(offset.y) < 700.0

# ---------- Comportamiento

func _boss_process(delta: float, player: Node2D) -> void:
	state_timer -= delta
	rail_cooldown = maxf(rail_cooldown - delta, 0.0)
	charge_cooldown = maxf(charge_cooldown - delta, 0.0)
	var target_height: float = COLLAPSED_HEIGHT if collapsed else BODY_HEIGHT - 26.0 * (4 - legs_alive())
	if state != State.COLLAPSE:
		body_height = move_toward(body_height, target_height, 140.0 * delta)
	match state:
		State.IDLE:
			body_shift = body_shift.lerp(Vector2.ZERO, 4.0 * delta)
			_turn_towards(player)
			if state_timer <= 0.0 and combat_started and player != null:
				_decide(player)
		State.WALK:
			_turn_towards(player)
			decision_timer -= delta
			var speed: float = walk_speed * (0.45 if collapsed else 1.0)
			position.x = clampf(position.x + facing * speed * delta, min_x + 260.0, max_x - 260.0)
			if decision_timer <= 0.0 or (player != null and _distance_to(player) < 300.0):
				_decide(player)
		State.STAB_WINDUP:
			var progress: float = 1.0 - state_timer / stab_windup
			if _leg_alive(stab_leg):
				var raised: Vector2 = _body_world() + Vector2(face_x * 210.0, -70.0 - 30.0 * sin(progress * PI * 0.5))
				feet[stab_leg] = stab_from.lerp(raised, ease(minf(progress * 1.6, 1.0), 0.5))
			if player != null:
				stab_target = Vector2(clampf(player.global_position.x, position.x - 560.0, position.x + 560.0), position.y)
			if state_timer <= 0.0:
				_start_stab()
		State.STAB:
			var progress: float = 1.0 - state_timer / 0.14
			if _leg_alive(stab_leg):
				feet[stab_leg] = stab_from.lerp(stab_target, ease(clampf(progress, 0.0, 1.0), 2.4))
			if state_timer <= 0.0:
				_stab_impact(player)
		State.CHARGE_WINDUP:
			var progress: float = 1.0 - state_timer / charge_windup
			body_shift = body_shift.lerp(Vector2(-face_x * 50.0, 34.0), 5.0 * delta)
			if int(progress * 20.0) % 2 == 0:
				flash_timer = 0.02
			if state_timer <= 0.0:
				_start_charge()
		State.CHARGE:
			var step: float = minf(charge_speed * delta, charge_left)
			charge_left -= step
			var before := position.x
			position.x = clampf(position.x + facing * step, min_x + 260.0, max_x - 260.0)
			body_shift = body_shift.lerp(Vector2(face_x * 30.0, 0.0), 8.0 * delta)
			_check_charge(player)
			if charge_left <= 0.0 or is_equal_approx(before, position.x):
				Sfx.play("heavy_land", 2.0, 0.6)
				Fx.dust(get_parent(), global_position + Vector2(face_x * 200.0, 0), Vector2(-face_x, 0), 10, 2.2)
				_recover(1.3)
		State.RAIL_AIM, State.RAIL_RETRACK:
			if player != null:
				var wanted := (player.global_position + Vector2(0, -26) - _muzzle_base()).angle()
				aim_angle = lerp_angle(aim_angle, wanted, minf(5.0 * delta, 1.0))
			_update_sight()
			if state_timer <= 0.0:
				state = State.RAIL_LOCK
				state_timer = rail_lock_time
				Sfx.play("enemy_charge", 0.0, 1.3)
		State.RAIL_LOCK:
			_update_sight()
			if state_timer <= 0.0:
				_fire_rail(player)
		State.RECOVER:
			body_shift = body_shift.lerp(Vector2.ZERO, 4.0 * delta)
			if state_timer <= 0.0:
				state = State.IDLE
				state_timer = 0.5
		State.COLLAPSE:
			var progress: float = 1.0 - state_timer / 1.0
			body_height = lerpf(body_height, COLLAPSED_HEIGHT, ease(progress, 2.0))
			if state_timer <= 0.0:
				_finish_collapse()
		State.SLAM_WINDUP:
			body_shift = Vector2(0, -24.0 * sin((1.0 - state_timer / slam_windup) * PI))
			if state_timer <= 0.0:
				_slam(player)

func _turn_towards(player: Node2D) -> void:
	if player == null:
		return
	var side: int = 1 if player.global_position.x >= global_position.x else -1
	# Gira solo si Viridy queda claramente detrás (no a cada paso).
	if side != facing and absf(player.global_position.x - global_position.x) > 120.0:
		facing = side

func _decide(player: Node2D) -> void:
	if player == null:
		state = State.IDLE
		state_timer = 0.6
		return
	_turn_towards(player)
	var distance := _distance_to(player)
	var above: bool = player.global_position.y < global_position.y - 240.0
	if collapsed:
		if rail_cooldown <= 0.0 and (distance > 260.0 or randf() < 0.4):
			_start_rail()
		elif distance < 300.0:
			_start_windup(State.SLAM_WINDUP, slam_windup, "")
		else:
			state = State.WALK
			decision_timer = 1.6
		return
	if rail_cooldown <= 0.0 and (distance > 650.0 or above or randf() < 0.3):
		_start_rail()
	elif distance < 520.0 and _pick_stab_leg(player) >= 0 and (charge_cooldown > 0.0 or randf() < 0.65):
		_start_stab_windup(player)
	elif charge_cooldown <= 0.0 and distance < 1300.0:
		_start_windup(State.CHARGE_WINDUP, charge_windup, "¡ARREMETIDA!")
		charge_glow = Fx.charge(get_parent(), _head_world(), GLOW, 1.0, 1.6)
		Sfx.play("boss_charge", 0.0, 0.7)
	else:
		state = State.WALK
		decision_timer = 1.8

func _start_windup(next: State, duration: float, callout: String) -> void:
	state = next
	state_timer = duration
	warning_label.visible = true
	if callout != "":
		Fx.text(get_parent(), _body_world() + Vector2(-40, -150), callout, GLOW.lightened(0.35))

func _recover(duration: float) -> void:
	state = State.RECOVER
	state_timer = duration
	warning_label.visible = false
	hit_done = false
	if is_instance_valid(charge_glow):
		charge_glow.queue_free()

# ---------- Estocada

func _pick_stab_leg(player: Node2D) -> int:
	var best := -1
	var best_distance := INF
	for index in range(4):
		if not _leg_alive(index) or stepping[index]:
			continue
		var distance: float = absf(feet[index].x - player.global_position.x) + (0.0 if LEG_FRONT[index] else 260.0)
		if distance < best_distance:
			best = index
			best_distance = distance
	return best

func _start_stab_windup(player: Node2D) -> void:
	stab_leg = _pick_stab_leg(player)
	stab_from = feet[stab_leg]
	_start_windup(State.STAB_WINDUP, stab_windup, "")
	Sfx.play("boss_swing", 0.0, 0.6)

func _start_stab() -> void:
	parry_serial += 1
	warning_label.visible = false
	hit_done = false
	state = State.STAB
	state_timer = 0.14
	stab_from = feet[stab_leg] if _leg_alive(stab_leg) else stab_from

func _stab_impact(player: Node2D) -> void:
	if _leg_alive(stab_leg):
		feet[stab_leg] = stab_target
		step_from[stab_leg] = stab_target
		step_to[stab_leg] = stab_target
	Sfx.play("heavy_land", 2.0, 0.55)
	Sfx.play("shockwave", -2.0, 0.9)
	Fx.impact(get_parent(), stab_target + Vector2(0, -10), [Color(0.3, 0.08, 0.04), GLOW, Color(1.0, 0.92, 0.75)], 1.9)
	Fx.dust(get_parent(), stab_target, Vector2.UP, 9, 1.8)
	if player != null and not hit_done and _leg_alive(stab_leg):
		var shin_top: Vector2 = knees[stab_leg].lerp(stab_target, 0.4)
		if _segment_hits_player(player, shin_top, stab_target, 34.0) or (player.global_position.distance_to(stab_target) < 80.0):
			hit_done = true
			player.take_damage(stab_damage, stab_target + Vector2(0, -40), self)
	_recover(1.0)

# ---------- Arremetida

func _start_charge() -> void:
	parry_serial += 1
	warning_label.visible = false
	hit_done = false
	state = State.CHARGE
	charge_left = charge_distance
	charge_cooldown = 6.0
	if is_instance_valid(charge_glow):
		charge_glow.queue_free()
	Sfx.play("boss_dash", 2.0, 0.55)

func _check_charge(player: Node2D) -> void:
	if hit_done or player == null:
		return
	var head := _head_world()
	var chest := _body_world() + Vector2(face_x * 40.0, 40.0)
	var ground := Vector2(head.x + face_x * 40.0, global_position.y - 10.0)
	if _segment_hits_player(player, chest, head, 70.0) or _segment_hits_player(player, head, ground, 48.0):
		hit_done = true
		player.take_damage(charge_damage, head, self)

# ---------- Railgun

func _start_rail() -> void:
	_start_windup(State.RAIL_AIM, rail_aim_time, "¡RAILGUN!")
	shots_left = 3
	rail_cooldown = rail_cooldown_time
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player != null:
		aim_angle = (player.global_position - _muzzle_base()).angle()
	Sfx.play("boss_charge", 0.0, 1.1)
	Fx.charge(get_parent(), _muzzle_world(), RAIL_COLOR, 0.6, 1.2)

func _update_sight() -> void:
	var from := _muzzle_world()
	var to := from + Vector2.from_angle(aim_angle) * 2600.0
	var hit := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(from, to, WORLD_MASK))
	sight_end = hit.position if not hit.is_empty() else to

func _fire_rail(player: Node2D) -> void:
	parry_serial += 1
	_update_sight()
	var from := _muzzle_world()
	Sfx.play("rail_shot", 2.0, 0.7)
	Fx.muzzle(get_parent(), from, aim_angle, RAIL_COLOR, 1.8)
	var beam := Node2D.new()
	beam.z_index = 8
	get_parent().add_child(beam)
	var tween := beam.create_tween().set_parallel()
	for layer in [[22.0, Color(RAIL_COLOR, 0.6)], [8.0, Color(1.0, 0.92, 0.85)]]:
		var line := Line2D.new()
		line.width = layer[0]
		line.default_color = layer[1]
		line.points = PackedVector2Array([from, sight_end])
		beam.add_child(line)
		tween.tween_property(line, "width", 0.0, 0.28)
	tween.chain().tween_callback(beam.queue_free)
	Fx.bullet_impact(get_parent(), sight_end, RAIL_COLOR, (from - sight_end).angle())
	Fx.zap(get_parent(), sight_end, RAIL_COLOR, 0.8)
	Fx.impact(get_parent(), from, [Color(0.3, 0.05, 0.03), RAIL_COLOR, Color.WHITE], 1.2)
	if player != null and _segment_hits_player(player, from, sight_end, 22.0):
		player.take_damage(rail_damage, from, self)
	shots_left -= 1
	if shots_left > 0:
		state = State.RAIL_RETRACK
		state_timer = rail_retrack_time
	else:
		_recover(1.2)

# ---------- Desplome

func on_leg_destroyed(leg: Node) -> void:
	var point: Vector2 = leg.global_position
	Fx.explosion(get_parent(), point, 0.55)
	Fx.text(get_parent(), point + Vector2(0, -60), "¡PATA DESTRUIDA!", Color(1.0, 0.8, 0.5))
	Ferocity.add("spider_leg", 80.0, "PATA ROTA", Ferocity.BONUS_COLOR)
	Sfx.play("grenade_blast", 0.0, 0.8)
	if state in [State.STAB_WINDUP, State.STAB] and leg.index == stab_leg:
		_recover(0.8)
	if legs_alive() == 0 and not collapsed:
		_start_collapse()

func _start_collapse() -> void:
	collapsed = true
	state = State.COLLAPSE
	state_timer = 1.0
	warning_label.visible = false
	if is_instance_valid(charge_glow):
		charge_glow.queue_free()
	Sfx.play("boss_hurt", 2.0, 0.6)

func _finish_collapse() -> void:
	body_height = COLLAPSED_HEIGHT
	Sfx.play("heavy_land", 4.0, 0.45)
	Sfx.play("guard_break", 0.0, 0.8)
	Fx.impact(get_parent(), global_position + Vector2(0, -20), [Color(0.25, 0.1, 0.05), GLOW, Color.WHITE], 2.6)
	Fx.dust(get_parent(), global_position + Vector2(-160, 0), Vector2.LEFT, 12, 2.6)
	Fx.dust(get_parent(), global_position + Vector2(160, 0), Vector2.RIGHT, 12, 2.6)
	Fx.text(get_parent(), _body_world() + Vector2(-90, -120), "¡NÚCLEO EXPUESTO!", GLOW.lightened(0.4))
	_call_minions()
	_recover(1.2)

func _call_minions() -> void:
	# Una sola vez, al quedarse sin patas: esbirros pequeños a los dos lados.
	if minions_called:
		return
	minions_called = true
	# Llegan ya en combate (sin agente de sigilo): no pasan por el director de la oleada.
	for index in range(minion_count):
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var x: float = clampf(global_position.x + side * (330.0 + (index / 2) * 140.0), min_x + 60.0, max_x - 60.0)
		var enemy: Area2D
		if index < 2:
			enemy = CHASER_SCRIPT.new()
			enemy.position = Vector2(x, global_position.y)
		else:
			enemy = STINGER_SCRIPT.new()
			enemy.position = Vector2(x, global_position.y - 220.0)
		enemy.add_to_group(&"spider_minions")
		get_parent().add_child.call_deferred(enemy)
		Fx.warp_in(get_parent(), Vector2(x, global_position.y), GLOW)

func _slam(player: Node2D) -> void:
	parry_serial += 1
	warning_label.visible = false
	body_shift = Vector2.ZERO
	Sfx.play("shockwave", 2.0, 0.7)
	Sfx.play("heavy_land", 2.0, 0.5)
	var center := global_position + Vector2(face_x * ABDOMEN.x * 0.3, 0)
	Fx.impact(get_parent(), center + Vector2(0, -20), [Color(0.3, 0.08, 0.04), GLOW, Color.WHITE], 2.4)
	Fx.dust(get_parent(), center, Vector2.LEFT, 10, 2.2)
	Fx.dust(get_parent(), center, Vector2.RIGHT, 10, 2.2)
	if player != null and player.global_position.distance_to(center) <= slam_radius and player.global_position.y > center.y - 140.0:
		player.take_damage(slam_damage, center, self)
	_recover(1.1)

# ---------- Daño

func take_hit(source_position: Vector2, direction: int = 1, damage: int = 1, play_hit_sound: bool = true) -> void:
	if defeated:
		return
	if legs_alive() > 0:
		# El ruby central está protegido mientras le quede alguna pata.
		if shield_feedback_left <= 0.0:
			shield_feedback_left = 0.4
			Sfx.play("block", 0.0, 0.8)
			Fx.shield_hit(get_parent(), global_position + impact_offset, SHIELD, source_position.x > global_position.x + impact_offset.x)
			Fx.text(get_parent(), global_position + impact_offset + Vector2(-40, -70), "PROTEGIDO", SHIELD.lightened(0.3))
		return
	super.take_hit(source_position, direction, damage, play_hit_sound)

func on_shine_hit(_direction: int, _strength: float) -> void:
	# Demasiado grande para empujarla.
	flash_timer = 0.06

func on_deflected(_by: Node) -> void:
	# El parry anula el golpe, pero ni la aturde ni le baja la postura.
	hit_done = true
	Fx.text(get_parent(), global_position + Vector2(0, -BODY_HEIGHT - 120.0), "¡NO SE INMUTA!", Color(1.0, 0.75, 0.45))

func on_projectile_parried(_token: int) -> void:
	pass

func on_stagger() -> void:
	pass

func _on_posture_broken() -> void:
	warning_label.hide()
	if is_instance_valid(charge_glow):
		charge_glow.queue_free()

func _on_reset() -> void:
	# Tras el remate fallido (el núcleo vuelve con algo de vida) sigue donde estaba: no recupera patas.
	state = State.IDLE
	state_timer = 0.8
	hit_done = false
	warning_label.visible = false

func _on_defeat() -> void:
	Fx.big_explosion(get_parent(), global_position + Vector2(0, 10), 1.3)
	Sfx.play("grenade_blast", 4.0, 0.6)
	for leg in legs:
		if is_instance_valid(leg):
			leg.broken = true
			leg.set_deferred("monitorable", false)
			leg.ruby_core.hide()

# ---------- Patas (IK y pisadas)

func _rest_offset(index: int) -> float:
	return LEG_REST[index] * (1.0 if LEG_FRONT[index] else -1.0) * face_x

func _body_world() -> Vector2:
	return global_position + Vector2(body_shift.x, -body_height + body_shift.y + sin(clock * 2.2) * 4.0)

func _head_world() -> Vector2:
	return _body_world() + Vector2(HEAD.x * face_x, HEAD.y)

func _muzzle_base() -> Vector2:
	return _body_world() + Vector2(TURRET.x * face_x, TURRET.y)

func _muzzle_world() -> Vector2:
	return _muzzle_base() + Vector2.from_angle(aim_angle) * BARREL

func _hip(index: int) -> Vector2:
	var side: float = 1.0 if LEG_FRONT[index] else -1.0
	var depth: float = 0.0 if LEG_NEAR[index] else -8.0
	return _body_world() + Vector2(side * 52.0 * face_x, 18.0 + depth)

func _update_legs(delta: float) -> void:
	var fast: bool = state == State.CHARGE
	var step_time: float = 0.12 if fast else 0.34
	for index in range(4):
		hips[index] = _hip(index)
		if not _leg_alive(index) or defeated:
			# Pata rota: se derrumba y queda tendida en el suelo hacia fuera.
			var outward: float = (1.0 if LEG_FRONT[index] else -1.0) * face_x
			var fallen := Vector2(hips[index].x + outward * (SHIN + 60.0), global_position.y)
			feet[index] = feet[index].lerp(fallen, minf(4.0 * delta, 1.0))
			stepping[index] = false
		elif index == stab_leg and state in [State.STAB_WINDUP, State.STAB]:
			pass
		elif stepping[index]:
			step_t[index] = minf(step_t[index] + delta / step_time, 1.0)
			var t: float = step_t[index]
			feet[index] = step_from[index].lerp(step_to[index], t) + Vector2(0, -sin(t * PI) * (40.0 if fast else 70.0))
			if t >= 1.0:
				stepping[index] = false
				feet[index] = step_to[index]
				if not fast and LEG_NEAR[index]:
					Sfx.play("step", -8.0, 0.4)
					Fx.dust(get_parent(), feet[index], Vector2.UP, 3, 0.8)
		else:
			var rest := Vector2(global_position.x + _rest_offset(index), global_position.y)
			var trigger: float = 70.0 if fast else STRIDE
			var other_group_stepping := false
			for other in range(4):
				if stepping[other] and LEG_GROUP[other] != LEG_GROUP[index]:
					other_group_stepping = true
			# También vuelve a apoyar una pata que quedó en el aire (tras una estocada interrumpida).
			var lifted: bool = absf(feet[index].y - global_position.y) > 4.0
			if (absf(feet[index].x - rest.x) > trigger or lifted) and not other_group_stepping:
				stepping[index] = true
				step_t[index] = 0.0
				step_from[index] = feet[index]
				var ahead: float = signf(rest.x - feet[index].x) * STRIDE * (0.8 if fast else 0.5)
				step_to[index] = Vector2(rest.x + ahead, global_position.y)
		knees[index] = _solve_knee(hips[index], feet[index], index)

func _solve_knee(hip: Vector2, foot: Vector2, index: int) -> Vector2:
	var span := foot - hip
	var distance: float = clampf(span.length(), absf(THIGH - SHIN) + 1.0, THIGH + SHIN - 1.0)
	var direction := span.normalized() if span.length() > 0.01 else Vector2.DOWN
	var alpha := acos(clampf((THIGH * THIGH + distance * distance - SHIN * SHIN) / (2.0 * THIGH * distance), -1.0, 1.0))
	var a: Vector2 = hip + direction.rotated(alpha) * THIGH
	var b: Vector2 = hip + direction.rotated(-alpha) * THIGH
	# Rodillas hacia arriba y hacia fuera, como una araña.
	var outward: float = (1.0 if LEG_FRONT[index] else -1.0) * face_x
	var score_a: float = -a.y + (a.x - hip.x) * outward * 0.3
	var score_b: float = -b.y + (b.x - hip.x) * outward * 0.3
	return a if score_a >= score_b else b

func _ruby_point(index: int) -> Vector2:
	return knees[index].lerp(feet[index], 0.7)

func _sync_parts() -> void:
	for index in range(legs.size()):
		var leg: Area2D = legs[index]
		if is_instance_valid(leg) and leg.is_inside_tree():
			leg.global_position = _ruby_point(index)
	# Núcleo central en el abdomen: también la hurtbox del guardián.
	var abdomen := _body_world() + Vector2(ABDOMEN.x * face_x, ABDOMEN.y + 22.0) - global_position
	impact_offset = abdomen
	if ruby_core != null:
		ruby_core.position = abdomen
	if hurt_shape != null:
		hurt_shape.position = abdomen
	var top := _body_world() - global_position
	warning_label.position = top + Vector2(-12, -190)
	if bar != null:
		bar.position = top + Vector2(0, -120)

# ---------- Dibujo

func _draw_spider() -> void:
	var o := global_position
	# Patas lejanas detrás del cuerpo.
	for index in [2, 3]:
		_draw_leg(index, o, true)
	var body := _body_world() - o
	var flash: bool = flash_timer > 0.0
	var armor: Color = Color(1.0, 0.6, 0.55) if flash else ARMOR
	# Abdomen: un gran casco de placas.
	var abdomen := body + Vector2(ABDOMEN.x * face_x, ABDOMEN.y)
	drawer.draw_set_transform(abdomen, 0.0, Vector2(1.25, 0.85))
	drawer.draw_circle(Vector2.ZERO, 98.0, ARMOR_DARK)
	drawer.draw_circle(Vector2(0, -6), 90.0, armor)
	drawer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for plate in range(4):
		var px: float = abdomen.x + (plate - 1.5) * 44.0 * face_x
		drawer.draw_arc(Vector2(px, abdomen.y - 10.0), 58.0 - absf(plate - 1.5) * 8.0, PI * 1.12, PI * 1.88, 12, ARMOR_LIGHT, 3.0)
	# Rejillas que brillan al cargar.
	var charging: bool = state in [State.CHARGE_WINDUP, State.CHARGE]
	for vent in range(3):
		var v := abdomen + Vector2((-50.0 + vent * 30.0) * face_x, 40.0)
		drawer.draw_rect(Rect2(v - Vector2(9, 3), Vector2(18, 6)), GLOW if charging else ARMOR_DARK.darkened(0.3))
	# Escudo sobre el ruby central mientras queden patas.
	var core_point := abdomen + Vector2(0, 22)
	if legs_alive() > 0 and not defeated:
		var pulse := 0.5 + 0.5 * sin(clock * 3.0)
		drawer.draw_circle(core_point, 40.0, Color(SHIELD, 0.12 + 0.06 * pulse))
		drawer.draw_arc(core_point, 40.0, 0.0, TAU, 32, Color(SHIELD, 0.65), 2.5)
		for spoke in range(6):
			var a := TAU * spoke / 6.0 + clock * 0.4
			drawer.draw_line(core_point + Vector2.from_angle(a) * 26.0, core_point + Vector2.from_angle(a) * 40.0, Color(SHIELD, 0.45), 1.5)
	# Tórax.
	drawer.draw_set_transform(body, 0.0, Vector2(1.15, 0.72))
	drawer.draw_circle(Vector2.ZERO, 82.0, ARMOR_DARK)
	drawer.draw_circle(Vector2(0, -5), 75.0, armor)
	drawer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	drawer.draw_arc(body + Vector2(0, -8), 60.0, PI * 1.15, PI * 1.85, 14, ARMOR_LIGHT, 3.0)
	# Cabeza con cuatro ojos.
	var head := body + Vector2(HEAD.x * face_x, HEAD.y)
	drawer.draw_circle(head, 44.0, ARMOR_DARK)
	drawer.draw_circle(head + Vector2(0, -3), 38.0, armor)
	var eye_glow: Color = GLOW.lightened(0.3) if is_warning() else GLOW
	for eye in [Vector2(22, -8), Vector2(30, 6), Vector2(10, -16), Vector2(16, 10)]:
		drawer.draw_circle(head + Vector2(eye.x * face_x, eye.y), 5.0, eye_glow)
	# Mandíbulas.
	for side in [-1.0, 1.0]:
		var base := head + Vector2(30.0 * face_x, 22.0 + side * 6.0)
		drawer.draw_line(base, base + Vector2(26.0 * face_x, 20.0 + side * 4.0), ARMOR_LIGHT, 5.0)
	# Torreta del railgun.
	var turret := body + Vector2(TURRET.x * face_x, TURRET.y)
	drawer.draw_circle(turret, 30.0, ARMOR_DARK)
	drawer.draw_circle(turret + Vector2(0, -3), 25.0, ARMOR_LIGHT.darkened(0.15))
	var barrel_dir := Vector2.from_angle(aim_angle)
	var muzzle := turret + barrel_dir * BARREL
	drawer.draw_line(turret, muzzle, ARMOR_DARK, 18.0)
	drawer.draw_line(turret + barrel_dir * 10.0, muzzle, ARMOR_LIGHT, 8.0)
	var aiming: bool = state in [State.RAIL_AIM, State.RAIL_LOCK, State.RAIL_RETRACK]
	if aiming:
		var locked: bool = state == State.RAIL_LOCK
		var blink: bool = int(clock * 20.0) % 2 == 0
		var sight := Color(1.0, 1.0, 1.0, 0.85) if locked and blink else Color(RAIL_COLOR, 0.55)
		drawer.draw_line(muzzle, sight_end - o, sight, 3.0 if locked else 1.5)
		drawer.draw_circle(sight_end - o, 8.0 if locked else 5.0, sight)
		drawer.draw_circle(muzzle, 9.0, Color(RAIL_COLOR, 0.7))
	# Patas cercanas delante.
	for index in [1, 0]:
		_draw_leg(index, o, false)

func _draw_leg(index: int, o: Vector2, far: bool) -> void:
	var hip: Vector2 = hips[index] - o
	var knee: Vector2 = knees[index] - o
	var foot: Vector2 = feet[index] - o
	var alive := _leg_alive(index) and not defeated
	var tint: Color = FAR_TINT if far else Color.WHITE
	var flash: bool = alive and legs[index].flash_left > 0.0
	var color: Color = Color(1.0, 0.6, 0.55) if flash else ARMOR * tint
	var dark: Color = ARMOR_DARK * tint
	drawer.draw_line(hip, knee, dark, 24.0)
	drawer.draw_line(hip, knee, color, 16.0)
	drawer.draw_circle(hip, 16.0, dark)
	drawer.draw_circle(knee, 15.0, dark)
	drawer.draw_circle(knee, 10.0, ARMOR_LIGHT * tint)
	if alive:
		# Tibia afilada hasta la punta.
		var side := (foot - knee).normalized().orthogonal()
		drawer.draw_colored_polygon(PackedVector2Array([knee + side * 11.0, foot, knee - side * 11.0]), dark)
		drawer.draw_colored_polygon(PackedVector2Array([knee + side * 7.0, foot + (knee - foot).normalized() * 6.0, knee - side * 7.0]), color)
		if index == stab_leg and state == State.STAB_WINDUP and int(clock * 16.0) % 2 == 0:
			drawer.draw_circle(foot, 10.0, GLOW)
	else:
		# Tibia partida, con chispas.
		var snapped := knee.lerp(foot, 0.45)
		drawer.draw_line(knee, snapped, dark, 12.0)
		drawer.draw_line(knee, snapped, color.darkened(0.3), 6.0)
		if not far and int(clock * 7.0 + index) % 5 == 0:
			drawer.draw_circle(snapped, 4.0, Color(1.0, 0.8, 0.4))
