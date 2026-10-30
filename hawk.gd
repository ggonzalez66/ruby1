extends Area2D

const RUBY_CORE_SCRIPT := preload("res://ruby_core.gd")
const FLIGHT_MOTION := preload("res://enemy_launch_motion.gd")
var ruby_core: Node2D

# Halcón: vuela libre patrullando de un lado a otro. Si ve a Viridy debajo, chilla (aviso agudo, "!"),
# se queda planeando unos segundos y se lanza en picada en línea recta hacia donde estaba; luego vuelve a
# subir a su altura. Golpearlo mientras avisa o en plena picada lo aturde; el rugido desvía la picada.
# Si la picada choca con una plataforma o el suelo, se queda aturdido un momento antes de subir.

@export var max_health := 5
@export var patrol_width := 320.0
@export var patrol_speed := 150.0
@export var detect_range := 560.0
@export var detect_depth := 920.0
@export var watch_time := 1.5
@export var dive_speed := 980.0
@export var dive_overshoot := 70.0
@export var dive_damage := 12
@export var climb_speed := 430.0
@export var cooldown_time := 1.8

const BODY_COLOR := Color(0.47, 0.3, 0.18)
const WING_COLOR := Color(0.36, 0.22, 0.13)
const BELLY_COLOR := Color(0.86, 0.78, 0.62)
const BEAK_COLOR := Color(0.98, 0.78, 0.25)
const HIT_COLOR := Color(1.0, 0.55, 0.45)
const WARNING_COLOR := Color(1.0, 0.9, 0.5)
const CONTACT_RADIUS := 30.0

enum State { PATROL, WATCH, DIVE, CLIMB, STAGGER, DEAD }

var impact_offset := Vector2.ZERO
var state := State.PATROL
var state_timer := 0.0
var current_health := 0
var facing := 1
var patrol_direction := 1.0
var home := Vector2.ZERO
var spawn_position := Vector2.ZERO
var flight_time := 0.0
var cooldown := 0.0
var flash_timer := 0.0
var knock_velocity := 0.0
var dive_direction := Vector2.ZERO
var dive_left := 0.0
var dive_hit_done := false
# Se estrelló contra el suelo: el aturdimiento no lo hunde más.
var crashed := false
# Lanzado por un uppercut: sube hasta el punto, flota y vuelve a volar.
var launched := false
var launch_elapsed := 0.0
var launch_from := Vector2.ZERO
var launch_target := Vector2.ZERO
var launch_rise := 0.0
var launch_hang := 0.0

const ENEMY_SKIN := preload("res://enemy_skin.gd")
var visual: Node2D
var body_poly: Polygon2D
var wing_front: Polygon2D
var wing_back: Polygon2D
var warning_label: Label
var health_fill: Polygon2D
var collision_shape: CollisionShape2D

func _ready() -> void:
	add_to_group(&"training_dummies")
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	spawn_position = position
	_build()
	reset_dummy()
	ruby_core = RUBY_CORE_SCRIPT.new()
	ruby_core.name = "RubyCore"
	add_child(ruby_core)

