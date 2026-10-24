extends Node2D

# Núcleo común de los autómatas. El daño ordinario nunca inicia una ejecución:
# solo Viridy puede reclamar un núcleo que YA estuviera open al conectar su heavy.
const LOW_HEALTH_RATIO := 0.30
const NORMAL_OPEN_TIME := 2.0
const POSTURE_MAX := 100.0
const POSTURE_HIT := POSTURE_MAX / 3.0
const BOSS_OPEN_TIME := 2.5
const BLAST_RADIUS := 125.0
const BLAST_DAMAGE := 1
const BLAST_PUSH := 450.0
const RED := Color(1.0, 0.08, 0.15)

var enemy: Node2D
var boss := false
var open_time := 0.0
var posture := POSTURE_MAX
var final_open := false
var broken := false
var locked := false
var claimant: WeakRef
var cracks := 0
var clock := 0.0
var spawn_grace_left := 0.0
var parried_attacks := {}

func _ready() -> void:
	enemy = get_parent()
	spawn_grace_left = maxf(float(enemy.get_meta(&"spawn_grace", 0.0)), 0.0)
	boss = enemy.is_in_group(&"boss")
	enemy.add_to_group(&"ruby_enemies")
	position = enemy.impact_offset
	z_index = 4
	if not boss and enemy.get("health_fill") != null:
		# La vida se lee en el núcleo; conservar los nodos antiguos para resets existentes.
		enemy.health_fill.get_parent().hide()

func reset_core() -> void:
	open_time = 0.0
	spawn_grace_left = 0.0
	posture = POSTURE_MAX
	final_open = false
	broken = false
	locked = false
	claimant = null
	cracks = 0
	parried_attacks.clear()
	z_index = 4
	show()

func alive() -> bool:
	return is_instance_valid(enemy) and enemy.visible and not broken and (not boss or not enemy.is_defeated())

func is_open() -> bool:
	if not alive() or locked:
		return false
	if boss:
		return final_open or open_time > 0.0
	return open_time > 0.0 or (enemy.current_health > 0 and enemy.current_health <= enemy.max_health * LOW_HEALTH_RATIO)

func holds_actor() -> bool:
	return locked or final_open or open_time > 0.0 or spawn_grace_left > 0.0

func register_parry(token: int = -1) -> bool:
	if not alive() or locked or final_open or open_time > 0.0:
		return false
	if not boss:
		open_time = NORMAL_OPEN_TIME
		if enemy.get("knock_velocity") != null:
			enemy.knock_velocity = 0.0
		if enemy.get("warning_label") != null:
			enemy.warning_label.hide()
		Fx.text(enemy.get_parent(), global_position + Vector2(0, -35), "OPEN", RED.lightened(0.4))
		return true
	# Una ráfaga, un giro o su arco asociado solo cuentan una vez.
	if token >= 0 and parried_attacks.has(token):
		return false
	if token >= 0:
		parried_attacks[token] = true
	posture = maxf(posture - POSTURE_HIT, 0.0)
	if posture <= 0.01:
		open_time = BOSS_OPEN_TIME
		enemy._on_posture_broken()
		Fx.text(enemy.get_parent(), global_position + Vector2(0, -100), "¡POSTURA ROTA!", Color(1.0, 0.78, 0.3))
		return true
	Fx.text(enemy.get_parent(), global_position + Vector2(0, -70), "POSTURA −33", Color(1.0, 0.7, 0.3))
	return false

func enter_final_open() -> void:
	final_open = true
	posture = 0.0
	open_time = 0.0
	enemy._on_posture_broken()
	Fx.text(enemy.get_parent(), global_position + Vector2(0, -100), "¡ROMPE EL RUBY!", RED.lightened(0.3))

func claim(by: Node) -> bool:
	if not is_open():
		return false
	locked = true
	z_index = 13
	claimant = weakref(by)
	return true

func claimed_by(by: Node) -> bool:
	return locked and claimant != null and claimant.get_ref() == by and alive()

func release_claim(by: Node) -> void:
	if claimant != null and claimant.get_ref() == by:
		locked = false
		z_index = 4
		claimant = null

func complete(by: Node) -> bool:
	if not claimed_by(by):
		return false
	var center := global_position
	z_index = 4
	locked = false
	claimant = null
	if boss and not final_open:
		# El crítico puede dejarlo a cero, pero exige OTRO heavy para romper el núcleo.
		cracks += 1
		open_time = 0.0
		posture = POSTURE_MAX
		parried_attacks.clear()
		enemy.take_hit(by.global_position, by.facing, maxi(1, ceili(enemy.max_health * 0.22)))
		if not final_open:
			enemy._on_reset()
		Stats.add("ruby_criticals")
		Sfx.play("guard_break", -2.0, 1.65)
		Fx.ruby_critical(enemy.get_parent(), center, RED)
		_essence(by, center)
		return false
	broken = true
	hide()
	enemy.current_health = 0
	enemy._update_health_bar()
	if boss:
		enemy._defeat()
	else:
		enemy._die()
	Stats.add("ruby_executions")
	_essence(by, center)
	_blast(center)
	return true

func _physics_process(delta: float) -> void:
	spawn_grace_left = maxf(spawn_grace_left - delta, 0.0)
	clock += delta
	if locked and (claimant == null or not is_instance_valid(claimant.get_ref())):
		locked = false
		z_index = 4
		claimant = null
	if open_time > 0.0 and not locked:
		open_time = maxf(open_time - delta, 0.0)
		if open_time == 0.0 and boss:
			posture = POSTURE_MAX
			parried_attacks.clear()
			enemy._on_reset()
		elif open_time == 0.0 and enemy.get("state_timer") != null:
			enemy.state_timer = 0.0
	# El pulso solo reconstruye geometría cerca de la pantalla. Los timers siguen activos
	# fuera de cámara: una apertura o una captura no depende de dónde esté mirando Viridy.
	if is_visible_in_tree() and get_viewport_rect().grow(64.0).has_point(get_global_transform_with_canvas().origin):
		queue_redraw()

