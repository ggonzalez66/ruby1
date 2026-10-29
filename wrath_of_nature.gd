extends Node2D

enum State { IDLE, CHARGING, READY, AIM, RUSH, RECOIL, SHATTER, RECOVERY }
const SSS_COLOR := Color(1.0, 0.18, 0.4)
const JADE := Color(0.22, 0.65, 0.43)
@export var charge_duration := 1.0
@export var ready_duration := 4.0
@export var aim_duration := 0.50
@export var rush_speed := 1850.0
@export var max_distance := 4800.0
@export var max_rush_duration := 3.0
@export var recoil_duration := 0.12
@export var shatter_duration := 0.30
@export var recovery_duration := 0.18

var player: CharacterBody2D
var state := State.IDLE
var elapsed := 0.0
var ready_left := 0.0
var distance := 0.0
var direction := Vector2.RIGHT
var recoil := Vector2.ZERO
var captured: Array[Node2D] = []
var afterimage_wait := 0.0
var trail_wait := 0.0
var clock := 0.0
var landed := false
var aura: Node2D
var recovery_ghost: Sprite2D

func _ready() -> void:
	player = get_parent()
	z_index = 3
	aura = Node2D.new()
	aura.z_index = -6
	aura.draw.connect(_draw_aura)
	add_child(aura)

func controls_movement() -> bool:
	return state in [State.AIM, State.RUSH, State.RECOIL, State.SHATTER, State.RECOVERY]

func uses_beast() -> bool:
	return state in [State.RUSH, State.RECOIL, State.SHATTER]

func invulnerable() -> bool:
	return state in [State.AIM, State.RUSH, State.RECOIL, State.SHATTER, State.RECOVERY]

func is_ready() -> bool:
	return state in [State.READY, State.AIM]

func tick(delta: float) -> void:
	clock += delta
	if player.dead:
		cancel()
		return
	if state in [State.IDLE, State.CHARGING]:
		var can_charge: bool = player.is_crouching() and Ferocity.rank == 6
		if can_charge:
			if state != State.CHARGING:
				Sfx.start_loop("wrath_charge")
			state = State.CHARGING
			Ferocity.drain_locked = true
			elapsed += delta
			if elapsed >= charge_duration:
				arm()
		elif state == State.CHARGING:
			Sfx.stop_loop("wrath_charge")
			state = State.IDLE
			elapsed = 0.0
			Ferocity.drain_locked = false
	elif state == State.READY:
		ready_left = maxf(ready_left - delta, 0.0)
		Ferocity.special_progress = ready_left / ready_duration
		_destroy_projectiles()
		if ready_left <= 0.0:
			cancel()
	elif controls_movement():
		player._update_timers(delta)
		elapsed += delta
		_destroy_projectiles()
		match state:
			State.AIM:
				var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
				if input_direction.length_squared() >= 0.01:
					var candidate := Vector2(signf(input_direction.x), signf(input_direction.y)).normalized()
					if not (landed and _blocked_on_ground(candidate)):
						direction = candidate
				player.velocity = Vector2.ZERO
				Ferocity.special_progress = maxf(1.0 - elapsed / aim_duration, 0.0)
				if elapsed >= aim_duration:
					launch(direction)
			State.RUSH:
				if Input.is_action_just_pressed("heavy_attack"):
					_brake()
				else:
					_rush(delta)
			State.RECOIL:
				player.velocity = recoil * (1.0 - clampf(elapsed / recoil_duration, 0.0, 1.0))
				player.move_and_collide(player.velocity * delta)
				if elapsed >= recoil_duration:
					state = State.SHATTER
					elapsed = 0.0
			State.SHATTER:
				player.velocity = Vector2.ZERO
				if elapsed >= shatter_duration:
					_shatter()
			State.RECOVERY:
				var progress := clampf(elapsed / recovery_duration, 0.0, 1.0)
				player.animated_sprite.self_modulate.a = progress
				if is_instance_valid(recovery_ghost):
					recovery_ghost.modulate.a = 1.0 - progress
				if progress >= 1.0:
					player.velocity = Vector2.ZERO
					player.move_and_slide()
					cancel()
					return
		if uses_beast():
			_pose()
		player.shadow.visible = landed
		Ferocity.update_airtime(delta, landed, false)
	aura.queue_redraw()
	queue_redraw()

func arm() -> void:
	if state not in [State.IDLE, State.CHARGING] or Ferocity.rank != 6:
		return
	Ferocity.reset()
	Ferocity.style_locked = true
	Ferocity.special_name = "Wrath of Nature"
	Ferocity.special_progress = 1.0
	state = State.READY
	elapsed = 0.0
	ready_left = ready_duration
	Sfx.stop_loop("wrath_charge")
	Sfx.play("wrath_ready")
	Fx.text(player.get_parent(), player.global_position + Vector2(0, -80), "WRATH OF NATURE", SSS_COLOR)
	Stats.add("wrath_charged")

