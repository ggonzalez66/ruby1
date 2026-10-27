extends SceneTree

var checks := 0
var fails := 0
var level: Node2D
var player: CharacterBody2D
var F: Node
const Catalog := preload("res://weapon_catalog.gd")

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("  OK   " if ok else "  FAIL ", label)

func frames(count: int) -> void:
	for _i in range(count):
		await physics_frame

func release() -> void:
	for action in ["attack", "heavy_attack", "jump", "dash", "throw_knife", "roar", "transform", "move_up", "move_down", "move_left", "move_right"]:
		Input.action_release(action)

func tap(action: String) -> void:
	Input.action_press(action)
	await frames(1)
	Input.action_release(action)
	await frames(1)

func reset(id: StringName = &"unarmed", at := Vector2(0, -2)) -> void:
	release()
	player._respawn_player()
	player.weapons.equip(id)
	player.position = at
	F.reset()
	await frames(6)

func enemy(at: Vector2, health := 100) -> Area2D:
	var target := load("res://training_dummy.tscn").instantiate() as Area2D
	target.position = at
	target.max_health = health
	target.shoot_interval = 0.0
	level.add_child(target)
	return target

func _run() -> void:
	F = root.get_node("Ferocity")
	level = Node2D.new()
	root.add_child(level)
	var floor := StaticBody2D.new()
	floor.collision_layer = 2
	floor.position = Vector2(0, 40)
	var collision := CollisionShape2D.new()
	collision.shape = RectangleShape2D.new()
	collision.shape.size = Vector2(8000, 80)
	floor.add_child(collision)
	level.add_child(floor)
	player = load("res://playerr.tscn").instantiate()
	player.position = Vector2(0, -2)
	level.add_child(player)
	await frames(10)
	check(player.weapons.current_weapon() == &"unarmed" and not player.has_knife, "Viridy empieza desarmado")
	# Pulsaciones reales y buffer: cinco golpes, luego fin de cadena.
	var steps := []
	await tap("attack")
	for i in range(5):
		steps.append(player.weapons.step)
		if i < 4:
			await tap("attack")
		var old: int = player.weapons.step
		for _j in range(60):
			await frames(1)
			if not player.weapons.active or player.weapons.step != old:
				break
	check(steps == [0, 1, 2, 3, 4], "Unarmed encadena 3 golpes originales + 2 patadas")
	check(not player.weapons.active, "La cadena de cinco termina sin repetirse al mantener")
	for id in Catalog.IDS:
		for heavy in [false, true]:
			await reset(id)
			var action := "heavy_attack" if heavy else "attack"
			var seen := []
			for index in range(Catalog.chain(id, heavy).size()):
				await tap(action)
				seen.append(player.weapons.step)
				for _j in range(120):
					await frames(1)
					if not player.weapons.active:
						break
			check(seen.size() == Catalog.chain(id, heavy).size() and seen[0] == 0 and seen[-1] == seen.size() - 1, "%s: cadena %s por input (%d golpes)" % [id, "heavy" if heavy else "light", seen.size()])
	# Geometría: estocada frontal no toca espalda; giro real daña ambos lados.
	await reset(&"glaive")
	var front := enemy(Vector2(130, -2))
	var back := enemy(Vector2(-110, -2))
	await frames(2)
	await tap("attack")
	await frames(18)
	check(front.current_health < 100 and back.current_health == 100, "Estocada de guja: alcance frontal y espalda segura")
	for _i in range(3):
		await tap("attack")
		while player.weapons.active:
			await frames(1)
	check(back.current_health < 100, "Remate de guja alcanza detrás")
	front.queue_free()
	back.queue_free()
	# Un giro doble y una ráfaga requieren impactos separados sobre el mismo blanco.
	await reset(&"axe")
	var target := enemy(Vector2(75, -2), 500)
	await frames(2)
	player.weapons.step = 1
	player.weapons.last_heavy = false
	player.weapons.window = 0.5
	await tap("attack")
	await frames(55)
	check(target.current_health <= 494, "Hacha: el remate de dos vueltas golpea dos veces")
	target.queue_free()
	await reset(&"hammer")
	Input.action_press("heavy_attack")
	await frames(65)
	check(player.weapons.charging and not player.weapons.move.is_empty(), "Heavy de martillo se mantiene cargado sin atacar")
	Input.action_release("heavy_attack")
	await frames(2)
	check(not player.weapons.charging and player.weapons.charge_ratio > 0.99, "Soltar heavy libera carga completa")
	var health_before: int = player.current_health
	player.take_damage(5, player.global_position + Vector2(50, 0))
	check(player.current_health == health_before - 5 and player.weapons.active and player.hurt_lock_timer <= 0.0, "Superarmadura recibe daño pero conserva el ataque")
	await reset(&"sword", Vector2(0, -400))
	await tap("attack")
	var air_y: float = player.position.y
	await tap("attack")
	await frames(15)
	check(player.position.y - air_y < 35.0 and not player.is_on_floor(), "El combo ligero mantiene aerial stall")
	# Aim reemplaza el lanzamiento inmediato. Solo tira al pulsar ataque.
	await reset(&"sword")
	Input.action_press("throw_knife")
	Input.action_press("dash")
	Input.action_press("move_right")
	await frames(10)
	check(player.weapons.aim and player.has_knife and not player.is_sprinting and absf(player.velocity.x) <= player.max_speed, "Mantener Aim permite caminar, impide correr y no lanza solo")
	await tap("attack")
	check(not player.has_knife and is_instance_valid(player.thrown_knife) and player.weapons.current_weapon() == &"unarmed", "Lanzar espada cambia temporalmente al moveset desarmado")
	release()
	await frames(10)
	await tap("attack")
	check(player.weapons.active and player.weapons.move.kind == "claw", "Desarmado tras lanzar: ataque ligero disponible")
	player._cancel_attack_for_chain()
	player.attack_cooldown_timer = 0.0
	Input.action_press("throw_knife")
	await frames(2)
	await tap("attack")
	await frames(90)
	check(player.has_knife and player.weapons.current_weapon() == &"sword", "Aim + ataque recupera el arma equipada")
	# Estados y exclusividad de las ejecuciones.
	await reset()
	target = enemy(Vector2(70, -2), 10)
	await frames(2)
	target.take_hit(Vector2.ZERO, 1, 8)
	check(not target.ruby_core.is_open(), "Poca vida ya no equivale a OPEN")
	target.ruby_core.register_parry()
	check(target.ruby_core.is_open() and not target.ruby_core.dying, "Parry produce OPEN independiente de la vida")
	check(not target.ruby_core.claim(player), "Viridy normal no puede reclamar un ruby OPEN")
	await frames(125)
	check(not target.ruby_core.is_open() and target.visible, "OPEN expira a los dos segundos; enemigo sigue vivo")
	target.take_hit(Vector2.ZERO, 1, 20)
	check(target.ruby_core.dying and target.visible and not target.ruby_core.is_open(), "A cero entra en DYING, visible y ejecutable, sin OPEN")
	await frames(180)
	check(target.visible and target.ruby_core.dying, "DYING permanece tres segundos")
	await frames(65)
	check(not target.visible and target.ruby_core.broken, "A los cuatro segundos el ruby explota")
	target.queue_free()
	await reset()
	await tap("transform")
	check(player.liquid_beast, "Q/B alterna a Liquid Beast")
	await tap("transform")
	check(player.liquid_beast, "Cooldown evita doble transformación inmediata")
	await frames(45)
	check(player.liquid_beast, "Liquid Beast se mantiene sin límite temporal")
	Input.action_press("throw_knife")
	await frames(2)
	check(not player.weapons.aim, "Aim no actúa en Liquid Beast")
	Input.action_release("throw_knife")
	target = enemy(Vector2(90, -2), 100)
	await frames(2)
	Input.action_press("attack")
	await frames(35)
	Input.action_release("attack")
	check(target.current_health <= 97 and player.liquid_beast, "Mantener ligero en bestia da aliento continuo")
	await tap("roar")
	check(player.roar_active, "Liquid Beast conserva LB/parry")
	player._end_roar()
	target.take_hit(Vector2.ZERO, 1, 200)
	check(target.ruby_core.claim(player), "Liquid Beast puede reclamar DYING")
	target.ruby_core.release_claim(player)
	target.queue_free()
	await frames(35)
	await tap("transform")
	check(not player.liquid_beast, "Puede volver a Viridy tras el cooldown")
	# Portal y pickups: escena real.
	release()
	level.queue_free()
	await frames(4)
	change_scene_to_file("res://gauntlet.tscn")
	await frames(20)
	var director := get_first_node_in_group(&"gauntlet_director")
	player = get_first_node_in_group(&"player")
	check(director.phase == director.Phase.PREPARATION and director.enemies.is_empty() and not root.get_node("RunSession").running, "Gauntlet espera elección sin enemigos ni reloj")
	var pickup: Node2D = director.armory[1]
	player.position = pickup.position
	await frames(3)
	await tap("move_up")
	check(player.weapons.equipped == &"sword", "Arriba equipa espada suspendida")
	player.position = Vector2(1390, -2)
	await frames(10)
	check(director.phase == director.Phase.WAVE and not director.enemies.is_empty() and get_nodes_in_group(&"weapon_pickups").is_empty(), "Cruzar portal inicia oleada y retira armas")
	check(root.get_node("RunSession").running, "Reloj comienza al cruzar portal")
	release()
	print("RESULTADO: %d/%d" % [checks - fails, checks])
	quit(1 if fails else 0)
