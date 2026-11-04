extends SceneTree

# Tanda del 2026-11-04: variantes de la fábrica (canal, patio de carga, sótano inundado, línea de montaje),
# elección de variante por enfrentamiento, agua estilo Metroid, pasarelas atravesables, enemigos que no se
# meten dentro de los bloques, Ejecución certera, Lanza punzante, el dron sanador que se tambalea al recibir
# golpes y la pose de aerial stall al caer de un salto normal.
var checks := 0
var fails := 0
var upgrades: Node

func _initialize() -> void:
	_run.call_deferred()

func frames(count: int) -> void:
	for _i in range(count):
		await physics_frame

func check(ok: bool, label: String) -> void:
	checks += 1
	fails += 0 if ok else 1
	print("  OK   " if ok else "  FAIL ", label)

func release() -> void:
	for action in ["attack", "heavy_attack", "jump", "dash", "throw_knife", "roar", "move_up", "move_down", "move_left", "move_right"]:
		Input.action_release(action)

func open(path: String) -> void:
	change_scene_to_file(path)
	for _i in range(60):
		await frames(1)
		if current_scene != null and current_scene.scene_file_path == path:
			break
	await frames(10)

func player() -> CharacterBody2D:
	return get_first_node_in_group(&"player")

func quiet() -> Node:
	var director: Node = get_first_node_in_group(&"gauntlet_director")
	director.set_physics_process(false)
	for enemy in director.enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	var stealth: Node = get_first_node_in_group(&"stealth_director")
	if stealth != null:
		stealth.set_physics_process(false)
	await frames(2)
	return director

func ground_below(point: Vector2, reach := 12.0) -> bool:
	var query := PhysicsRayQueryParameters2D.create(point + Vector2(0, -6), point + Vector2(0, reach), 2)
	return not current_scene.get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _run() -> void:
	root.size = Vector2i(1152, 648)
	upgrades = root.get_node("Upgrades")
	await variants()
	await variant_choice()
	await water()
	await catwalks()
	await terrain_guard()
	await upgrades_and_drones()
	await falling_pose()
	print("RESULTADO: %d/%d" % [checks - fails, checks])
	quit(1 if fails else 0)

func variants() -> void:
	print("== Variantes de la fábrica")
	var air_kinds := ["flyer", "stinger", "restorer", "bush"]
	for path in ["res://factory_outdoor_b.tscn", "res://factory_outdoor_c.tscn", "res://factory_indoor_b.tscn", "res://factory_indoor_c.tscn"]:
		await open(path)
		var director: Node = get_first_node_in_group(&"gauntlet_director")
		var exit: Node = director.exit_door
		check(director != null and exit != null, "%s: director y puerta de salida" % path.get_file())
		check(get_nodes_in_group(&"security_cameras").size() >= 1, "%s: al menos una cámara" % path.get_file())
		var spawns: Node = current_scene.get_node("Spawns")
		var grounded := 0
		var floating: Array = []
		for marker in spawns.get_children():
			if marker.get_meta(&"kind", "") in air_kinds:
				continue
			if ground_below(marker.global_position):
				grounded += 1
			else:
				floating.append("%s@%s" % [marker.get_meta(&"kind", ""), marker.global_position])
		check(grounded > 5 and floating.is_empty(), "%s: los enemigos de tierra aparecen sobre el suelo %s" % [path.get_file(), floating])
		check(ground_below(player().global_position), "%s: Viridy empieza sobre el suelo" % path.get_file())
		check(ground_below(exit.global_position, 20.0), "%s: la puerta está apoyada en el suelo" % path.get_file())
		if path.contains("_b"):
			check(get_nodes_in_group(&"water_zones").size() >= 1, "%s: tiene agua" % path.get_file())
		check(get_nodes_in_group(&"one_way_platforms").size() >= 2, "%s: tiene pasarelas atravesables" % path.get_file())