func begin_aim() -> bool:
	if state != State.READY or player.execution_core != null:
		return false
	direction = Vector2(player.facing, 0)
	player._cancel_all_states()
	player._cancel_attack_for_chain()
	player._update_roar_aura()
	player.velocity = Vector2.ZERO
	player.knife_throw_pose_timer = 0.0
	state = State.AIM
	elapsed = 0.0
	landed = player.is_on_floor()
	var pose: StringName = player.ANIMATION_CROUCH if landed else player.ANIMATION_AERIAL_STALL
	player.animated_sprite.play(pose)
	player._align_character_animation(pose)
	Sfx.play("wrath_aim")
	return true

func launch(input_direction: Vector2) -> bool:
	if not is_ready() or input_direction.length_squared() < 0.01 or player.execution_core != null:
		return false
	direction = Vector2(signf(input_direction.x), signf(input_direction.y)).normalized()
	player._cancel_all_states()
	player._cancel_attack_for_chain()
	player._update_roar_aura()
	if player.knife_scrape.active:
		player.knife_scrape.end()
	player.knife_throw_pose_timer = 0.0
	player.animated_sprite.modulate = Color.WHITE
	player.charge_glow_material.set_shader_parameter("glow_amount", 0.0)
	player.velocity = direction * rush_speed
	player.facing = -1 if direction.x < -0.01 else (1 if direction.x > 0.01 else player.facing)
	player._update_facing_visual()
	state = State.RUSH
	elapsed = 0.0
	distance = 0.0
	landed = false
	afterimage_wait = 0.0
	trail_wait = 0.0
	captured.clear()
	_pose()
	Sfx.play("wrath_launch")
	Sfx.start_loop("wrath_rush")
	Stats.add("wrath_launched")
	return true

func _rush(delta: float) -> void:
	var from := player.global_position
	var remaining := minf(rush_speed * delta, maxf(max_distance - distance, 0.0))
	player.velocity = direction * rush_speed
	var collision := player.move_and_collide(direction * remaining)
	var to := player.global_position
	distance += from.distance_to(to)
	_capture_segment(from + Vector2(0, -42), to + Vector2(0, -42))
	Ferocity.special_progress = maxf(1.0 - distance / max_distance, 0.0)
	afterimage_wait -= delta
	if afterimage_wait <= 0.0:
		afterimage_wait = 0.035
		player.unstoppable_glow = true
		player.afterimage_unstoppable_material.set_shader_parameter("glow_color", SSS_COLOR)
		player._spawn_afterimage()
	trail_wait -= delta
	if trail_wait <= 0.0:
		trail_wait = 0.045
		Fx.jade_splash(player.get_parent(), to + Vector2(0, -42), -direction, 0.50, 0.65)
	if collision != null or distance >= max_distance - 0.1 or elapsed >= max_rush_duration:
		Sfx.stop_loop("wrath_rush")
		if collision != null:
			Fx.jade_burst(player.get_parent(), collision.get_position(), 1.3)
		landed = collision != null and collision.get_normal().y < -0.7
		recoil = (collision.get_normal() if collision != null else -direction) * 190.0
		state = State.RECOIL
		elapsed = 0.0
		Sfx.play("wrath_impact")
		player._camera_kick(0.55, 0.045)

func _blocked_on_ground(candidate: Vector2) -> bool:
	# Desde el suelo no se apunta hacia abajo (abajo-adelante, abajo, abajo-atrás) ni hacia atrás.
	return candidate.y > 0.01 or (absf(candidate.y) < 0.01 and signf(candidate.x) == -player.facing)

func _brake() -> void:
	# Heavy durante el avance: frena deslizándose hacia delante y ejecuta ahí lo capturado.
	Sfx.stop_loop("wrath_rush")
	Sfx.play("skid")
	Sfx.play("wrath_impact", -4.0, 0.85)
	Fx.jade_burst(player.get_parent(), player.global_position + Vector2(0, -42), 0.8)
	landed = player.test_move(player.global_transform, Vector2.DOWN * 4.0)
	recoil = direction * 260.0
	state = State.RECOIL
	elapsed = 0.0
	player._camera_kick(0.3, 0.03)

func _capture_segment(from: Vector2, to: Vector2) -> void:
	var shape := CapsuleShape2D.new()
	shape.radius = 38.0
	shape.height = from.distance_to(to) + 76.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D((to - from).angle() - PI * 0.5, from.lerp(to, 0.5))
	query.collision_mask = 8
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for hit in player.get_world_2d().direct_space_state.intersect_shape(query, 128):
		var enemy: Node2D = hit.collider
		var core: Node2D = enemy.get_node_or_null("RubyCore")
		if core == null or core in captured:
			continue
		var closest := Geometry2D.get_closest_point_to_segment(core.global_position, from, to)
		var ray := PhysicsRayQueryParameters2D.create(closest, core.global_position, 2)
		if not player.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		if core.claim_wrath(player):
			captured.append(core)
			Fx.impact(player.get_parent(), core.global_position, [JADE.darkened(0.7), JADE, Color(0.8, 1.0, 0.7)], 1.3)
			Sfx.play("wrath_hit", -2.0, 1.0 + minf(captured.size() * 0.025, 0.2), true)