func core_radius() -> float:
	return 15.0 if boss else (7.0 if enemy.get("patrol_width") != null else 9.0)

func health_polygon(radius: float, ratio: float) -> PackedVector2Array:
	var diamond := PackedVector2Array([Vector2(0, -radius), Vector2(radius * 0.65, 0), Vector2(0, radius), Vector2(-radius * 0.65, 0)])
	if ratio <= 0.0:
		return PackedVector2Array()
	if ratio >= 1.0:
		return diamond
	var top := radius * (1.0 - 2.0 * ratio)
	var half_width := radius * 0.65 * (1.0 - absf(top) / radius)
	var filled := PackedVector2Array([Vector2(-half_width, top), Vector2(half_width, top)])
	if top < 0.0:
		filled.append(diamond[1])
	filled.append(diamond[2])
	if top < 0.0:
		filled.append(diamond[3])
	return filled

func posture_outline(radius: float, ratio: float) -> PackedVector2Array:
	var corners := PackedVector2Array([Vector2(0, -radius), Vector2(radius * 0.65, 0), Vector2(0, radius), Vector2(-radius * 0.65, 0), Vector2(0, -radius)])
	var points := PackedVector2Array([corners[0]])
	var remaining := clampf(ratio, 0.0, 1.0) * 4.0
	for edge in range(4):
		if remaining <= 0.0:
			break
		points.append(corners[edge].lerp(corners[edge + 1], minf(remaining, 1.0)))
		remaining -= 1.0
	return points

func _draw() -> void:
	if broken:
		return
	var exposed := is_open() or locked
	var pulse := 0.5 + 0.5 * sin(clock * (18.0 if exposed else 4.0))
	var radius := core_radius()
	for layer in range(3):
		draw_circle(Vector2.ZERO, radius + 3.0 + layer * 3.0, Color(RED, (0.10 + pulse * (0.08 if exposed else 0.02)) / (layer + 1)))
	var diamond := PackedVector2Array([Vector2(0, -radius), Vector2(radius * 0.65, 0), Vector2(0, radius), Vector2(-radius * 0.65, 0)])
	# El oscuro es la vida perdida; el rojo claro baja dentro del mismo rombo.
	draw_colored_polygon(diamond, Color(0.25, 0.01, 0.035))
	var ratio := clampf(float(enemy.current_health) / maxf(float(enemy.max_health), 1.0), 0.0, 1.0)
	var filled := health_polygon(radius, ratio)
	if filled.size() >= 3:
		draw_colored_polygon(filled, RED.lerp(Color(1.0, 0.55, 0.55), pulse * (0.6 if exposed else 0.15)))
	diamond.append(diamond[0])
	draw_polyline(diamond, Color(0.10, 0.005, 0.015), 2.0, true)
	if boss:
		var outline := posture_outline(radius + 5.0, 1.0)
		draw_polyline(outline, Color(0.10, 0.06, 0.015), 5.0, true)
		var remaining := posture_outline(radius + 5.0, posture / POSTURE_MAX)
		if remaining.size() > 1:
			draw_polyline(remaining, Color(1.0, 0.67, 0.15), 2.5, true)
	if exposed:
		draw_polyline(posture_outline(radius + 9.0 + pulse * 2.0, 1.0), Color(1.0, 0.35, 0.3, 0.45), 1.5, true)
	if cracks > 0 or final_open:
		draw_polyline(PackedVector2Array([Vector2(1, -radius), Vector2(-2, -2), Vector2(3, 2), Vector2(-1, radius)]), Color(0.10, 0.0, 0.01), 2.0)

func _essence(by: Node2D, center: Vector2) -> void:
	for index in range(6):
		var mote := Polygon2D.new()
		mote.polygon = PackedVector2Array([Vector2(0, -4), Vector2(3, 0), Vector2(0, 4), Vector2(-3, 0)])
		mote.color = RED.lightened(0.15)
		enemy.get_parent().add_child(mote)
		mote.global_position = center + Vector2(randf_range(-14, 14), randf_range(-14, 14))
		var tween := mote.create_tween()
		tween.tween_property(mote, "global_position", by.global_position + Vector2(0, -26), 0.18 + index * 0.025)
		tween.tween_callback(mote.queue_free)

func _blast(center: Vector2) -> void:
	Sfx.play("guard_break", 1.0, 1.25)
	Fx.shatter(enemy.get_parent(), center, RED, BLAST_RADIUS)
	Fx.puff(enemy.get_parent(), center, RED)
	for target in get_tree().get_nodes_in_group(&"ruby_enemies"):
		if target == enemy or not is_instance_valid(target) or not target.visible:
			continue
		var core: Node = target.get_node_or_null("RubyCore")
		if core == null or core.locked or core.broken:
			continue
		var point: Vector2 = target.global_position + target.impact_offset
		if point.distance_to(center) > BLAST_RADIUS:
			continue
		var ray := PhysicsRayQueryParameters2D.create(center, point, 2)
		if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		var direction := 1 if point.x >= center.x else -1
		target.take_hit(center, direction, BLAST_DAMAGE)
		if target.get("knock_velocity") != null:
			target.on_shine_hit(direction, BLAST_PUSH)
		elif target.has_method("pull_towards"):
			var away := (point - center).normalized()
			if away == Vector2.ZERO:
				away = Vector2.RIGHT
			target.pull_towards(point + away * 180.0, 110.0)
		elif target.has_method("on_shine_hit"):
			target.on_shine_hit(direction, BLAST_PUSH)
