extends Node2D

# Combo ligero de Viridy (3 zarpazos + 2 patadas) con startup / active / recovery, y el Aim de la lanza jade.
# El pesado no vive aquí: es la embestida de movimiento.gd. Un pesado pulsado durante un ligero espera a su
# recovery; dentro del recovery lo cancela al instante.
const MODE := 8
const CHAIN_WINDOW := 0.55
const THROW_SPEED := 1300.0
enum Phase { IDLE, STARTUP, ACTIVE, RECOVERY }
var player: CharacterBody2D
var active := false
var elapsed := 0.0
var duration := 0.0
var startup := 0.0
var active_time := 0.0
var recovery := 0.0
var phase: Phase:
	get:
		if not active:
			return Phase.IDLE
		if elapsed < startup:
			return Phase.STARTUP
		if elapsed < startup + active_time:
			return Phase.ACTIVE
		return Phase.RECOVERY
var step := -1
var window := 0.0
var queued := &""
var move: Dictionary = {}
var hit_set: Array = []
var aim := false
var aim_armed := false
var aim_direction := Vector2.RIGHT
# RT lanzó la lanza: no dashea ni corre hasta soltarlo.
var dash_latch := false
# Suspensión aérea del string: solo tras conectar en el aire, hasta aterrizar.
var air_stall := false

# Timings a 60 Hz: startup / active / recovery. En ejecución se usan segundos.
static func hit(kind: String, damage: int, frames: Vector3i, reach: float, height: float, stagger := 0.0, push := 180.0) -> Dictionary:
	return {"kind": kind, "damage": damage, "duration": (frames.x + frames.y + frames.z) / 60.0,
		"startup": frames.x / 60.0, "active_time": frames.y / 60.0, "recovery": frames.z / 60.0, "reach": reach, "height": height,
		"stagger": stagger, "push": push}

static func chain() -> Array:
	return [hit("claw", 1, Vector3i(2, 3, 5), 80, 80), hit("claw", 1, Vector3i(2, 3, 5), 80, 80), hit("claw", 2, Vector3i(3, 4, 6), 105, 100),
		hit("kick", 2, Vector3i(3, 4, 7), 118, 65, 0.35, 340), hit("kick", 2, Vector3i(4, 5, 8), 132, 75, 0.5, 440)]

func _ready() -> void:
	player = get_parent()
	z_index = 5

func tick(delta: float) -> void:
	if player.is_on_floor():
		air_stall = false
	window = maxf(window - delta, 0.0)
	# LT: con la lanza en la mano se apunta mientras se mantiene; con la lanza clavada, un toque la recupera.
	if Input.is_action_just_pressed("throw_knife"):
		if player.has_knife:
			aim_armed = true
		else:
			player.recall_spear()
	if not Input.is_action_pressed("throw_knife"):
		aim_armed = false
	if not Input.is_action_pressed("dash"):
		dash_latch = false
	aim = aim_armed and player.has_knife and not player._blocks_actions()
	if Input.is_action_just_pressed("dash") and (aim or aim_armed):
		dash_latch = true
	if aim:
		if player.dash_timer > 0.0:
			player.dash_timer = 0.0
			player._set_dash_visual_active(false)
		player._stop_sprint()
		player.long_jump_active = false
		player.backflip_active = false
		player.velocity.x = clampf(player.velocity.x, -player.max_speed, player.max_speed)
		_update_aim()
	if active:
		var previous := elapsed
		elapsed += delta
		_advance(previous)
		if active and queued == &"heavy" and phase == Phase.RECOVERY:
			interrupt()
			player._start_heavy_attack()
	queue_redraw()

func _advance(previous: float) -> void:
	if previous < startup and elapsed >= startup:
		Sfx.play("swing_light", 0.0, [1.0, 1.0, 1.12, 0.94, 0.88][step])
	# Revisar todo el intervalo: un frame largo no puede saltarse la ventana de daño.
	if elapsed >= startup and previous < startup + active_time:
		_strike()
	if active and elapsed >= duration:
		_finish()