func variant_choice() -> void:
	print("== Elección de variante")
	var run_state: Node = root.get_node("RunState")
	var seen := {}
	for _i in range(30):
		run_state._pick_fight_layout()
		seen[run_state.fight_scene(0)] = true
		seen[run_state.fight_scene(1)] = true
	check(seen.size() == 6, "salen las tres afueras y los tres interiores (%d)" % seen.size())
	run_state.fight_layout = [1, 2, 0]
	check(run_state.fight_phase_of("res://factory_outdoor_b.tscn") == 0 and run_state.fight_scene(1) == "res://factory_indoor_c.tscn", "de las afueras B se pasa al interior elegido")
	check(run_state.fight_scene(2) == "res://factory_boss.tscn", "el guardián es siempre el mismo")
	run_state.layout_variants = false
	run_state._pick_fight_layout()
	check(run_state.fight_scene(0) == "res://factory_outdoor.tscn", "sin variantes (pruebas), la fábrica original")
	run_state.layout_variants = true

func water() -> void:
	print("== Agua")
	await open("res://factory_indoor_b.tscn")
	await quiet()
	var p := player()
	var walk: float = p.max_speed
	var jump: float = p.jump_velocity
	var lunge: float = p.charged_ground_lunge_speed
	var zone: Node2D = get_nodes_in_group(&"water_zones")[0]
	p.global_position = Vector2(zone.global_position.x, 158)
	p.velocity = Vector2.ZERO
	await frames(6)
	check(p.in_water and is_equal_approx(p.max_speed, walk * 0.55) and is_equal_approx(p.jump_velocity, jump * 0.72), "dentro del agua camina y salta menos")
	check(is_equal_approx(p.charged_ground_lunge_speed, lunge), "los ataques no cambian")
	Input.action_press("move_right")
	await frames(30)
	check(p.velocity.x <= walk * 0.55 + 1.0, "se mueve lenta (%.0f)" % p.velocity.x)
	var bubbles: Array = current_scene.get_children().filter(func(n): return String(n.name).begins_with("PixelFx_bubbles"))
	check(not bubbles.is_empty(), "deja burbujas al moverse")
	release()
	p.global_position = Vector2(2600, -2)
	await frames(6)
	check(not p.in_water and is_equal_approx(p.max_speed, walk) and is_equal_approx(p.jump_velocity, jump), "al salir todo vuelve a la normalidad")

func catwalks() -> void:
	print("== Pasarelas atravesables")
	await open("res://factory_indoor.tscn")
	await quiet()
	var p := player()
	var walk: StaticBody2D = current_scene.get_node("F1CatwalkA")
	var top: float = walk.global_position.y - walk.size.y * 0.5
	p.global_position = Vector2(walk.global_position.x, -2)
	p.velocity = Vector2.ZERO
	await frames(4)
	Input.action_press("jump")
	var landed := false
	for tick in range(90):
		await frames(1)
		if tick == 12:
			Input.action_release("jump")
			await frames(1)
			Input.action_press("jump")
		if p.is_on_floor() and absf(p.global_position.y - top) < 3.0:
			landed = true
			break
	release()
	check(landed, "se sube saltando a través desde abajo")
	await frames(10)
	Input.action_press("move_down")
	await frames(2)
	Input.action_press("jump")
	await frames(2)
	release()
	var dropped := false
	for _i in range(60):
		await frames(1)
		if p.is_on_floor() and p.global_position.y > -5.0:
			dropped = true
			break
	check(dropped, "abajo + salto la atraviesa hacia abajo")

