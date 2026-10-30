extends "res://hawk.gd"

# Restaurador: máquina de mantenimiento voladora que busca al aliado más dañado, se pone encima y lo
# repara con un rayo (no repara a los que están en DYING ni a los guardianes). Cuando Viridy se acerca
# huye; si lo acorrala, avisa y suelta una descarga eléctrica a su alrededor (se parrea). Aguanta bastante
# más que los demás pequeños: hay que perseguirlo.

@export var repair_amount := 1
@export var repair_interval := 0.35
@export var repair_range := 70.0
@export var fly_speed := 210.0
@export var flee_distance := 210.0
@export var flee_speed := 300.0
@export var pulse_distance := 95.0
@export var pulse_time := 0.55
@export var pulse_radius := 92.0
@export var pulse_damage := 10
@export var pulse_cooldown := 2.2

const BRASS := Color(0.62, 0.45, 0.2)
const BEAM := Color(1.0, 0.65, 0.2)
const PULSE := Color(0.55, 0.85, 1.0)

var target: Node2D
var repair_timer := 0.0
var near_time := 0.0
var pulse_wait := 0.0
var beam: Line2D
var pulse_ring: Line2D

func _init() -> void:
	max_health = 14
	detect_range = 700.0

func _build() -> void:
	collision_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 20.0
	collision_shape.shape = circle
	add_child(collision_shape)
	visual = Node2D.new()
	add_child(visual)
	wing_back = _poly([Vector2(-6, -14), Vector2(-22, -20), Vector2(-8, -18)], BRASS.darkened(0.3))
	visual.add_child(wing_back)
	body_poly = _poly([Vector2(-16, -10), Vector2(0, -16), Vector2(16, -10), Vector2(16, 10), Vector2(0, 16), Vector2(-16, 10)], BRASS)
	visual.add_child(body_poly)
	wing_front = _poly([Vector2(6, -14), Vector2(22, -20), Vector2(8, -18)], BRASS.darkened(0.2))
	visual.add_child(wing_front)
	ENEMY_SKIN.new().dress(visual, body_poly, "restorer", [wing_back, body_poly, wing_front], null, 22.0)
	beam = Line2D.new()
	beam.width = 4.0
	beam.default_color = Color(BEAM, 0.0)
	beam.top_level = true
	add_child(beam)
	pulse_ring = Line2D.new()
	var points := PackedVector2Array()
	for index in range(29):
		points.append(Vector2.from_angle(TAU * index / 28.0) * pulse_radius)
	pulse_ring.points = points
	pulse_ring.width = 3.0
	pulse_ring.default_color = Color(PULSE, 0.0)
	add_child(pulse_ring)

	warning_label = Label.new()
	warning_label.text = "!"
	warning_label.add_theme_font_size_override("font_size", 24)
	warning_label.add_theme_color_override("font_color", PULSE)
	warning_label.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.1))
	warning_label.add_theme_constant_override("outline_size", 6)
	warning_label.position = Vector2(-5, -70)
	warning_label.visible = false
	add_child(warning_label)

	var bar := Node2D.new()
	bar.position = Vector2(0, -38)
	add_child(bar)
	bar.add_child(_poly([Vector2(-17, -4), Vector2(17, -4), Vector2(17, 4), Vector2(-17, 4)], Color(0.16, 0.15, 0.16, 0.8)))
	health_fill = _poly([], Color(0.95, 0.35, 0.3))
	bar.add_child(health_fill)

func reset_dummy() -> void:
	target = null
	near_time = 0.0
	pulse_wait = 0.0
	super.reset_dummy()

func _physics_process(delta: float) -> void:
	if ruby_core.holds_actor() or state == State.DEAD:
		beam.default_color.a = 0.0
		return
	flight_time += delta
	flash_timer = max(flash_timer - delta, 0.0)
	state_timer -= delta
	pulse_wait = maxf(pulse_wait - delta, 0.0)
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if abs(knock_velocity) > 1.0:
		if FLIGHT_MOTION.move_to(self, collision_shape, global_position + Vector2(knock_velocity * delta, 0)):
			knock_velocity = 0.0
		knock_velocity = move_toward(knock_velocity, 0.0, 900.0 * delta)
	beam.default_color.a = 0.0
	if launched:
		_update_launch(delta)
		_update_visual(delta)
		return
	var player_distance: float = player.global_position.distance_to(global_position) if player and player.current_health > 0 else INF
	match state:
		State.PATROL, State.CLIMB:
			near_time = near_time + delta if player_distance < pulse_distance else 0.0
			if near_time > 0.35 and pulse_wait <= 0.0:
				_start_pulse()
			elif player_distance < flee_distance:
				# Huye en dirección contraria a Viridy (y algo hacia arriba).
				var away: Vector2 = (global_position - player.global_position).normalized()
				_fly_to(global_position + (away + Vector2(0, -0.35)).normalized() * 80.0, flee_speed, delta)
				facing = 1 if away.x >= 0.0 else -1
			else:
				_repair_or_follow(delta)
		State.WATCH:
			# Carga la descarga: el anillo crece y parpadea.
			var progress: float = 1.0 - state_timer / pulse_time
			pulse_ring.scale = Vector2.ONE * (0.3 + 0.7 * progress)
			pulse_ring.default_color = Color(PULSE, 0.3 + 0.5 * absf(sin(state_timer * 30.0)))
			if state_timer <= 0.0:
				_release_pulse(player)
		State.STAGGER:
			FLIGHT_MOTION.move_to(self, collision_shape, global_position + Vector2(0, 30.0 * delta))
			if state_timer <= 0.0:
				state = State.PATROL
	if state != State.WATCH:
		pulse_ring.default_color.a = maxf(pulse_ring.default_color.a - 3.0 * delta, 0.0)
	_update_visual(delta)

