extends Area2D

# Proyectil de los dummies tiradores. Daña a Rengar; si lo alcanza el aura del rugido
# se refleja hacia quien lo disparó y pasa a dañar enemigos. Algunos enemigos (tiradores, arquero)
# pueden shinearlo de vuelta: cada shine sube su nivel (más daño, más grande; ver Shine).

const ENEMY_COLOR := Color(0.85, 0.25, 0.55)
const ENEMY_CORE := Color(1.0, 0.75, 0.9)
const REFLECTED_COLOR := Color(1.0, 0.8, 0.28)
const REFLECTED_CORE := Color(1.0, 0.98, 0.82)

var velocity := Vector2.ZERO
var damage := 10
var reflected_damage := 2
var shooter: Node2D
var reflected := false
var life := 6.0
# "orb" (bola de energía de los dummies) o "arrow" (flecha del guardián arquero).
var style := "orb"
var fall_gravity := 0.0
var glow: Polygon2D
var core: Polygon2D
# Veces que se ha shineado (Rengar o enemigos). 0 = recién disparado.
var shine_level := 0
var level_ring: Line2D

func _ready() -> void:
	add_to_group(&"projectiles")
	collision_layer = 0
	collision_mask = 1 | 2
	monitoring = true
	monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	shape.shape = circle
	add_child(shape)
	if style == "arrow":
		# Flecha apuntando a +x: astil, punta y plumas. El nodo rota según la velocidad.
		core = _poly([Vector2(-30, -1.6), Vector2(12, -1.6), Vector2(12, 1.6), Vector2(-30, 1.6)], Color(0.45, 0.3, 0.18))
		glow = _poly([Vector2(10, -6), Vector2(24, 0), Vector2(10, 6)], Color(0.85, 0.35, 0.3))
		add_child(_poly([Vector2(-30, 0), Vector2(-38, -7), Vector2(-24, -1), Vector2(-24, 1), Vector2(-38, 7)], Color(0.9, 0.88, 0.8)))
		add_child(core)
		add_child(glow)
		rotation = velocity.angle()
	else:
		glow = _circle(11.0, Color(ENEMY_COLOR, 0.45))
		core = _circle(6.0, ENEMY_CORE)
		add_child(glow)
		add_child(core)
	# Anillo que aparece desde el segundo shine y late más fuerte cuanto más nivel.
	level_ring = Line2D.new()
	level_ring.points = _circle_points(14.0)
	level_ring.width = 2.0
	level_ring.visible = false
	add_child(level_ring)
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	velocity.y += fall_gravity * delta
	global_position += velocity * delta
	if style == "arrow":
		rotation = velocity.angle()
	else:
		glow.scale = Vector2.ONE * (1.0 + 0.15 * sin(life * 20.0))
	if level_ring.visible:
		level_ring.scale = Vector2.ONE * (1.0 + 0.2 * sin(life * 28.0))
		level_ring.rotation = -rotation
	if reflected:
		return
	# El aura del rugido (también en sus frames latentes) devuelve el proyectil.
	var player := get_tree().get_first_node_in_group(&"player")
	if player and player.is_roar_aura_active() and global_position.distance_to(player.get_roar_center()) <= player.roar_radius + 6.0:
		_reflect(player)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group(&"player"):
		if reflected:
			return
		if body.is_roar_aura_active():
			_reflect(body)
			return
		body.take_damage(Shine.damage(damage, shine_level), global_position)
		_destroy()
		return
	if body is StaticBody2D:
		_destroy()

func _on_area_entered(area: Area2D) -> void:
	if not reflected or not area.has_method("take_hit") or not area.visible:
		return
	# Algunos enemigos lo shinean de vuelta en vez de recibir el golpe.
	if area.has_method("try_shine") and area.try_shine(self):
		_enemy_shine(area)
		return
	var direction: int = 1 if velocity.x >= 0.0 else -1
	area.take_hit(global_position, direction, Shine.damage(reflected_damage, shine_level))
	Fx.impact(get_parent(), global_position, Fx.ROAR, 1.1)
	_destroy()

func _reflect(player: Node) -> void:
	reflected = true
	shine_level += 1
	# Perfect devolución (en las frames del parry): más rápida y un nivel de shine más fuerte.
	var perfect: bool = player.has_method("is_perfect_shine") and player.is_perfect_shine()
	if perfect:
		shine_level += 1
	Stats.add("projectiles_reflected")
	# Vuelve hacia quien lo disparó; si golpea otra cosa por el camino, también vale.
	var goal: Vector2 = global_position - velocity
	if is_instance_valid(shooter):
		goal = shooter.global_position + shooter.get("impact_offset")
	velocity = (goal - global_position).normalized() * max(velocity.length() * 2.0, 420.0)
	if perfect:
		velocity *= player.perfect_reflect_speed
	fall_gravity = 0.0
	life = 4.0
	set_deferred("collision_mask", 2 | 8)
	_apply_shine_look(true)
	Fx.impact(get_parent(), global_position, Fx.ROAR, 1.6 if perfect else 1.0)
	if player.has_method("on_projectile_reflected"):
		player.on_projectile_reflected(perfect)

func _enemy_shine(by: Node2D) -> void:
	# Un enemigo lo devuelve hacia Rengar: vuelve a ser hostil, un nivel más fuerte y algo más rápido.
	reflected = false
	shine_level += 1
	shooter = by
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	var goal: Vector2 = global_position - velocity
	if player:
		goal = player.global_position + Vector2(0, -16)
	velocity = (goal - global_position).normalized() * max(velocity.length() * 1.1, 520.0)
	fall_gravity = 0.0
	life = 4.0
	set_deferred("collision_mask", 1 | 2)
	_apply_shine_look(false)
	Fx.text(get_parent(), global_position + Vector2(0, -30), "¡SHINE!", Shine.color(shine_level, false).lightened(0.3))

func _apply_shine_look(player_side: bool) -> void:
	# Cuanto más nivel, más grande y más caliente; color dorado si es de Rengar, rojizo si es enemigo.
	var tint: Color = Shine.color(shine_level, player_side)
	var visual_scale: float = Shine.visual_scale(shine_level)
	if style == "arrow":
		glow.color = tint
		glow.scale = Vector2.ONE * visual_scale
		core.color = tint.lerp(Color(0.45, 0.3, 0.18), 0.5)
	else:
		glow.color = Color(tint, 0.45)
		core.color = REFLECTED_CORE if player_side else ENEMY_CORE
		core.scale = Vector2.ONE * visual_scale
	level_ring.visible = shine_level >= 2
	level_ring.default_color = Color(tint, 0.9)
	level_ring.width = 1.5 + shine_level * 0.8
	level_ring.points = _circle_points(12.0 * visual_scale)
	level_ring.add_point(level_ring.points[0])

func _destroy() -> void:
	Fx.puff(get_parent(), global_position, Shine.color(max(shine_level, 1), reflected) if shine_level > 0 else ENEMY_COLOR)
	queue_free()

func _poly(points: Array, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array(points)
	poly.color = color
	return poly

func _circle(radius: float, color: Color = Color.WHITE) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.polygon = _circle_points(radius)
	poly.color = color
	return poly

func _circle_points(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(14):
		var angle: float = TAU * index / 14.0
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
