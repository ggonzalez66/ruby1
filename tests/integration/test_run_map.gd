extends SceneTree

# Run con mapa de hexágonos (RunState): generación del panal, movimientos sin callejones, hub del Árbol
# Madre, las tres fases de la fábrica (puertas, guardián, mejora gratis, vuelta al mapa), vida entre
# escenas, fuente de curación, tienda del zorro (stock limitado y reroll), morir y el final de la Torre
# (tres guardianes → sol → parkour → Ruby).
var checks := 0
var fails := 0
var state: Node
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

func wait_scene(path: String, limit := 120) -> bool:
	for _i in range(limit):
		await frames(1)
		if current_scene != null and current_scene.scene_file_path == path:
			await frames(8)
			return true
	return false

func player() -> CharacterBody2D:
	return get_first_node_in_group(&"player")

func kill_wave(director: Node) -> void:
	for _round in range(6):
		for enemy in director.enemies:
			if is_instance_valid(enemy) and enemy.is_inside_tree() and enemy.visible:
				enemy.take_hit(Vector2.ZERO, 1, 999)
		await frames(20)
		if director._alive_enemies() == 0:
			return

func kill_bosses(director: Node) -> void:
	for _i in range(200):
		await frames(1)
		if director.phase == director.Phase.BOSS and not director.spawner.bosses.is_empty():
			break
	for boss in director.spawner.bosses:
		boss.take_hit(Vector2.ZERO, 1, 9999)
		boss.ruby_core.claim(player())
		boss.ruby_core.complete(player())