func _build() -> void:
	collision_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 24.0
	collision_shape.shape = circle
	add_child(collision_shape)

	visual = Node2D.new()
	add_child(visual)
	# Mira hacia +x: ala trasera, cola, cuerpo, vientre, cabeza con pico y el ala delantera encima.
	wing_back = _poly([Vector2(-4, -2), Vector2(-30, -26), Vector2(-10, -24), Vector2(8, -4)], WING_COLOR.darkened(0.25))
	wing_back.position = Vector2(2, -4)
	visual.add_child(wing_back)
	var tail := _poly([Vector2(-14, -4), Vector2(-34, -10), Vector2(-36, 2), Vector2(-14, 4)], WING_COLOR)
	visual.add_child(tail)
	body_poly = _poly([Vector2(-16, -6), Vector2(4, -10), Vector2(16, -6), Vector2(14, 6), Vector2(-14, 6)], BODY_COLOR)
	visual.add_child(body_poly)
	var details := [
		_poly([Vector2(-8, 2), Vector2(10, 0), Vector2(8, 6), Vector2(-8, 6)], BELLY_COLOR),
		_poly([Vector2(10, -12), Vector2(20, -12), Vector2(22, -4), Vector2(12, -2)], BODY_COLOR.lightened(0.1)),
		_poly([Vector2(21, -10), Vector2(30, -6), Vector2(22, -4)], BEAK_COLOR),
		_poly([Vector2(16, -10), Vector2(19, -10), Vector2(19, -7), Vector2(16, -7)], Color(0.1, 0.06, 0.04)),
	]
	for piece in details:
		visual.add_child(piece)
	wing_front = _poly([Vector2(-6, 0), Vector2(-26, -30), Vector2(-4, -28), Vector2(10, -2)], WING_COLOR)
	wing_front.position = Vector2(0, -2)
	visual.add_child(wing_front)
	# El sprite trae las alas abiertas: sustituye cuerpo y alas, y late con el aleteo.
	ENEMY_SKIN.new().dress(visual, body_poly, "hawk", [wing_back, tail, body_poly, wing_front] + details, wing_front, 22.0)

	warning_label = Label.new()
	warning_label.text = "!"
	warning_label.add_theme_font_size_override("font_size", 24)
	warning_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	warning_label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02))
	warning_label.add_theme_constant_override("outline_size", 6)
	warning_label.position = Vector2(-5, -80)
	warning_label.visible = false
	add_child(warning_label)

	var bar := Node2D.new()
	bar.position = Vector2(0, -46)
	add_child(bar)
	bar.add_child(_poly([Vector2(-17, -4), Vector2(17, -4), Vector2(17, 4), Vector2(-17, 4)], Color(0.16, 0.15, 0.16, 0.8)))
	health_fill = _poly([], Color(0.95, 0.35, 0.3))
	bar.add_child(health_fill)

func reset_dummy() -> void:
	if is_instance_valid(ruby_core):
		ruby_core.reset_core()
	position = spawn_position
	home = spawn_position
	current_health = max_health
	state = State.PATROL
	state_timer = 0.0
	cooldown = 0.0
	flash_timer = 0.0
	knock_velocity = 0.0
	launched = false
	flight_time = 0.0
	visible = true
	visual.rotation = 0.0
	warning_label.visible = false
	set_deferred("monitorable", true)
	collision_shape.set_deferred("disabled", false)
	_update_health_bar()

func _physics_process(delta: float) -> void:
	if ruby_core.holds_actor():
		return
	if state == State.DEAD:
		return
	flight_time += delta
	flash_timer = max(flash_timer - delta, 0.0)
	cooldown = max(cooldown - delta, 0.0)
	state_timer -= delta
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if abs(knock_velocity) > 1.0:
		if FLIGHT_MOTION.move_to(self, collision_shape, global_position + Vector2(knock_velocity * delta, 0)):
			knock_velocity = 0.0
		knock_velocity = move_toward(knock_velocity, 0.0, 900.0 * delta)
	if launched:
		_update_launch(delta)
		_update_visual(delta)
		return

	match state:
		State.PATROL:
			var target_x: float = home.x + patrol_direction * patrol_width
			if abs(target_x - global_position.x) < 6.0:
				patrol_direction = -patrol_direction
			if FLIGHT_MOTION.move_to(self, collision_shape, Vector2(move_toward(global_position.x, target_x, patrol_speed * delta), global_position.y)):
				patrol_direction = -patrol_direction
			FLIGHT_MOTION.move_to(self, collision_shape, Vector2(global_position.x, lerpf(global_position.y, home.y + sin(flight_time * 2.2) * 12.0, minf(3.0 * delta, 1.0))))
			facing = 1 if target_x >= global_position.x else -1
			if cooldown <= 0.0 and player and _can_see(player):
				_start_watch(player)
		State.WATCH:
			# Planea en el sitio mirando a Viridy, con el aviso, antes de lanzarse.
			_face(player)
			FLIGHT_MOTION.move_to(self, collision_shape, Vector2(global_position.x, lerpf(global_position.y, home.y - 18.0 + sin(flight_time * 9.0) * 4.0, minf(4.0 * delta, 1.0))))
			if state_timer <= 0.0:
				_start_dive(player)
		State.DIVE:
			_update_dive(delta, player)
		State.CLIMB:
			var goal := Vector2(global_position.x + facing * 120.0, home.y)
			var destination := global_position.move_toward(goal, climb_speed * delta)
			# Subir junto a una pared debe deslizar el cuerpo, sin atravesarla ni bloquear la subida.
			FLIGHT_MOTION.move_to(self, collision_shape, Vector2(global_position.x, destination.y))
			FLIGHT_MOTION.move_to(self, collision_shape, Vector2(destination.x, global_position.y))
			if global_position.y <= home.y + 4.0:
				state = State.PATROL
				cooldown = cooldown_time
		State.STAGGER:
			FLIGHT_MOTION.move_to(self, collision_shape, global_position + Vector2(0, (-30.0 if crashed else 60.0) * delta))
			if state_timer <= 0.0:
				state = State.CLIMB
	_update_visual(delta)

