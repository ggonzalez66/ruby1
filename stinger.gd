extends "res://hawk.gd"

# Aguijón: dron pequeño que vuela en enjambre alrededor de Viridy. Orbita a su alrededor, se fija (se
# queda quieto con una línea roja de aviso) y embiste en línea recta; luego vuelve a orbitar. Golpearlo
# mientras se fija o embiste lo aturde y el rugido desvía la embestida (heredado del halcón).

@export var orbit_radius := 160.0
@export var orbit_speed := 1.6
@export var approach_speed := 300.0
@export var lock_time := 0.5

const SHELL := Color(0.25, 0.27, 0.3)
const EYE := Color(1.0, 0.15, 0.12)

var orbit_angle := 0.0
var orbit_wait := 0.0
var aim_line: Line2D

func _init() -> void:
	max_health = 3
	dive_speed = 820.0
	dive_overshoot = 90.0
	dive_damage = 8
	watch_time = lock_time
	cooldown_time = 0.6
	detect_range = 720.0

func _build() -> void:
	collision_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 15.0
	collision_shape.shape = circle
	add_child(collision_shape)
	visual = Node2D.new()
	add_child(visual)
	# Las alas del halcón: aquí dos cuchillas que giran (el sprite las trae, quedan como pivotes ocultos).
	wing_back = _poly([Vector2(-2, 0), Vector2(-16, -12), Vector2(-4, -10)], SHELL.darkened(0.3))
	visual.add_child(wing_back)
	body_poly = _poly([Vector2(-11, -6), Vector2(0, -12), Vector2(11, -6), Vector2(11, 6), Vector2(0, 12), Vector2(-11, 6)], SHELL)
	visual.add_child(body_poly)
	var eye := _poly([Vector2(-3, -3), Vector2(3, -3), Vector2(3, 3), Vector2(-3, 3)], EYE)
	visual.add_child(eye)
	wing_front = _poly([Vector2(2, 0), Vector2(16, -12), Vector2(4, -10)], SHELL.darkened(0.2))
	visual.add_child(wing_front)
	ENEMY_SKIN.new().dress(visual, body_poly, "stinger", [wing_back, body_poly, eye, wing_front], null, 16.0)
	aim_line = Line2D.new()
	aim_line.width = 2.0
	aim_line.default_color = Color(EYE, 0.0)
	aim_line.top_level = true
	add_child(aim_line)

	warning_label = Label.new()
	warning_label.text = "!"
	warning_label.add_theme_font_size_override("font_size", 20)
	warning_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.25))
	warning_label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02))
	warning_label.add_theme_constant_override("outline_size", 6)
	warning_label.position = Vector2(-5, -52)
	warning_label.visible = false
	add_child(warning_label)

	var bar := Node2D.new()
	bar.position = Vector2(0, -28)
	add_child(bar)
	bar.add_child(_poly([Vector2(-17, -4), Vector2(17, -4), Vector2(17, 4), Vector2(-17, 4)], Color(0.16, 0.15, 0.16, 0.8)))
	health_fill = _poly([], Color(0.95, 0.35, 0.3))
	bar.add_child(health_fill)

func reset_dummy() -> void:
	super.reset_dummy()
	# Cada dron del enjambre arranca en otro punto de la órbita y con otro ritmo.
	orbit_angle = randf() * TAU
	orbit_wait = randf_range(1.2, 2.6)

func _physics_process(delta: float) -> void:
	if ruby_core.holds_actor() or state == State.DEAD:
		aim_line.default_color.a = 0.0
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
		aim_line.default_color.a = 0.0
		_update_launch(delta)
		_update_visual(delta)
		return
	aim_line.default_color.a = 0.0
	match state:
		State.PATROL, State.CLIMB:
			if player and _can_see(player):
				# Orbita alrededor de Viridy, a la altura de su pecho.
				orbit_angle += orbit_speed * delta
				var goal: Vector2 = player.global_position + Vector2(0, -40) + Vector2(cos(orbit_angle), sin(orbit_angle) * 0.55) * orbit_radius
				var destination := global_position.move_toward(goal, approach_speed * delta)
				FLIGHT_MOTION.move_to(self, collision_shape, Vector2(destination.x, global_position.y))
				FLIGHT_MOTION.move_to(self, collision_shape, Vector2(global_position.x, destination.y))
				_face(player)
				orbit_wait -= delta
				if orbit_wait <= 0.0 and cooldown <= 0.0 and global_position.distance_to(goal) < 60.0:
					orbit_wait = randf_range(1.4, 2.8)
					_start_watch(player)
			else:
				# Sin verla, flota en su sitio.
				FLIGHT_MOTION.move_to(self, collision_shape, Vector2(global_position.x, lerpf(global_position.y, home.y + sin(flight_time * 3.0) * 8.0, minf(3.0 * delta, 1.0))))
		State.WATCH:
			_face(player)
			if player:
				var target: Vector2 = player.global_position + Vector2(0, -18)
				aim_line.points = PackedVector2Array([global_position, target])
				aim_line.default_color = Color(EYE, 0.35 + 0.35 * sin(state_timer * 50.0))
			if state_timer <= 0.0:
				_start_dive(player)
		State.DIVE:
			_update_dive(delta, player)
		State.STAGGER:
			FLIGHT_MOTION.move_to(self, collision_shape, global_position + Vector2(0, (-20.0 if crashed else 40.0) * delta))
			if state_timer <= 0.0:
				state = State.CLIMB
	_update_visual(delta)

func _can_see(player: Node2D) -> bool:
	if player.current_health <= 0:
		return false
	if player.global_position.distance_to(global_position) > detect_range:
		return false
	return get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, player.global_position + Vector2(0, -18), 2)).is_empty()

func _start_watch(player: Node2D) -> void:
	state = State.WATCH
	state_timer = watch_time
	warning_label.visible = true
	_face(player)
	Sfx.play("zap", -4.0, 1.6)

func _start_dive(player: Node2D) -> void:
	super._start_dive(player)
	Sfx.play("dagger_throw", -2.0, 1.3)

func _update_dive(delta: float, player: Node2D) -> void:
	super._update_dive(delta, player)
	if state == State.CLIMB:
		cooldown = cooldown_time

func _update_visual(delta: float) -> void:
	visual.scale = Vector2(facing, 1.0)
	# Las cuchillas zumban; al embestir, el dron apunta hacia donde va.
	var target_rotation := 0.0
	if state == State.DIVE:
		target_rotation = Vector2(dive_direction.x * facing, dive_direction.y).angle()
	elif state == State.STAGGER:
		target_rotation = sin(flight_time * 22.0) * 0.6
	visual.rotation = lerp_angle(visual.rotation, target_rotation, 14.0 * delta)
	var blink: bool = state == State.WATCH and int(state_timer * 18.0) % 2 == 0
	body_poly.color = HIT_COLOR if flash_timer > 0.0 else (WARNING_COLOR if blink else SHELL)

func _die() -> void:
	aim_line.default_color.a = 0.0
	super._die()
