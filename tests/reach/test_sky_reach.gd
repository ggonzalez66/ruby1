extends SceneTree

# ¿Se puede pasar la Escalera al Cielo? Para cada tramo (isla → volador, volador → volador,
# volador → isla) busca una combinación de entradas que funcione: salto aéreo en el frame a (o
# ninguno), heavy en el frame h y tipo de heavy (arco, diagonal, picado), partiendo de cada tipo de
# rebote (normal o en picado), y encadena los tipos de rebote de principio a fin. Los tramos con
# voladores móviles se prueban en varias fases (basta con una: se puede esperar en la isla).
# Los tramos salen de los nombres de la escena: StartIsland, Seg{n}F{i} (voladores), Seg{n}Land.
# Uso (tarda varios minutos): godot --headless --fixed-fps 60 --path . -s res://tests/reach/test_sky_reach.gd

const ARC := 0
const DIAG := 1
const DIVE := 2
const PHASES := [0.0, 0.25, 0.5, 0.75]

var level: Node
var player: CharacterBody2D
var dummies: Array = []
var current_phase := 0.0

func _initialize() -> void:
	_run.call_deferred()

func frames(n: int) -> void:
	for i in range(n):
		Engine.time_scale = 1.0
		await physics_frame
	Engine.time_scale = 1.0

func release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "jump", "attack", "heavy_attack", "dash", "throw_knife", "roar"]:
		Input.action_release(a)

func set_phase(phase: float) -> void:
	for dummy in dummies:
		dummy.reset_dummy()
		dummy.path_time = phase * dummy.move_period

func fresh_player(at: Vector2) -> void:
	release_all()
	player._cancel_all_states()
	player.attack_mode = player.ATTACK_NONE
	player.attack_cooldown_timer = 0.0
	player.dash_cooldown_timer = 0.0
	player.invulnerability_timer = 0.0
	player.hurt_lock_timer = 0.0
	player.block_stun_timer = 0.0
	player.has_knife = true
	player.current_health = 99999
	player.facing = 1
	player._update_facing_visual()
	player.global_position = at
	player.velocity = Vector2.ZERO
	player.bounce_chain = 0

func dummy_center(dummy: Node2D) -> Vector2:
	return dummy.global_position + dummy.impact_offset

func island_rect(node: Node2D) -> Rect2:
	var size: Vector2 = node.size
	return Rect2(node.global_position - size * 0.5, size)

# Ejecuta un plan ya en el aire. Devuelve el tipo de rebote si golpea "target" (o -1).
func play_plan(a: int, h: int, kind: int, target: Node2D, landing: Rect2) -> int:
	var t := 0
	var heavy_started := false
	var last_pos := player.global_position
	while t < 140:
		if t == a:
			Input.action_press("jump")
		if t == a + 18:
			Input.action_release("jump")
		if t == h and target != null:
			Input.action_release("jump")
			Input.action_release("move_right")
			if kind != ARC:
				Input.action_press("move_down")
			if kind == DIAG:
				Input.action_press("move_right")
			Input.action_press("heavy_attack")
		if t == h + 1 and target != null:
			Input.action_release("heavy_attack")
			Input.action_release("move_down")
			Input.action_press("move_right")
			heavy_started = player.attack_mode == player.ATTACK_HEAVY
		await frames(1)
		t += 1
		# Un salto de más de 200 px en un frame es la vuelta al checkpoint (cayó en las espinas).
		if player.global_position.distance_to(last_pos) > 200.0:
			return -1
		last_pos = player.global_position
		if landing.size != Vector2.ZERO and player.is_on_floor():
			var on_top: bool = player.global_position.x >= landing.position.x and player.global_position.x <= landing.end.x and abs(player.global_position.y - landing.position.y) < 4.0
			return ARC if on_top else -1
		if player.is_on_floor():
			return -1
		if heavy_started and player.attack_mode != player.ATTACK_HEAVY:
			if player.velocity.y < -200.0 and player.global_position.distance_to(dummy_center(target)) < 130.0:
				return DIVE if player.heavy_trajectory == player.HEAVY_DIVE else ARC
			return -1
		if t > h + 70 and target != null:
			return -1
	return -1