func _can_see(player: Node2D) -> bool:
	if player.current_health <= 0:
		return false
	var offset := player.global_position - global_position
	if abs(offset.x) >= detect_range or offset.y <= 40.0 or offset.y >= detect_depth:
		return false
	return get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, player.global_position + Vector2(0, -18), 2)).is_empty()

func _face(player: Node2D) -> void:
	if player:
		facing = 1 if player.global_position.x >= global_position.x else -1

func _start_watch(player: Node2D) -> void:
	state = State.WATCH
	state_timer = watch_time
	warning_label.visible = true
	_face(player)
	Sfx.play("hawk_screech")

func _start_dive(player: Node2D) -> void:
	warning_label.visible = false
	if player == null or player.current_health <= 0:
		state = State.CLIMB
		return
	# En línea recta hacia donde está Viridy al lanzarse (un poco más allá).
	var target: Vector2 = player.global_position + Vector2(0, -18)
	var offset: Vector2 = target - global_position
	dive_direction = offset.normalized() if offset.length() > 1.0 else Vector2.DOWN
	dive_left = offset.length() + dive_overshoot
	dive_hit_done = false
	crashed = false
	facing = 1 if dive_direction.x >= 0.0 else -1
	state = State.DIVE
	Sfx.play("hawk_dive")

func _update_dive(delta: float, player: Node2D) -> void:
	var step: float = min(dive_speed * delta, dive_left)
	var from := global_position
	var to: Vector2 = from + dive_direction * step
	var blocked := FLIGHT_MOTION.move_to(self, collision_shape, to)
	to = global_position
	dive_left -= step
	_check_dive_hit(player, from, to)
	if blocked:
		# Se estrella: polvo y aturdido un momento.
		Fx.puff(get_parent(), to + dive_direction * 24.0, Color(0.8, 0.7, 0.55, 0.9))
		state = State.STAGGER
		state_timer = 0.7
		crashed = true
		return
	if dive_left <= 0.0:
		state = State.CLIMB

func _check_dive_hit(player: Node2D, from: Vector2, to: Vector2) -> void:
	if dive_hit_done or player == null or state != State.DIVE:
		return
	var center: Vector2 = player.global_position + Vector2(0, -18)
	if not get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(to, center, 2)).is_empty():
		return
	var touches: bool = Geometry2D.get_closest_point_to_segment(center, from, to).distance_to(center) <= CONTACT_RADIUS
	var aura: bool = player.has_method("parry_reaches") and player.parry_reaches(from, to + dive_direction * 24.0)
	if touches or aura:
		dive_hit_done = true
		player.take_damage(dive_damage, global_position, self)

func launch_to(point: Vector2, rise_time: float, hang_time: float) -> void:
	if ruby_core != null and ruby_core.locked:
		return
	if state == State.DEAD:
		return
	launched = true
	crashed = false
	launch_elapsed = 0.0
	launch_from = global_position
	launch_target = point
	launch_rise = max(rise_time, 0.01)
	launch_hang = hang_time
	warning_label.visible = false
	state = State.STAGGER
	state_timer = 0.0

func _update_launch(delta: float) -> void:
	launch_elapsed += delta
	var t: float = clamp(launch_elapsed / launch_rise, 0.0, 1.0)
	if FLIGHT_MOTION.move_to(self, collision_shape, launch_from.lerp(launch_target, ease(t, 0.4))):
		launch_target = global_position
		launch_from = global_position
		launch_elapsed = maxf(launch_elapsed, launch_rise)
	if launch_elapsed >= launch_rise + launch_hang:
		launched = false
		state = State.STAGGER
		state_timer = 0.3

