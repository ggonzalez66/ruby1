extends Node2D

# Daga del guardián ágil lanzada como una rueda: barre el suelo girando hasta cierta distancia,
# frena y vuelve a su mano. Daña a Rengar una vez por pasada (hay que saltarla o shinearla).
# - El rugido la devuelve contra el guardián (shine); si le da, le hace daño y lo aturde.
# - El guardián puede pararla con un parry y mandarla otra vez contra Rengar.
# Cada shine o parry sube su nivel: pega más y se ve más grande y más caliente (ver Shine).

const BLADE_COLOR := Color(0.86, 0.9, 0.97)
const TRIM_COLOR := Color(0.85, 0.72, 0.35)
const DAGGER_LENGTH := 58.0
const RADIUS := 26.0
# Altura del centro de la rueda sobre el suelo: barre a la altura de Rengar, se puede saltar.
const LANE_HEIGHT := 26.0
const SPIN_SPEED := 24.0
const OUT_SPEED := 980.0
const RETURN_ACCELERATION := 2600.0
const RETURN_MAX_SPEED := 1100.0
const REFLECT_SPEED := 1150.0
const CATCH_DISTANCE := 34.0
const LIFETIME := 8.0

enum State { OUT, BACK, REFLECTED }

var boss: Node2D
var state := State.OUT
var direction := 1.0
var speed := 0.0
var deceleration := 0.0
var ground_y := 0.0
var damage := 14
var reflected_damage := 8
var shine_level := 0
# Golpea a Rengar una vez por pasada (ida, vuelta o tras un parry).
var hit_this_pass := false
var life := LIFETIME
var wheel: Node2D
var blades: Array = []
var blur: Line2D
var trail: Line2D

func _ready() -> void:
	z_index = 2
	trail = Line2D.new()
	trail.top_level = true
	trail.width = 14.0
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.9, 0.8, 0.0))
	gradient.set_color(1, Color(1.0, 0.95, 0.9, 0.55))
	trail.gradient = gradient
	add_child(trail)
	wheel = Node2D.new()
	add_child(wheel)
	# Disco y anillo translúcidos: el giro se lee como una rueda afilada.
	var disc := Polygon2D.new()
	var disc_points := PackedVector2Array()
	for index in range(24):
		var angle: float = TAU * index / 24.0
		disc_points.append(Vector2(cos(angle), sin(angle)) * RADIUS)
	disc.polygon = disc_points
	disc.color = Color(BLADE_COLOR, 0.16)
	wheel.add_child(disc)
	blur = Line2D.new()
	for index in range(25):
		var angle: float = TAU * index / 24.0
		blur.add_point(Vector2(cos(angle), sin(angle)) * RADIUS)
	blur.width = 8.0
	blur.default_color = Color(BLADE_COLOR, 0.55)
	wheel.add_child(blur)
	# La daga, centrada en su punto medio, girando sobre sí misma.
	var half: float = DAGGER_LENGTH * 0.5
	var hilt := _poly([Vector2(-half - 3, -5), Vector2(-half + 5, -5), Vector2(-half + 5, 5), Vector2(-half - 3, 5)], TRIM_COLOR)
	var blade := _poly([Vector2(-half + 5, -5), Vector2(half - 10.0, -3), Vector2(half, 0), Vector2(half - 10.0, 3), Vector2(-half + 5, 5)], BLADE_COLOR)
	wheel.add_child(hilt)
	wheel.add_child(blade)
	blades.append(blade)
	# Reflejo de la hoja cruzado: con el giro rápido parece una rueda de cuchillas.
	var ghost := _poly(blade.polygon, Color(BLADE_COLOR, 0.45))
	ghost.rotation = PI * 0.5
	wheel.add_child(ghost)

func launch(owner_boss: Node2D, start: Vector2, throw_direction: float, distance: float, floor_y: float) -> void:
	boss = owner_boss
	ground_y = floor_y
	global_position = Vector2(start.x, floor_y - LANE_HEIGHT)
	_go_out(throw_direction, distance, OUT_SPEED)

func _go_out(throw_direction: float, distance: float, start_speed: float) -> void:
	# Frenado constante: se detiene justo al recorrer "distance" y entonces vuelve.
	state = State.OUT
	direction = 1.0 if throw_direction >= 0.0 else -1.0
	speed = start_speed
	deceleration = start_speed * start_speed / (2.0 * max(distance, 60.0))
	hit_this_pass = false