func start_from_bounce(from: Node2D, bounce: int) -> void:
	fresh_player(dummy_center(from) + Vector2(-10, -30))
	Input.action_press("dash")
	Input.action_press("move_right")
	player.attack_mode = player.ATTACK_HEAVY
	player.heavy_trajectory = player.HEAVY_DIVE if bounce == DIVE else player.HEAVY_ARC
	player._bounce_out_of_heavy_attack(true)

func start_from_island(island: Rect2, jump_before: float) -> void:
	fresh_player(Vector2(max(island.position.x + 20.0, island.end.x - 320.0), island.position.y - 2.0))
	await frames(2)
	Input.action_press("dash")
	Input.action_press("move_right")
	for i in range(120):
		await frames(1)
		if player.global_position.x >= island.end.x - jump_before:
			break
	Input.action_press("jump")
	await frames(2)
	# Se suelta: si no, el salto aéreo del plan no cuenta como pulsación nueva.
	Input.action_release("jump")

func search(from_dummy: Node2D, bounce: int, island: Rect2, jump_before: float, target: Node2D, landing: Rect2) -> Array:
	var results := []
	var kinds := [ARC, DIAG, DIVE] if target != null else [ARC]
	for kind in kinds:
		var found := false
		for a in [-1, 4, 10, 16, 22, 28]:
			var hs: Array = range(max(a + 2, 2), 64, 3) if target != null else [999]
			for h in hs:
				set_phase(current_phase)
				if from_dummy != null:
					start_from_bounce(from_dummy, bounce)
				else:
					await start_from_island(island, jump_before)
				var outcome: int = await play_plan(a, h, kind, target, landing)
				release_all()
				if outcome >= 0:
					if not outcome in results:
						results.append(outcome)
					found = true
					break
			if found:
				break
	return results

func _run() -> void:
	level = load(OS.get_environment("SCENE") if OS.get_environment("SCENE") != "" else "res://sky_stairs.tscn").instantiate()
	root.add_child(level)
	await frames(10)
	player = get_first_node_in_group(&"player")
	# La meta terminaría la etapa (y congela a Rengar) si una prueba llega hasta ella.
	for goal in ["Sun", "Ruby1"]:
		if level.has_node(goal):
			level.get_node(goal).queue_free()
	for node in get_nodes_in_group(&"training_dummies"):
		dummies.append(node)
	var all_ok := true
	var n := 1
	var previous: Node2D = level.get_node("StartIsland")
	while level.has_node("Seg%dLand" % n):
		var flyer_nodes := []
		var i := 1
		while level.has_node("Seg%dF%d" % [n, i]):
			flyer_nodes.append(level.get_node("Seg%dF%d" % [n, i]))
			i += 1
		var landing_node: Node2D = level.get_node("Seg%dLand" % n)
		var island := island_rect(previous)
		var landing := island_rect(landing_node)
		var moving := false
		for f in flyer_nodes:
			moving = moving or f.move_offset != Vector2.ZERO or f.orbit_radius > 0.0
		var passable := 0
		for phase in (PHASES if moving else [0.0]):
			current_phase = phase
			var reachable := []
			var detail := []
			for jump_before in [10.0, 60.0, 120.0]:
				for kind in await search(null, ARC, island, jump_before, flyer_nodes[0], Rect2()):
					if not kind in reachable:
						reachable.append(kind)
				if reachable.size() == 2:
					break
			detail.append("isla→F1 %s" % [reachable])
			for index in range(flyer_nodes.size()):
				if reachable.is_empty():
					break
				var is_last: bool = index == flyer_nodes.size() - 1
				var target: Node2D = null if is_last else flyer_nodes[index + 1]
				var next := []
				for bounce in reachable:
					for kind in await search(flyer_nodes[index], bounce, Rect2(), 0.0, target, landing if is_last else Rect2()):
						if not kind in next:
							next.append(kind)
				detail.append("F%d→%s %s" % [index + 1, "pilar" if is_last else "F%d" % (index + 2), next])
				reachable = next
			if not reachable.is_empty():
				passable += 1
			print("  Tramo %d fase %.2f: %s | %s" % [n, phase, "OK" if not reachable.is_empty() else "BLOQUEADO", ", ".join(detail)])
		print("%s Tramo %d (%d fases pasables)" % ["OK  " if passable > 0 else "FAIL", n, passable])
		all_ok = all_ok and passable > 0
		previous = landing_node
		n += 1
	print("RESULTADO: %s" % ("OK" if all_ok else "FAIL"))
	quit()
