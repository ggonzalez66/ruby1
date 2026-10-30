extends "res://chaser_dummy.gd"

# Fusilero: robot bípedo con un cañón largo. Guarda distancia (se acerca o retrocede por su plataforma),
# apunta con un láser de aviso, fija la mira un instante y suelta una ráfaga de tres disparos; luego
# recarga. Dispara en cualquier ángulo, así que funciona igual desde una plataforma alta. Los disparos se
# devuelven con el rugido.

@export var preferred_distance := 380.0
@export var aim_time := 0.8
@export var lock_time := 0.22
@export var burst := 3
@export var burst_gap := 0.12
@export var bullet_speed := 720.0
@export var bullet_damage := 8
@export var reload_time := 1.5
@export var shoot_range := 760.0

const PROJECTILE_SCRIPT := preload("res://projectile.gd")
const ARMOR := Color(0.28, 0.3, 0.33)
const LASER := Color(1.0, 0.15, 0.15)
const MUZZLE := Vector2(34, -38)

var aim_direction := Vector2.RIGHT
var shots_left := 0
var shot_timer := 0.0
var laser: Line2D
var gun: Node2D

func _init() -> void:
	max_health = 8
	speed = 95.0
	detect_range = shoot_range
	attack_damage = 0
	telegraph_time = aim_time
	recover_time = reload_time
	impact_offset = Vector2(0, -30)

func _build() -> void:
	body_color = ARMOR
	collision_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, 58)
	collision_shape.shape = rect
	collision_shape.position = Vector2(0, -29)
	add_child(collision_shape)

	visual = Node2D.new()
	add_child(visual)
	body_poly = _poly([Vector2(-13, 0), Vector2(13, 0), Vector2(12, -56), Vector2(-12, -56)], ARMOR)
	visual.add_child(body_poly)
	var visor := _poly([Vector2(2, -52), Vector2(12, -52), Vector2(12, -48), Vector2(2, -48)], LASER)
	visual.add_child(visor)
	ENEMY_SKIN.new().dress(visual, body_poly, "rifleman", [body_poly, visor])
	# Pivote del cañón (el sprite ya lo trae dibujado): sirve para orientar el láser y la boca.
	gun = Node2D.new()
	gun.position = Vector2(6, -38)
	visual.add_child(gun)
	arm = gun
	laser = Line2D.new()
	laser.width = 2.0
	laser.default_color = Color(LASER, 0.0)
	laser.top_level = true
	laser.z_index = 4
	add_child(laser)

	warning_label = Label.new()
	warning_label.text = "!"
	warning_label.add_theme_font_size_override("font_size", 24)
	warning_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
	warning_label.add_theme_color_override("font_outline_color", Color(0.1, 0.02, 0.02))
	warning_label.add_theme_constant_override("outline_size", 6)
	warning_label.position = Vector2(-5, -100)
	warning_label.visible = false
	add_child(warning_label)

	var bar := Node2D.new()
	bar.position = Vector2(0, -70)
	add_child(bar)
	bar.add_child(_poly([Vector2(-17, -4), Vector2(17, -4), Vector2(17, 4), Vector2(-17, 4)], Color(0.16, 0.15, 0.16, 0.8)))
	health_fill = _poly([], Color(0.95, 0.35, 0.3))
	bar.add_child(health_fill)

func reset_dummy() -> void:
	shots_left = 0
	if laser != null:
		laser.default_color.a = 0.0
	super.reset_dummy()