func _physics_process(delta: float) -> void:
	life -= delta
	if not is_instance_valid(boss) or boss.is_defeated():
		_vanish()
		return
	if life <= 0.0:
		_caught()
		return
	wheel.rotation += SPIN_SPEED * delta * direction
	_update_trail()
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	match state:
		State.OUT:
			speed -= deceleration * delta
			global_position.x += direction * max(speed, 0.0) * delta
			_settle_to_lane(delta)
			if speed <= 40.0:
				state = State.BACK
				speed = 120.0
				hit_this_pass = false
			_check_player(player)
		State.BACK:
			speed = min(speed + RETURN_ACCELERATION * delta, RETURN_MAX_SPEED)
			var dx: float = boss.global_position.x - global_position.x
			direction = sign(dx) if dx != 0.0 else direction
			global_position.x += direction * min(speed * delta, abs(dx))
			_settle_to_lane(delta)
			if abs(dx) <= CATCH_DISTANCE:
				_caught()
				return
			_check_player(player)
		State.REFLECTED:
			# Hacia el centro del guardián; al llegar, o la para o se la come.
			var goal: Vector2 = boss.global_position + boss.impact_offset
			var offset := goal - global_position
			var step: float = REFLECT_SPEED * delta
			if offset.length() <= step + 40.0:
				_reach_boss(player)
				return
			global_position += offset.normalized() * step
			direction = sign(offset.x) if offset.x != 0.0 else direction

func _settle_to_lane(delta: float) -> void:
	global_position.y = move_toward(global_position.y, ground_y - LANE_HEIGHT, 700.0 * delta)

func _check_player(player: Node2D) -> void:
	if player == null or player.dead:
		return
	# El aura del rugido la devuelve (también en sus frames latentes).
	if player.is_roar_aura_active() and global_position.distance_to(player.get_roar_center()) <= player.roar_radius + RADIUS * 0.6:
		_player_shine(player)
		return
	if hit_this_pass:
		return
	var radius: float = RADIUS * Shine.visual_scale(shine_level) + 8.0
	for offset in [Vector2(0, -4), Vector2(0, -16), Vector2(0, -28)]:
		if global_position.distance_to(player.global_position + offset) <= radius:
			hit_this_pass = true
			player.take_damage(Shine.damage(damage, shine_level), global_position, self)
			return

func on_deflected(by: Node) -> void:
	# Parada con los frames explosivos del rugido: igual que el shine.
	if state != State.REFLECTED:
		_player_shine(by)

func _player_shine(player: Node) -> void:
	state = State.REFLECTED
	shine_level += 1
	hit_this_pass = false
	Stats.add("projectiles_reflected")
	Fx.impact(get_parent(), global_position, Fx.ROAR, 1.3)
	_apply_look()
	if player.has_method("on_projectile_reflected"):
		player.on_projectile_reflected()

func _reach_boss(player: Node2D) -> void:
	if boss.has_method("try_parry_dagger") and boss.try_parry_dagger(self):
		# Parry del guardián: vuelve contra Rengar, más fuerte.
		shine_level += 1
		var toward: float = 1.0 if player and player.global_position.x >= global_position.x else -1.0
		var distance: float = abs(player.global_position.x - global_position.x) + 260.0 if player else 500.0
		_go_out(toward, distance, OUT_SPEED * 1.15)
		_apply_look()
		return
	if boss.has_method("on_dagger_hit"):
		boss.on_dagger_hit(self, Shine.damage(reflected_damage, shine_level))
	queue_free()

func _caught() -> void:
	if is_instance_valid(boss) and boss.has_method("on_dagger_caught"):
		boss.on_dagger_caught(self)
	queue_free()

func _vanish() -> void:
	Fx.puff(get_parent(), global_position, BLADE_COLOR)
	queue_free()

func _apply_look() -> void:
	# Dorada si va contra el guardián, rojiza si va contra Rengar; más grande con cada nivel.
	var player_side: bool = state == State.REFLECTED
	var tint: Color = Shine.color(shine_level, player_side)
	wheel.scale = Vector2.ONE * Shine.visual_scale(shine_level)
	blur.default_color = Color(tint, 0.6)
	blur.width = 8.0 + shine_level * 1.5
	for blade in blades:
		blade.color = BLADE_COLOR.lerp(tint, 0.55)
	trail.gradient.set_color(0, Color(tint, 0.0))
	trail.gradient.set_color(1, Color(tint, 0.7))
	trail.width = 14.0 + shine_level * 4.0

func _update_trail() -> void:
	trail.add_point(global_position)
	while trail.get_point_count() > 8:
		trail.remove_point(0)

func _poly(points: Array, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array(points)
	poly.color = color
	return poly
