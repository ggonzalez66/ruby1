extends "res://projectile.gd"

# Misil del guardián mecha: sale hacia arriba desde el hombro, gira hacia el punto marcado en el suelo
# (cruz roja) y cae acelerando. Al tocar el terreno se clava y parpadea; tras la mecha estalla en un
# radio amplio (las paredes cubren). Si toca a Viridy, en vuelo o clavado, estalla al momento. Como
# cualquier proyectil, el rugido lo devuelve (también clavado), y devuelto vuela contra el mecha.

const BODY := Color(0.36, 0.38, 0.42)
const FLAME := Color(1.0, 0.55, 0.15)
const MARK := Color(1.0, 0.18, 0.12)
const WORLD_MASK := 2
# El Area2D no detecta el suelo estático: el trayecto se barre con un rayo, como las balas.
const NEAR_TARGET := 20.0

var target := Vector2.ZERO
var rise_time := 0.45
var cruise_speed := 520.0
var turn_rate := 4.5
var blast_radius := 80.0
var fuse_time := 1.1
var elapsed := 0.0
var marker: Node2D
var flame: Polygon2D
var light: Polygon2D
var exploded := false
var planted := false
var fuse_left := 0.0
var blink_phase := 0.0
var ground_normal := Vector2.UP

func _ready() -> void:
	style = "orb"
	super._ready()
	glow.visible = false
	core.visible = false
	add_child(_poly([Vector2(-10, -3), Vector2(6, -3), Vector2(12, 0), Vector2(6, 3), Vector2(-10, 3)], BODY))
	add_child(_poly([Vector2(-10, -3), Vector2(-14, -6), Vector2(-12, 0), Vector2(-14, 6), Vector2(-10, 3)], BODY.darkened(0.3)))
	flame = _poly([Vector2(-12, -2), Vector2(-24, 0), Vector2(-12, 2)], FLAME)
	add_child(flame)
	light = _circle(2.5, MARK)
	light.position = Vector2(-4, 0)
	light.visible = false
	add_child(light)
	marker = Node2D.new()
	marker.top_level = true
	marker.z_index = -1
	marker.draw.connect(_draw_marker)
	add_child(marker)
	marker.global_position = target
	life = 6.0

func _draw_marker() -> void:
	var pulse: float = 0.5 + 0.5 * sin(elapsed * 18.0)
	if planted:
		# Zona de la explosión: se llena según se consume la mecha.
		var progress: float = 1.0 - fuse_left / fuse_time
		marker.draw_circle(Vector2.ZERO, blast_radius, Color(MARK, 0.06 + 0.14 * progress))
		marker.draw_circle(Vector2.ZERO, blast_radius * progress, Color(MARK, 0.18))
		marker.draw_arc(Vector2.ZERO, blast_radius, 0.0, TAU, 32, Color(MARK, 0.55 + 0.4 * pulse), 2.5, true)
		return
	marker.draw_arc(Vector2.ZERO, blast_radius, 0.0, TAU, 32, Color(MARK, 0.15 + 0.15 * pulse), 1.5, true)
	marker.draw_arc(Vector2.ZERO, blast_radius * 0.4, 0.0, TAU, 20, Color(MARK, 0.5 + 0.4 * pulse), 2.0, true)
	marker.draw_line(Vector2(-12, -12), Vector2(12, 12), Color(MARK, 0.8), 2.0, true)
	marker.draw_line(Vector2(-12, 12), Vector2(12, -12), Color(MARK, 0.8), 2.0, true)

func _physics_process(delta: float) -> void:
	elapsed += delta
	marker.visible = not reflected
	marker.queue_redraw()
	if planted:
		fuse_left -= delta
		# Parpadeo cada vez más rápido según se acaba la mecha.
		blink_phase += delta * lerpf(4.0, 16.0, 1.0 - fuse_left / fuse_time)
		light.visible = fmod(blink_phase, 1.0) < 0.5
		if fuse_left <= 0.0:
			_destroy()
			return
		super._physics_process(delta)
		return
	if not reflected:
		if elapsed > rise_time:
			var wanted: Vector2 = (target - global_position).normalized() * cruise_speed * (1.0 + (elapsed - rise_time) * 0.8)
			velocity = velocity.lerp(wanted, clampf(turn_rate * delta, 0.0, 1.0))
		var near: bool = elapsed > rise_time and global_position.distance_to(target) <= NEAR_TARGET
		if _sweep_ground(delta, near):
			return
		# Sin suelo bajo la cruz (o se acabó el vuelo): estalla en el aire.
		if near or life <= delta:
			_destroy()
			return
	rotation = velocity.angle()
	flame.scale.x = 0.8 + 0.4 * sin(elapsed * 50.0)
	super._physics_process(delta)

func _sweep_ground(delta: float, near: bool) -> bool:
	var step: Vector2 = velocity * delta
	# Junto a la cruz mira un poco más allá para clavarse en vez de estallar en el aire.
	if near:
		step = velocity.normalized() * maxf(step.length(), NEAR_TARGET * 2.0)
	var hit := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, global_position + step, WORLD_MASK))
	if hit.is_empty():
		return false
	_plant(hit.position, hit.normal)
	return true

func _plant(point: Vector2, normal: Vector2) -> void:
	planted = true
	fuse_left = fuse_time
	ground_normal = normal
	rotation = velocity.angle()
	# Medio misil enterrado: la punta (x = 12) queda dentro del terreno.
	global_position = point - velocity.normalized() * 4.0
	velocity = Vector2.ZERO
	life = fuse_time + 1.0
	flame.visible = false
	light.visible = true
	marker.global_position = point
	Fx.dust(get_parent(), point, normal, 4, 1.0)
	Sfx.play("knife_hit", -4.0, 0.7)
	Sfx.play("countdown_tick", -10.0, 1.4)

func _reflect(player: Node) -> void:
	super._reflect(player)
	planted = false
	flame.visible = true
	light.visible = false

func blast_center() -> Vector2:
	return marker.global_position + ground_normal * 8.0 if planted else global_position

func _destroy() -> void:
	if exploded:
		return
	exploded = true
	var center: Vector2 = blast_center()
	if not reflected:
		var player := get_tree().get_first_node_in_group(&"player") as Node2D
		if player != null:
			var body: Vector2 = player.global_position + Vector2(0, -20)
			# Las paredes cubren de la explosión.
			var covered: bool = not get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(center, body, WORLD_MASK)).is_empty()
			if body.distance_to(center) <= blast_radius and not covered:
				player.take_damage(Shine.damage(damage, shine_level), center)
	Fx.impact(get_parent(), center, [Color(0.4, 0.08, 0.04), FLAME, Color(1.0, 0.95, 0.7)], blast_radius / 24.0 if planted else 1.1)
	Sfx.play("grenade_blast", -4.0, 1.15)
	super._destroy()