func request() -> bool:
	if aim or player._blocks_actions() or player.dash_timer > 0.0:
		return false
	if active:
		queued = &"light"
		return true
	if player._is_attack_active() or player.attack_cooldown_timer > 0.0:
		return false
	var moves := chain()
	if window > 0.0 and step + 1 < moves.size():
		step += 1
	else:
		step = 0
	move = moves[step]
	startup = float(move.startup)
	active_time = float(move.active_time)
	recovery = float(move.recovery)
	duration = startup + active_time + recovery
	elapsed = 0.0
	hit_set.clear()
	active = true
	queued = &""
	window = 0.0
	player._face_attack_input()
	player.attack_mode = MODE
	player.attack_timer = 0.0
	player._set_attack_active(false)
	player.light_combo_step = step + 1
	if not player.is_on_floor() and air_stall:
		player.velocity.y = minf(player.velocity.y, -50.0)
	return true

func blocks_dash() -> bool:
	# Mientras se mantiene LT (apuntando, o tras lanzar sin soltarlo) RT nunca dashea.
	return aim or aim_armed or dash_latch

func queue_heavy() -> void:
	queued = &"heavy"

func active_progress() -> float:
	return clampf((elapsed - startup) / maxf(active_time, 0.001), 0.0, 1.0)

func phase_progress() -> float:
	match phase:
		Phase.STARTUP:
			return clampf(elapsed / maxf(startup, 0.001), 0.0, 1.0)
		Phase.ACTIVE:
			return active_progress()
		Phase.RECOVERY:
			return clampf((elapsed - startup - active_time) / maxf(recovery, 0.001), 0.0, 1.0)
	return 0.0

func apply_movement(delta: float, horizontal: float) -> void:
	if player.is_sprinting:
		player._apply_sprint_movement(horizontal, delta)
	else:
		player.velocity.x = move_toward(player.velocity.x, horizontal * player.max_speed * 0.45, player.ground_acceleration * delta)
	if player.is_on_floor():
		player.velocity.y = 0.0
	elif air_stall:
		player.velocity.y = minf(player.velocity.y + player.gravity * delta * 0.08, 85.0)
	else:
		# Sin golpear a nadie el string no sostiene en el aire: nada de vuelo infinito.
		player._apply_gravity(delta)

func _finish() -> void:
	var next := queued
	active = false
	queued = &""
	player.attack_mode = player.ATTACK_NONE
	player.riposte_attack = false
	player.attack_effects.visible = false
	player.claw_slash_sprite.hide()
	window = CHAIN_WINDOW
	if step + 1 >= chain().size():
		step = -1
		window = 0.0
		# El recovery ya forma parte del último golpe: sin una cuarta fase oculta.
		player.attack_cooldown_timer = 0.0
	if next == &"light" and window > 0.0:
		# El buffer no vuelve a iniciar una cadena completa tras su último golpe.
		player.attack_cooldown_timer = 0.0
		request()

func interrupt() -> void:
	# Corta el ataque actual sin abrir ventana de combo ni lanzar lo que hubiera en cola.
	active = false
	queued = &""
	window = 0.0
	step = -1
	player.attack_mode = player.ATTACK_NONE
	player.riposte_attack = false
	player.attack_cooldown_timer = 0.0
	player.attack_effects.visible = false
	player.claw_slash_sprite.hide()

func in_recovery() -> bool:
	return active and phase == Phase.RECOVERY

func cancel() -> void:
	active = false
	elapsed = 0.0
	queued = &""
	window = 0.0
	step = -1
	if is_instance_valid(player) and is_instance_valid(player.claw_slash_sprite):
		player.claw_slash_sprite.hide()