func terrain_guard() -> void:
	print("== Enemigos contra el terreno")
	await open("res://factory_indoor.tscn")
	await quiet()
	player().global_position = Vector2(300, -2)
	var crate: StaticBody2D = current_scene.get_node("F1Crate")
	var left_edge: float = crate.global_position.x - crate.size.x * 0.5
	var guard: Area2D = load("res://chaser_dummy.gd").new()
	current_scene.add_child(guard)
	guard.global_position = Vector2(left_edge - 30, -2)
	await frames(2)
	guard.set_physics_process(false)
	for _i in range(40):
		guard._move_horizontally(6.0, false)
	check(guard.global_position.x < left_edge, "empujado contra un contenedor no se mete dentro (%.0f)" % guard.global_position.x)
	guard.global_position = crate.global_position + Vector2(0, -2)
	guard._escape_terrain()
	check(not guard._body_in_terrain(guard.global_position), "si quedó dentro de un bloque, sale")
	var walk: StaticBody2D = current_scene.get_node("F1CatwalkA")
	guard.global_position = Vector2(walk.global_position.x - walk.size.x * 0.5 - 40, walk.global_position.y + 10)
	check(guard.terrain_ray(guard.global_position, guard.global_position + Vector2(80, 0)).is_empty(), "las pasarelas no son pared para los enemigos")
	guard.queue_free()

func upgrades_and_drones() -> void:
	print("== Ejecución certera, Lanza punzante y dron sanador")
	await open("res://factory_boss.tscn")
	await quiet()
	var p := player()
	p.global_position = Vector2(1200, -2)
	upgrades.grant(upgrades._card("sure_execution"))
	var target: Area2D = load("res://chaser_dummy.gd").new()
	current_scene.add_child(target)
	target.global_position = Vector2(1240, -2)
	await frames(2)
	target.set_physics_process(false)
	target.current_health = 1
	p.attack_mode = p.ATTACK_HEAVY_GROUND
	p.attack_targets_hit.clear()
	p._hit_area(target)
	check(p.execution_core != null, "un pesado que lo deja a cero lo ejecuta en el acto")
	for _i in range(90):
		await frames(1)
		if p.execution_core == null:
			break
	p.attack_mode = p.ATTACK_NONE
	check(not is_instance_valid(target) or target.get("state") == target.State.DEAD, "queda ejecutado")
	upgrades.grant(upgrades._card("spear_sting"))
	var speared: Area2D = load("res://chaser_dummy.gd").new()
	current_scene.add_child(speared)
	speared.global_position = Vector2(1500, -2)
	await frames(2)
	speared.set_physics_process(false)
	var plain: int = upgrades.strike(speared, "", 8)
	p.combo.aim_direction = Vector2(1, 0)
	p.has_knife = true
	p.jade_fire_cooldown_timer = 0.0
	p._throw_spear()
	p.thrown_knife.global_position = speared.global_position + speared.impact_offset
	p.thrown_knife._stick_in_enemy(speared)
	check(upgrades.is_speared(speared) and upgrades.strike(speared, "", 8) == ceili(plain * 1.25), "con la lanza clavada recibe un 25 %% más (%d → %d)" % [plain, upgrades.strike(speared, "", 8)])
	p.thrown_knife.queue_free()
	p.thrown_knife = null
	p.has_knife = true
	var drone: Area2D = load("res://restorer.gd").new()
	current_scene.add_child(drone)
	drone.global_position = Vector2(1800, -200)
	await frames(3)
	drone.state = drone.State.PATROL
	drone.take_hit(p.global_position, 1, 1)
	check(drone.state == drone.State.STAGGER and drone.state_timer <= drone.HIT_FLINCH + 0.01, "golpear al dron sanador le corta el vuelo un instante")
	await frames(30)
	check(drone.state != drone.State.STAGGER, "y enseguida vuelve a volar")

func falling_pose() -> void:
	print("== Pose al caer de un salto normal")
	await open("res://factory_boss.tscn")
	await quiet()
	var p := player()
	p.global_position = Vector2(1200, -300)
	p.velocity = Vector2(0, 200)
	await frames(3)
	check(p.animated_sprite.animation == p.ANIMATION_AERIAL_STALL, "cayendo sin carrera usa el aerial stall (%s)" % p.animated_sprite.animation)
	p.global_position = Vector2(1200, -400)
	p.is_sprinting = true
	p.velocity = Vector2(560, 200)
	await frames(2)
	check(p.animated_sprite.animation != p.ANIMATION_AERIAL_STALL, "cayendo de una carrera, la pose de caída (%s)" % p.animated_sprite.animation)
	p.is_sprinting = false