func _run() -> void:
	root.size = Vector2i(1152, 648)
	state = root.get_node("RunState")
	upgrades = root.get_node("Upgrades")

	print("== Mapa: panal y caminos")
	state.start_run(1234)
	var counts := {}
	for cell in state.cells:
		counts[state.cells[cell]] = counts.get(state.cells[cell], 0) + 1
	check(state.cells.size() == 28 and state.cells[Vector2i(3, 0)] == "start", "28 hexágonos con el inicio abajo (%s)" % [counts])
	check(state.cells.keys().filter(func(c): return c.y == 1).all(func(c): return state.cells[c] == "fight"), "la primera fila son enfrentamientos")
	var rows_ok := true
	for row in range(2, state.ROWS.size()):
		var kinds: Array = state.cells.keys().filter(func(c): return c.y == row).map(func(c): return state.cells[c])
		rows_ok = rows_ok and kinds.count("fight") >= 2 and "fountain" in kinds
	check(rows_ok, "cada fila trae una fuente y al menos dos enfrentamientos")
	check(counts.get("shop", 0) >= 3, "hay varios zorros en el mapa (%d)" % counts.get("shop", 0))
	var adjacent_shops := false
	for cell in state.cells:
		if state.cells[cell] == "shop":
			for other in state.neighbors(cell):
				adjacent_shops = adjacent_shops or state.cells.get(other, "") == "shop"
	check(not adjacent_shops, "no hay dos zorros juntos")
	var first: Array = state.available_moves()
	check(first.size() == 2 and first.all(func(c): return c.y == 1), "desde el inicio se elige entre los vecinos de arriba (%s)" % [first])
	var copy: Dictionary = state.cells.duplicate()
	state.generate_map(1234)
	check(copy == state.cells, "la misma semilla da el mismo mapa")
	# Paseos al azar con muchas semillas: nunca se queda sin caminos antes de la Torre ni baja de fila.
	var stuck := 0
	var went_down := 0
	var longest := 0
	for seed_value in range(200):
		state.start_run(seed_value)
		var steps := 0
		while state.current != state.TOWER_CELL:
			var moves: Array = state.available_moves()
			if moves.is_empty():
				stuck += 1
				break
			var next: Vector2i = moves[randi() % moves.size()]
			if next != state.TOWER_CELL and next.y < state.current.y:
				went_down += 1
			state.current = next
			state.visited[next] = true
			steps += 1
		longest = maxi(longest, steps)
	check(stuck == 0 and went_down == 0, "200 runs al azar llegan a la Torre sin callejones ni bajar (atascos %d)" % stuck)
	check(longest <= 20, "el recorrido más largo es de %d hexágonos" % longest)
	state.abort_run()

	print("== Menú y Árbol Madre")
	change_scene_to_file("res://main_menu.tscn")
	await frames(10)
	var gauntlet_button: Button
	for button in current_scene.first_button.get_parent().get_children():
		if button.text == "Entrar al Gauntlet":
			gauntlet_button = button
	gauntlet_button.pressed.emit()
	check(await wait_scene("res://mother_tree.tscn"), "Entrar al Gauntlet lleva al Árbol Madre")
	var hub := current_scene
	check(hub.hub_mode and hub.run_exit != null and hub.run_exit.global_position.x > 6000.0, "la salida de la run está a la derecha")
	check(not state.active, "en el hub no hay run activa")
	player().global_position = hub.run_exit.global_position + Vector2(0, -4)
	check(await wait_scene("res://run_map.tscn"), "salir por la derecha abre el mapa")
	check(state.active and upgrades.active and upgrades.rubies == 0, "empieza una run con las mejoras desde cero")
	var map := current_scene
	check(map.moves.size() == 2 and map.selected in map.moves, "el mapa ofrece los dos hexágonos de arriba")

	print("== Enfrentamiento · fase 1, afueras")
	state.cells[map.moves[0]] = "fight"
	map.choose(map.moves[0])
	check(await wait_scene("res://factory_outdoor.tscn"), "un enfrentamiento empieza en las afueras de la fábrica")
	var director: Node = get_first_node_in_group(&"gauntlet_director")
	var door: Node = current_scene.get_node("FactoryDoor")
	check(director.stage == director.Stage.OUTDOOR and director.round_number == 1, "director de afueras en el enfrentamiento 1")
	check(director.enemies.size() == 5, "5 guardias afuera en el primer enfrentamiento (%d)" % director.enemies.size())
	check(not player().respawn_enabled, "sin checkpoint: morir termina la run")
	check(door.locked and director.counter_label.text.contains("AFUERAS"), "la puerta empieza cerrada · %s" % director.counter_label.text)
	player().take_damage(30, player().global_position + Vector2(40, 0))
	await frames(2)
	var hurt_health: int = player().current_health
	check(state.health == hurt_health and hurt_health < player().max_health, "la run guarda la vida (%d)" % hurt_health)
	player().global_position = door.global_position + Vector2(0, -4)
	await frames(10)
	check(current_scene.scene_file_path == "res://factory_outdoor.tscn", "con la puerta cerrada no se entra")
	await kill_wave(director)
	await frames(80)
	check(not door.locked and door.is_open(), "sin enemigos la puerta se abre")
	player().global_position = door.global_position + Vector2(0, -4)

	print("== Fase 2, dentro")
	check(await wait_scene("res://factory_indoor.tscn"), "la puerta lleva dentro de la fábrica")
	check(player().current_health == hurt_health, "la vida se conserva entre fases (%d)" % player().current_health)
	director = get_first_node_in_group(&"gauntlet_director")
	var boss_door: Node = current_scene.get_node("BossDoor")
	check(director.stage == director.Stage.INDOOR and director.enemies.size() == 8, "8 enemigos en tres pisos (%d)" % director.enemies.size())
	check(boss_door.global_position.y < -800.0 and boss_door.global_position.x > 3000.0, "la puerta del guardián está arriba a la derecha")
	await kill_wave(director)
	await frames(80)
	check(boss_door.is_open(), "al limpiar se abre la puerta del guardián")
	player().global_position = boss_door.global_position + Vector2(0, -4)

	print("== Fase 3, el guardián")
	check(await wait_scene("res://factory_boss.tscn"), "y lleva a la sala del guardián")
	director = get_first_node_in_group(&"gauntlet_director")
	var rubies_before: int = upgrades.rubies
	await kill_bosses(director)
	check(director.spawner.bosses.size() == 1, "un guardián")
	await frames(200)
	check(director.upgrade_menu.is_open() and director.upgrade_menu.stage == director.upgrade_menu.Stage.FREE, "al vencerlo, la mejora gratis")
	var owned_before: int = upgrades.owned.size() + upgrades.element_slots.size()
	director.upgrade_menu.choose(0)
	if director.upgrade_menu.is_confirming():
		director.upgrade_menu.accept_replace()
	await frames(3)
	check(not director.upgrade_menu.is_open(), "tras la mejora gratis no hay tienda (los rubíes se guardan para el zorro)")
	check(upgrades.rubies >= rubies_before, "no se gastan rubíes (%d)" % upgrades.rubies)
	check(director.portals.size() == 1 and director.portals[0].label_text == "AL MAPA", "un portal de vuelta al mapa")
	director.portals[0].entered.emit()
	check(await wait_scene("res://run_map.tscn"), "el portal vuelve al mapa")
	check(state.fights_cleared == 1 and state.depth() == 2, "un enfrentamiento superado")
	map = current_scene
	check(not map.moves.is_empty() and map.moves.all(func(c): return c.y >= 1 and not state.visited.has(c)), "nuevos caminos sin repetir hexágonos")
	var defeated: Array = root.get_node("Stats").get_meta(&"defeated_bosses", [])
	check(defeated.size() == 1, "el guardián vencido no se repite (%s)" % [defeated])

	print("== Fuente de curación")
	state.cells[map.moves[0]] = "fountain"
	map.choose(map.moves[0])
	check(await wait_scene("res://fountain.tscn"), "la fuente es su propio territorio")
	var fountain := current_scene
	check(player().current_health == hurt_health, "llega con la vida de la run")
	player().global_position = Vector2(2000, 200)
	await frames(30)
	check(fountain.used and player().current_health == player().max_health, "meterse en el agua cura toda la vida")
	player().take_damage(20, player().global_position + Vector2(40, 0))
	player().global_position = Vector2(2000, 150)
	await frames(30)
	check(player().current_health < player().max_health, "la fuente se usa una sola vez")
	player().global_position = fountain.exit_sign.global_position + Vector2(0, -4)
	check(await wait_scene("res://run_map.tscn"), "la salida vuelve al mapa")

	print("== Zorro comerciante")
	map = current_scene
	state.cells[map.moves[0]] = "shop"
	upgrades.rubies = 60
	map.choose(map.moves[0])
	check(await wait_scene("res://fox_shop.tscn"), "el zorro tiene su puesto")
	var shop := current_scene
	player().global_position = Vector2(shop.STALL_X, -4)
	await frames(10)
	var menu: CanvasLayer = shop.shop_menu
	check(menu.is_open() and menu.cards.size() == shop.STOCK and menu.stage == menu.Stage.SHOP, "al llegar al mostrador se abre la tienda con %d mejoras" % menu.cards.size())
	var price: int = int(menu.cards[0]["price"])
	menu.choose(0)
	if menu.is_confirming():
		menu.accept_replace()
	check(upgrades.rubies == 60 - price and 0 in menu.bought, "comprar gasta rubíes (%d)" % upgrades.rubies)
	var sold: Dictionary = menu.cards[0]
	var others: Array = menu.cards.slice(1).map(func(card): return card["key"])
	menu.reroll()
	check(upgrades.rubies == 60 - price - upgrades.REROLL_COST, "el reroll cuesta %d rubíes" % upgrades.REROLL_COST)
	check(menu.cards[0] == sold and 0 in menu.bought and menu.cards.size() <= shop.STOCK, "el reroll mantiene lo vendido")
	check(menu.cards.slice(1).all(func(card): return not card["key"] in others), "y cambia el resto")
	var stock: Array = menu.cards.duplicate()
	menu.close()
	await frames(5)
	Input.action_press("move_up")
	await frames(2)
	Input.action_release("move_up")
	await frames(2)
	check(menu.is_open() and menu.cards == stock, "arriba vuelve a abrir la tienda con el mismo stock")
	menu.close()
	player().global_position = shop.exit_sign.global_position + Vector2(0, -4)
	check(await wait_scene("res://run_map.tscn"), "la salida del zorro vuelve al mapa")

	print("== Morir termina la run")
	map = current_scene
	state.cells[map.moves[0]] = "fight"
	map.choose(map.moves[0])
	check(await wait_scene("res://factory_outdoor.tscn"), "otro enfrentamiento")
	director = get_first_node_in_group(&"gauntlet_director")
	check(director.round_number == 2 and director.enemies.size() > 5, "más enemigos en el enfrentamiento 2 (%d)" % director.enemies.size())
	player().take_damage(999, player().global_position + Vector2(40, 0))
	await frames(200)
	var demo: Node = get_first_node_in_group(&"demo_complete")
	var labels: Array = demo.continue_button.get_parent().get_children().filter(func(b): return not b.is_queued_for_deletion()).map(func(b): return b.text)
	check(demo.root_control.visible and demo.title_label.text == "FIN DE LA RUN" and labels == ["Volver al Árbol Madre", "Menú principal"], "fin de la run: %s %s" % [demo.title_label.text, labels])
	check(not state.active and not upgrades.active, "la run se pierde")
	demo.continue_button.pressed.emit()
	check(await wait_scene("res://mother_tree.tscn"), "vuelta al Árbol Madre")

	print("== La Torre, el sol y el Ruby")
	state.start_run(77)
	for cell in state.cells:
		state.visited[cell] = true
	state.current = Vector2i(3, state.ROWS.size() - 1)
	check(state.available_moves() == [state.TOWER_CELL], "desde arriba solo queda la Torre")
	state.enter(state.TOWER_CELL)
	check(await wait_scene("res://tower_finale.tscn"), "la Torre es la última escena del mapa")
	director = get_first_node_in_group(&"gauntlet_director")
	await kill_bosses(director)
	check(director.spawner.bosses.size() == 3, "los tres guardianes juntos")
	await frames(200)
	check(not director.upgrade_menu.is_open() and is_instance_valid(director.sun), "al vencerlos aparece el sol")
	player().global_position = director.sun.global_position + Vector2(0, -4)
	check(await wait_scene("res://stage4.tscn", 600), "el sol absorbe a Viridy y llega el parkour final")
	check(state.active and player().respawn_enabled, "en el parkour las espinas devuelven al checkpoint")
	check(not root.get_node("RunSession").running, "sin cuenta atrás ni récord de etapa dentro de la run")
	var ruby: Node = current_scene.get_node("Ruby1")
	player().global_position = ruby.global_position + Vector2(0, -4)
	await frames(500)
	demo = get_first_node_in_group(&"demo_complete")
	check(demo.root_control.visible and demo.title_label.text == "¡RUN COMPLETADA!", "fundirse con el Ruby termina la run (%s)" % demo.title_label.text)
	check(not state.active, "la run queda cerrada")
	paused = false

	print("RESULTADO: %d/%d" % [checks - fails, checks])
	quit(1 if fails else 0)