func _targets(center: Vector2, size: Vector2) -> Array:
	var shapes: Array[Shape2D] = []
	var transform := Transform2D(0.0, center)
	if move.kind == "claw":
		# Conservar la geometría exacta de los zarpazos, incluida su concavidad.
		var outline: PackedVector2Array = player.claw_finisher_polygon if step == 2 else player.claw_hitbox_polygon
		for polygon in Geometry2D.decompose_polygon_in_convex(outline):
			var shape := ConvexPolygonShape2D.new()
			shape.points = polygon
			shapes.append(shape)
		transform = player.hitbox.global_transform
	else:
		var shape := RectangleShape2D.new()
		shape.size = size
		shapes.append(shape)
	var query := PhysicsShapeQueryParameters2D.new()
	query.transform = transform
	query.collision_mask = 8
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var result: Array = []
	var excluded: Array[RID] = []
	for shape in shapes:
		query.shape = shape
		while true:
			query.exclude = excluded
			var hits := get_world_2d().direct_space_state.intersect_shape(query, 32)
			if hits.is_empty():
				break
			for hit in hits:
				excluded.append(hit.rid)
				var enemy: Node2D = hit.collider
				if not enemy.has_method("take_hit") or not enemy.visible or enemy in result:
					continue
				var point: Vector2 = player._get_target_center(enemy)
				var ray := PhysicsRayQueryParameters2D.create(player.global_position + Vector2(0, -26), point, 2)
				if get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
					result.append(enemy)
	return result

func attack_rect() -> Rect2:
	var reach := float(move.get("reach", 0.0))
	var size := Vector2(reach, float(move.get("height", 0.0)))
	var center := Vector2(player.facing * (reach * 0.5 + 8), -30)
	return Rect2(center - size * 0.5, size)

func _strike() -> void:
	var rect := attack_rect()
	for enemy in _targets(player.global_position + rect.get_center(), rect.size):
		if enemy in hit_set:
			continue
		hit_set.append(enemy)
		if enemy.has_method("try_block") and enemy.try_block(player.global_position):
			player._on_attack_blocked(enemy)
			return
		var damage := maxi(1, roundi(float(move.damage) * Ferocity.damage_multiplier() * (2.0 if player.riposte_attack else 1.0)))
		var direction := 1 if enemy.global_position.x >= player.global_position.x else -1
		enemy.take_hit(player.global_position, direction, damage)
		var core: Node = enemy.get_node_or_null("RubyCore")
		if core != null:
			core.stagger(float(move.stagger))
		if enemy.has_method("on_shine_hit") and move.kind == "kick":
			enemy.on_shine_hit(direction, float(move.push))
		player._spawn_hit_feedback(enemy)
		Ferocity.add("light_combo", 6.0 + step * 2.0, "COMBO %d" % (step + 1))
		Sfx.play("hit_light")
		if not player.is_on_floor():
			air_stall = true
			player._apply_light_hit_air_boost()

func _update_aim() -> void:
	if InputHints.device == InputHints.Device.KEYBOARD:
		var direction := player.get_global_mouse_position() - (player.global_position + Vector2(0, -26))
		if direction.length() > 12:
			aim_direction = direction.normalized()
	else:
		var direction := Vector2.ZERO
		for device in Input.get_connected_joypads():
			direction = Vector2(Input.get_joy_axis(device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y))
			if direction.length() > 0.25:
				break
		if direction.length() > 0.25:
			aim_direction = direction.normalized()
		elif Input.is_action_just_pressed("throw_knife"):
			aim_direction = Vector2(player.facing, 0)

func throw_velocity() -> Vector2:
	return aim_direction * THROW_SPEED

func _draw() -> void:
	if aim:
		var origin := Vector2(0, -26)
		var end := origin + aim_direction * 165.0
		draw_line(origin + aim_direction * 40, end, Color(0.5, 1, 0.75, 0.6), 2, true)
		draw_arc(end, 8, 0, TAU, 16, Color(0.8, 1, 0.65), 2, true)
	if phase == Phase.ACTIVE and move.kind == "kick":
		var rect := attack_rect()
		if player.show_hitbox_debug:
			draw_rect(rect, Color(0.5, 1, 0.7, 0.15))
			draw_rect(rect, Color(0.5, 1, 0.7), false, 2)
