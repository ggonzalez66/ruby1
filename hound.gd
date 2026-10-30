extends "res://chaser_dummy.gd"

# Sabueso: cuadrúpedo rápido que persigue a Viridy, salta a las plataformas y se le lanza encima. Si la
# alcanza la deja inmovilizada en el suelo (no quita vida) para que los demás le peguen; machacar el
# ligero la suelta. El salto se parrea con el rugido (lo deja aturdido y con el rubí abierto) y la guardia
# lo bloquea. Es débil pero muy móvil.

@export var pounce_range := 240.0
@export var pounce_speed_y := -380.0
@export var pounce_time := 0.42
@export var jump_speed := 760.0
@export var mash_count := 7
@export var pin_cooldown := 1.6

const HOUND_COLOR := Color(0.22, 0.24, 0.28)
const STRIPE_COLOR := Color(0.9, 0.18, 0.15)
const CONTACT_RADIUS := 34.0

var air_velocity := Vector2.ZERO
var airborne := false
var pinning := false
var cooldown := 0.0
var leap_hit_done := false

func _init() -> void:
	max_health = 6
	speed = 270.0
	detect_range = 720.0
	attack_range = pounce_range
	attack_damage = 0
	telegraph_time = 0.4
	recover_time = 0.7
	impact_offset = Vector2(0, -26)

func _build() -> void:
	body_color = HOUND_COLOR
	collision_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(56, 44)
	collision_shape.shape = rect
	collision_shape.position = Vector2(0, -22)
	add_child(collision_shape)

	visual = Node2D.new()
	add_child(visual)
	body_poly = _poly([Vector2(-26, -10), Vector2(18, -12), Vector2(30, -24), Vector2(36, -18), Vector2(24, -4), Vector2(-26, -4)], HOUND_COLOR)
	visual.add_child(body_poly)
	var legs := _poly([Vector2(-24, -6), Vector2(-20, 0), Vector2(-14, 0), Vector2(-16, -6), Vector2(12, -6), Vector2(16, 0), Vector2(22, 0), Vector2(18, -6)], HOUND_COLOR.darkened(0.3))
	visual.add_child(legs)
	var stripe := _poly([Vector2(-20, -10), Vector2(14, -11), Vector2(14, -8), Vector2(-20, -7)], STRIPE_COLOR)
	visual.add_child(stripe)
	ENEMY_SKIN.new().dress(visual, body_poly, "hound", [body_poly, legs, stripe])
	# El chaser anima "arm" (aquí, las fauces): queda como pivote invisible.
	arm = Node2D.new()
	arm.position = Vector2(30, -20)
	visual.add_child(arm)

	warning_label = Label.new()
	warning_label.text = "!"
	warning_label.add_theme_font_size_override("font_size", 24)
	warning_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
	warning_label.add_theme_color_override("font_outline_color", Color(0.1, 0.02, 0.02))
	warning_label.add_theme_constant_override("outline_size", 6)
	warning_label.position = Vector2(-5, -92)
	warning_label.visible = false
	add_child(warning_label)

	var bar := Node2D.new()
	bar.position = Vector2(0, -66)
	add_child(bar)
	bar.add_child(_poly([Vector2(-17, -4), Vector2(17, -4), Vector2(17, 4), Vector2(-17, 4)], Color(0.16, 0.15, 0.16, 0.8)))
	health_fill = _poly([], Color(0.95, 0.35, 0.3))
	bar.add_child(health_fill)

func reset_dummy() -> void:
	_drop_pin()
	airborne = false
	air_velocity = Vector2.ZERO
	cooldown = 0.0
	super.reset_dummy()

func holds_pin() -> bool:
	return pinning and state != State.DEAD and not (ruby_core != null and (ruby_core.dying or ruby_core.holds_actor()))

func on_pin_released(escaped: bool) -> void:
	pinning = false
	cooldown = pin_cooldown
	if state == State.DEAD:
		return
	# Al soltarse Viridy lo despide hacia atrás, aturdido.
	state = State.STAGGER
	state_timer = 1.1 if escaped else 0.5
	knock_velocity = -facing * (420.0 if escaped else 200.0)
	visual.rotation = 0.0

func _physics_process(delta: float) -> void:
	if ruby_core.holds_actor():
		return
	if state == State.DEAD:
		return
	flash_timer = max(flash_timer - delta, 0.0)
	state_timer -= delta
	cooldown = maxf(cooldown - delta, 0.0)
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if launched:
		_drop_pin()
		_update_launch(delta)
		return
	if pinning:
		_hold_pin(player)
		_update_look()
		return
	var grounded := false
	if airborne:
		grounded = _update_air(delta, player)
	else:
		grounded = _apply_gravity(delta)
	if state == State.DEAD:
		return
	if abs(knock_velocity) > 1.0:
		_move_horizontally(knock_velocity * delta, false)
		knock_velocity = move_toward(knock_velocity, 0.0, 900.0 * delta)

	match state:
		State.IDLE, State.CHASE:
			if player and _can_see(player) and grounded and not airborne:
				state = State.CHASE
				_face(player)
				var offset: Vector2 = player.global_position - global_position
				if cooldown <= 0.0 and absf(offset.x) <= pounce_range and absf(offset.y) < 70.0:
					_start_telegraph()
				elif offset.y < -70.0 and absf(offset.x) < 260.0 and _can_jump_up():
					_leap(Vector2(signf(offset.x) * 180.0, -jump_speed), false)
				else:
					_move_horizontally(signf(offset.x) * speed * delta, true)
			elif not airborne:
				state = State.IDLE
		State.TELEGRAPH:
			# Se agazapa para saltar.
			visual.scale.y = lerpf(visual.scale.y, 0.8, 12.0 * delta)
			if state_timer <= 0.0:
				warning_label.visible = false
				visual.scale.y = 1.0
				if player == null:
					state = State.RECOVER
					state_timer = recover_time
				else:
					_face(player)
					var dx: float = player.global_position.x - global_position.x
					# Cae un poco más allá de donde está Viridy.
					_leap(Vector2((dx + facing * 30.0) / pounce_time, pounce_speed_y), true)
					Sfx.play("enemy_swing", 2.0, 0.7)
		State.SWING:
			if not airborne:
				state = State.RECOVER
				state_timer = recover_time
		State.RECOVER, State.STAGGER:
			visual.rotation = lerp(visual.rotation, 0.0, 6.0 * delta)
			if state_timer <= 0.0 and not airborne:
				state = State.IDLE
	_update_look()