func _shatter() -> void:
	var count := captured.size()
	var mouth := player.global_position + Vector2(0, -42) + direction * 60.0
	for core in captured:
		if is_instance_valid(core) and core.complete_wrath(player, mouth):
			player.heal(player.boss_execution_heal if core.boss else player.execution_heal)
	captured.clear()
	Fx.shatter(player.get_parent(), mouth, Color(1.0, 0.1, 0.18), 70.0)
	Sfx.play("wrath_shatter")
	Stats.add("wrath_rubies", count)
	recovery_ghost = Sprite2D.new()
	recovery_ghost.texture = player.animated_sprite.sprite_frames.get_frame_texture(player.animated_sprite.animation, player.animated_sprite.frame)
	recovery_ghost.transform = player.animated_sprite.transform
	recovery_ghost.flip_h = player.animated_sprite.flip_h
	recovery_ghost.material = player.charge_glow_material.duplicate()
	recovery_ghost.z_index = 2
	player.add_child(recovery_ghost)
	state = State.RECOVERY
	elapsed = 0.0
	player.velocity = Vector2.ZERO
	player.animated_sprite.rotation = 0.0
	player._update_character_animation()
	player.animated_sprite.self_modulate.a = 0.0

func _pose() -> void:
	var animation: StringName = player.ANIMATION_WRATH_RUSH if state == State.RUSH else player.ANIMATION_WRATH_CHEW
	player.animated_sprite.play(animation)
	player._align_character_animation(animation)
	player.animated_sprite.position = Vector2(0, -42)
	player.animated_sprite.rotation = direction.angle() - (PI if player.facing < 0 else 0.0)
	player.animated_sprite.flip_h = player.facing < 0
	player.mane_emitter.follow(player.animated_sprite, player.facing, true, SSS_COLOR)

func _destroy_projectiles() -> void:
	var center: Vector2 = player.global_position + Vector2(0, -42)
	for projectile in get_tree().get_nodes_in_group(&"projectiles"):
		if projectile.global_position.distance_to(center) <= 76.0:
			if projectile.has_method("_destroy"):
				projectile._destroy()
			else:
				projectile.queue_free()

func cancel() -> void:
	if state == State.RUSH:
		Sfx.stop_loop("wrath_rush")
	if state == State.CHARGING:
		Sfx.stop_loop("wrath_charge")
	for core in captured:
		if is_instance_valid(core):
			core.release_claim(player)
	captured.clear()
	if is_instance_valid(recovery_ghost):
		recovery_ghost.queue_free()
	recovery_ghost = null
	if is_instance_valid(player):
		player.animated_sprite.self_modulate.a = 1.0
		if controls_movement():
			player.animated_sprite.rotation = 0.0
			player.velocity = Vector2.ZERO
	if state not in [State.IDLE, State.CHARGING]:
		Ferocity.reset()
	Ferocity.drain_locked = false
	state = State.IDLE
	elapsed = 0.0
	ready_left = 0.0
	aura.queue_redraw()
	queue_redraw()

func _draw_aura() -> void:
	if state not in [State.CHARGING, State.READY, State.AIM]:
		return
	var strength := clampf(elapsed / charge_duration, 0.0, 1.0) if state == State.CHARGING else 1.0
	var points := PackedVector2Array([Vector2(-36, 0), Vector2(-45, -24), Vector2(-34, -18), Vector2(-47, -53), Vector2(-32, -43), Vector2(-34, -79), Vector2(-18, -62), Vector2(-10, -99), Vector2(0, -85), Vector2(15, -98), Vector2(18, -62), Vector2(37, -79), Vector2(30, -43), Vector2(46, -49), Vector2(37, -14), Vector2(43, -20), Vector2(34, 0), Vector2(-36, 0)])
	for i in range(1, points.size() - 2):
		points[i].y += sin(clock * 25.0 + i * 2.7) * 3.0
		points[i] *= 0.65 + 0.35 * strength
	aura.draw_colored_polygon(points, Color(0.95, 0.01, 0.04, 0.15 * strength))
	aura.draw_polyline(points, Color(1.0, 0.08, 0.16, 0.8 * strength), 1.8, true)

func _draw() -> void:
	if state == State.AIM:
		var center := Vector2(0, -42)
		var tip := center + direction * 72.0
		var base := tip - direction * 14.0
		draw_line(center + direction * 36.0, tip, SSS_COLOR, 3.0, true)
		draw_colored_polygon(PackedVector2Array([tip, base + direction.orthogonal() * 7.0, base - direction.orthogonal() * 7.0]), SSS_COLOR)
		draw_arc(center, 30.0, -PI * 0.5, -PI * 0.5 + TAU * maxf(1.0 - elapsed / aim_duration, 0.0), 32, SSS_COLOR, 2.0, true)
		return
	if not uses_beast():
		return
	for i in range(mini(captured.size(), 20)):
		var point := Vector2(0, -42) + direction * 58.0 + direction.orthogonal() * ((i % 5) - 2) * 4.0 - direction * (i / 5) * 7.0
		draw_colored_polygon(PackedVector2Array([point + Vector2(0, -4), point + Vector2(3, 0), point + Vector2(0, 4), point + Vector2(-3, 0)]), Color(1.0, 0.12, 0.22))