func take_hit(_source_position: Vector2, direction: int = 1, damage: int = 1) -> void:
	if ruby_core != null and ruby_core.locked:
		return
	if ruby_core != null and ruby_core.dying:
		flash_timer = 0.1
		ruby_core.hit_while_dying()
		return
	if state == State.DEAD:
		return
	current_health = max(current_health - max(damage, 0), 0)
	flash_timer = 0.1
	knock_velocity = direction * 180.0
	_update_health_bar()
	if current_health == 0:
		ruby_core.enter_dying()
		return
	Sfx.play("enemy_hurt", 0.0, 1.35)
	# Golpearlo mientras avisa o en plena picada lo saca de su ataque.
	if state in [State.WATCH, State.DIVE]:
		state = State.STAGGER
		state_timer = 0.5
		warning_label.visible = false

func on_shine_hit(direction: int, strength: float) -> void:
	if ruby_core != null and ruby_core.locked:
		return
	if state == State.DEAD:
		return
	knock_velocity = direction * strength
	flash_timer = 0.1

func on_deflected(_by: Node) -> void:
	# El rugido desvía la picada: sale rebotado hacia arriba, aturdido.
	if state != State.DIVE:
		return
	ruby_core.register_parry()
	dive_hit_done = true
	state = State.STAGGER
	state_timer = 2.0
	FLIGHT_MOTION.move_to(self, collision_shape, global_position - dive_direction * 30.0)
	Fx.deflect(get_parent(), global_position)

func pull_towards(point: Vector2, strength: float) -> void:
	if ruby_core != null and ruby_core.locked:
		return
	knock_velocity = sign(point.x - global_position.x) * strength * 5.0

func _die() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	Stats.add("dummies_killed")
	Sfx.play("enemy_die")
	Fx.puff(get_parent(), global_position, Color(0.55, 0.38, 0.24, 0.9))
	visible = false
	warning_label.visible = false
	set_deferred("monitorable", false)
	collision_shape.set_deferred("disabled", true)

func _update_visual(delta: float) -> void:
	visual.scale = Vector2(facing * 1.35, 1.35)
	var flap_speed: float = 9.0
	var target_rotation := 0.0
	match state:
		State.WATCH:
			flap_speed = 20.0
		State.DIVE:
			flap_speed = 0.0
			# Alas recogidas y el cuerpo apuntando a la picada.
			target_rotation = Vector2(dive_direction.x * facing, dive_direction.y).angle()
		State.STAGGER:
			flap_speed = 4.0
			target_rotation = sin(flight_time * 18.0) * 0.5
		State.CLIMB:
			flap_speed = 14.0
			target_rotation = -0.35
	if flap_speed > 0.0:
		var flap: float = sin(flight_time * flap_speed)
		wing_front.rotation = flap * 0.55
		wing_back.rotation = flap * 0.45
		wing_front.scale.y = 1.0
		wing_back.scale.y = 1.0
	else:
		wing_front.rotation = lerp(wing_front.rotation, 1.1, 12.0 * delta)
		wing_back.rotation = lerp(wing_back.rotation, 1.0, 12.0 * delta)
	visual.rotation = lerp_angle(visual.rotation, target_rotation, 14.0 * delta)
	var blink: bool = state == State.WATCH and int(state_timer * 14.0) % 2 == 0
	body_poly.color = HIT_COLOR if flash_timer > 0.0 else (WARNING_COLOR if blink else BODY_COLOR)

func _update_health_bar() -> void:
	var ratio: float = float(current_health) / float(max(max_health, 1))
	var right: float = -16.0 + 32.0 * ratio
	health_fill.polygon = PackedVector2Array([Vector2(-16, -3), Vector2(right, -3), Vector2(right, 3), Vector2(-16, 3)])
	health_fill.visible = current_health > 0

func _poly(points: Array, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array(points)
	poly.color = color
	return poly

func on_stagger() -> void:
	if state == State.DEAD:
		return
	state = State.STAGGER
	state_timer = 0.0
	warning_label.hide()