func _update_look() -> void:
	var blink: bool = state == State.TELEGRAPH and int(state_timer * 20.0) % 2 == 0
	body_poly.color = BODY_HIT_COLOR if flash_timer > 0.0 else (WARNING_COLOR if blink else body_color)
	if airborne:
		visual.rotation = clampf(air_velocity.y / 1400.0, -0.45, 0.45) * facing

func _can_jump_up() -> bool:
	var space := get_world_2d().direct_space_state
	var ceiling := space.intersect_ray(PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -34), global_position + Vector2(0, -120), 2))
	return ceiling.is_empty()

func _leap(initial: Vector2, pounce: bool) -> void:
	air_velocity = initial
	airborne = true
	leap_hit_done = not pounce
	fall_velocity = 0.0
	fall_distance = 0.0
	if pounce:
		state = State.SWING
		swing_hit_done = false
	global_position.y -= 2.0

func _update_air(delta: float, player: Node2D) -> bool:
	var from := global_position
	air_velocity.y = minf(air_velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	var space := get_world_2d().direct_space_state
	var step := air_velocity * delta
	# Pared delante: corta el avance horizontal.
	if step.x != 0.0 and not space.intersect_ray(PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -16), global_position + Vector2(signf(step.x) * 28.0 + step.x, -16), 2)).is_empty():
		step.x = 0.0
		air_velocity.x = 0.0
	if step.y < 0.0 and not space.intersect_ray(PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -32), global_position + Vector2(0, -34 + step.y), 2)).is_empty():
		step.y = 0.0
		air_velocity.y = 0.0
	global_position.x += step.x
	if step.y < 0.0:
		global_position.y += step.y
	else:
		var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -4), global_position + Vector2(0, step.y + 2.0), 2))
		if not hit.is_empty():
			global_position.y = hit.position.y
			airborne = false
			air_velocity = Vector2.ZERO
			fall_distance = 0.0
			visual.rotation = 0.0
			Fx.dust(get_parent(), global_position, Vector2.UP, 3, 0.8)
			return true
		global_position.y += step.y
	if global_position.y - from.y > 0.0:
		fall_distance += global_position.y - from.y
	if fall_distance > 3000.0:
		_die()
	if state == State.SWING and not leap_hit_done:
		_check_pounce(player, from, global_position)
	return false

func _check_pounce(player: Node2D, from: Vector2, to: Vector2) -> void:
	if player == null or player.current_health <= 0:
		return
	var center: Vector2 = player.global_position + Vector2(0, -22)
	var reach: bool = Geometry2D.get_closest_point_to_segment(center, from + Vector2(0, -16), to + Vector2(0, -16)).distance_to(center) <= CONTACT_RADIUS
	var aura: bool = player.has_method("parry_reaches") and player.parry_reaches(from + Vector2(0, -16), to + Vector2(facing * 30.0, -16))
	if not (reach or aura):
		return
	leap_hit_done = true
	if player.roar_active:
		# Rugido: el parry lo desvía (on_deflected) y la guardia lo bloquea; en ningún caso inmoviliza.
		player.take_damage(0, global_position + Vector2(0, -16), self)
		if state == State.SWING:
			air_velocity = Vector2(-facing * 220.0, -200.0)
		return
	if player.pin(self, mash_count):
		pinning = true
		airborne = false
		air_velocity = Vector2.ZERO
		Sfx.play("enemy_swing", 0.0, 0.5)
		Fx.dust(get_parent(), player.global_position, Vector2.UP, 6, 1.2, 1.5)

func on_deflected(by: Node) -> void:
	if state != State.SWING:
		return
	super.on_deflected(by)
	air_velocity = Vector2(-facing * 260.0, -240.0)

func _hold_pin(player: Node2D) -> void:
	if player == null or not player.has_method("is_pinned") or not player.is_pinned():
		on_pin_released(false)
		return
	# Encima de Viridy, mordiendo.
	global_position = player.global_position + Vector2(-facing * 6.0, -10.0)
	visual.rotation = sin(Time.get_ticks_msec() * 0.03) * 0.12 * facing

func _drop_pin() -> void:
	if not pinning:
		return
	pinning = false
	var player := get_tree().get_first_node_in_group(&"player") if is_inside_tree() else null
	if player != null and player.has_method("is_pinned") and player.pinned_by == self:
		player.release_pin(false)

func take_hit(source_position: Vector2, direction: int = 1, damage: int = 1) -> void:
	if pinning:
		_drop_pin()
	super.take_hit(source_position, direction, damage)

func _die() -> void:
	_drop_pin()
	airborne = false
	super._die()

func on_stagger() -> void:
	_drop_pin()
	super.on_stagger()