func _physics_process(delta: float) -> void:
	if ruby_core.holds_actor() or state == State.DEAD:
		laser.default_color.a = 0.0
		return
	flash_timer = max(flash_timer - delta, 0.0)
	state_timer -= delta
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if launched:
		laser.default_color.a = 0.0
		_update_launch(delta)
		return
	var grounded := _apply_gravity(delta)
	if state == State.DEAD:
		return
	if abs(knock_velocity) > 1.0:
		_move_horizontally(knock_velocity * delta, false)
		knock_velocity = move_toward(knock_velocity, 0.0, 900.0 * delta)
	match state:
		State.IDLE, State.CHASE:
			laser.default_color.a = 0.0
			if player and grounded and _sees(player):
				state = State.CHASE
				_face(player)
				var dx: float = player.global_position.x - global_position.x
				var distance: float = player.global_position.distance_to(global_position)
				if distance <= shoot_range:
					_start_telegraph()
				# Mantiene la distancia: se acerca si está lejos y retrocede si Viridy se le echa encima.
				if absf(dx) > preferred_distance + 60.0:
					_move_horizontally(signf(dx) * speed * delta, true)
				elif absf(dx) < preferred_distance - 160.0:
					_move_horizontally(-signf(dx) * speed * 0.8 * delta, true)
			else:
				state = State.IDLE
		State.TELEGRAPH:
			# Apunta siguiendo a Viridy y fija la mira justo antes de disparar.
			if player and state_timer > lock_time:
				_face(player)
				aim_direction = (player.global_position + Vector2(0, -24) - _muzzle()).normalized()
			var locked: bool = state_timer <= lock_time
			_draw_laser(1.0 if locked else 0.45 + 0.25 * sin(state_timer * 40.0), 3.0 if locked else 1.5)
			if state_timer <= 0.0:
				warning_label.visible = false
				state = State.SWING
				shots_left = burst
				shot_timer = 0.0
		State.SWING:
			_draw_laser(0.3, 1.0)
			shot_timer -= delta
			if shot_timer <= 0.0 and shots_left > 0:
				_fire()
				shots_left -= 1
				shot_timer = burst_gap
			if shots_left <= 0 and shot_timer <= 0.0:
				state = State.RECOVER
				state_timer = reload_time
				laser.default_color.a = 0.0
		State.RECOVER, State.STAGGER:
			laser.default_color.a = 0.0
			visual.rotation = lerp(visual.rotation, 0.0, 6.0 * delta)
			if state_timer <= 0.0:
				state = State.IDLE
	gun.rotation = Vector2(aim_direction.x * facing, aim_direction.y).angle()
	var blink: bool = state == State.TELEGRAPH and int(state_timer * 20.0) % 2 == 0
	body_poly.color = BODY_HIT_COLOR if flash_timer > 0.0 else (WARNING_COLOR if blink else body_color)

func _sees(player: Node2D) -> bool:
	if player.current_health <= 0:
		return false
	var offset := player.global_position - global_position
	var alerted: bool = Time.get_ticks_msec() < alert_until_msec
	if offset.length() > shoot_range * (1.6 if alerted else 1.0):
		return false
	var space := get_world_2d().direct_space_state
	return space.intersect_ray(PhysicsRayQueryParameters2D.create(_muzzle(), player.global_position + Vector2(0, -24), 2)).is_empty()

func _muzzle() -> Vector2:
	return global_position + Vector2(MUZZLE.x * facing, MUZZLE.y)

func _draw_laser(alpha: float, width: float) -> void:
	var from := _muzzle()
	var to := from + aim_direction * shoot_range
	var hit := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(from, to, 2))
	if not hit.is_empty():
		to = hit.position
	laser.points = PackedVector2Array([from, to])
	laser.width = width
	laser.default_color = Color(LASER, alpha)

func _start_telegraph() -> void:
	Sfx.play("enemy_charge")
	state = State.TELEGRAPH
	state_timer = aim_time
	warning_label.visible = true

func _fire() -> void:
	var shot: Area2D = PROJECTILE_SCRIPT.new()
	shot.velocity = aim_direction * bullet_speed
	shot.damage = bullet_damage
	shot.shooter = self
	get_parent().add_child(shot)
	shot.global_position = _muzzle()
	Sfx.play("enemy_shoot", 0.0, 1.3)
	Fx.puff(get_parent(), _muzzle(), Color(1.0, 0.6, 0.3, 0.8))
	knock_velocity = -facing * 60.0

func take_hit(source_position: Vector2, direction: int = 1, damage: int = 1) -> void:
	var aiming := state == State.TELEGRAPH
	super.take_hit(source_position, direction, damage)
	if aiming and state != State.TELEGRAPH:
		laser.default_color.a = 0.0

func on_deflected(_by: Node) -> void:
	# Un disparo devuelto en un parry perfecto lo aturde.
	ruby_core.register_parry()
	state = State.STAGGER
	state_timer = 1.4
	shots_left = 0
	laser.default_color.a = 0.0

func _die() -> void:
	laser.default_color.a = 0.0
	super._die()