func _repair_or_follow(delta: float) -> void:
	if not _repairable(target):
		target = _find_target()
	if target == null:
		# Nadie que reparar: flota junto al aliado más cercano (o en su sitio).
		var ally := _nearest_ally()
		var goal: Vector2 = (ally.global_position + Vector2(0, -110)) if ally != null else home + Vector2(0, sin(flight_time * 2.0) * 10.0)
		_fly_to(goal, fly_speed * 0.6, delta)
		return
	var spot: Vector2 = target.global_position + Vector2(0, -90)
	_fly_to(spot, fly_speed, delta)
	facing = 1 if target.global_position.x >= global_position.x else -1
	if global_position.distance_to(spot) <= repair_range:
		var point: Vector2 = target.global_position + target.get("impact_offset")
		beam.points = PackedVector2Array([global_position + Vector2(0, 10), point])
		beam.default_color = Color(BEAM, 0.55 + 0.3 * sin(flight_time * 30.0))
		repair_timer -= delta
		if repair_timer <= 0.0:
			repair_timer = repair_interval
			target.current_health = mini(target.current_health + repair_amount, target.max_health)
			if target.has_method("_update_health_bar"):
				target._update_health_bar()
			Fx.puff(get_parent(), point, Color(BEAM, 0.8))
			Sfx.play("zap", -10.0, 1.8)

func _fly_to(goal: Vector2, fly: float, delta: float) -> void:
	var destination := global_position.move_toward(goal, fly * delta)
	FLIGHT_MOTION.move_to(self, collision_shape, Vector2(destination.x, global_position.y))
	FLIGHT_MOTION.move_to(self, collision_shape, Vector2(global_position.x, destination.y))

func _repairable(node: Node2D) -> bool:
	if not is_instance_valid(node) or node == self or not node.is_inside_tree() or not node.visible:
		return false
	if node.is_in_group(&"boss") or not ("current_health" in node) or not ("max_health" in node):
		return false
	var core: Node = node.get_node_or_null("RubyCore")
	if core != null and (core.dying or core.holds_actor()):
		return false
	return node.current_health > 0 and node.current_health < node.max_health

func _find_target() -> Node2D:
	var best: Node2D = null
	var best_ratio := 2.0
	for node in get_tree().get_nodes_in_group(&"training_dummies"):
		if node.global_position.distance_to(global_position) > 1400.0 or not _repairable(node):
			continue
		var ratio: float = float(node.current_health) / float(maxi(node.max_health, 1))
		if ratio < best_ratio:
			best_ratio = ratio
			best = node
	return best

func _nearest_ally() -> Node2D:
	var best: Node2D = null
	var best_distance := 900.0
	for node in get_tree().get_nodes_in_group(&"training_dummies"):
		if node == self or not node.visible or node.is_in_group(&"boss"):
			continue
		var distance: float = node.global_position.distance_to(global_position)
		if distance < best_distance:
			best_distance = distance
			best = node
	return best

func _start_pulse() -> void:
	state = State.WATCH
	state_timer = pulse_time
	near_time = 0.0
	warning_label.visible = true
	Sfx.play("enemy_charge", 0.0, 1.4)

func _release_pulse(player: Node2D) -> void:
	warning_label.visible = false
	state = State.PATROL
	pulse_wait = pulse_cooldown
	pulse_ring.scale = Vector2.ONE
	pulse_ring.default_color = Color(PULSE, 0.9)
	Sfx.play("zap", 2.0, 0.9)
	Fx.impact(get_parent(), global_position, [Color(0.1, 0.3, 0.6), PULSE, Color(0.9, 1.0, 1.0)], 1.6)
	if player == null:
		return
	var center: Vector2 = player.global_position + Vector2(0, -22)
	var aura: bool = player.has_method("parry_reaches") and player.parry_reaches(global_position, center)
	if aura or center.distance_to(global_position) <= pulse_radius:
		player.take_damage(pulse_damage, global_position, self)

func on_deflected(_by: Node) -> void:
	# La descarga parreada lo deja aturdido y con el rubí abierto.
	ruby_core.register_parry()
	state = State.STAGGER
	state_timer = 1.6
	Fx.deflect(get_parent(), global_position)

func take_hit(source_position: Vector2, direction: int = 1, damage: int = 1) -> void:
	var charging := state == State.WATCH
	super.take_hit(source_position, direction, damage)
	if charging and state != State.DEAD:
		# Golpearlo mientras carga corta la descarga.
		state = State.STAGGER
		state_timer = 0.4
		warning_label.visible = false

func _update_visual(delta: float) -> void:
	visual.scale = Vector2(facing, 1.0)
	visual.rotation = lerp_angle(visual.rotation, sin(flight_time * 3.0) * 0.08, 10.0 * delta)
	var flap: float = sin(flight_time * 26.0)
	wing_front.rotation = flap * 0.3
	wing_back.rotation = -flap * 0.3
	var blink: bool = state == State.WATCH and int(state_timer * 18.0) % 2 == 0
	body_poly.color = HIT_COLOR if flash_timer > 0.0 else (PULSE if blink else BRASS)

func _die() -> void:
	beam.default_color.a = 0.0
	super._die()
