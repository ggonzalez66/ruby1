extends SceneTree

var checks := 0
var fails := 0
var arena: Node2D
var player: CharacterBody2D

func _initialize() -> void:
	_run.call_deferred()

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("  OK   " if ok else "  FAIL ", label)

func fire_on(target: Node2D) -> Node2D:
	var fire: Node2D = load("res://knife.gd").new()
	arena.add_child(fire)
	fire.launch(player, target.position + target.impact_offset, Vector2.RIGHT)
	player.thrown_knife = fire
	player.has_knife = false
	fire._stick_in_enemy(target)
	return fire

func _run() -> void:
	arena = Node2D.new()
	root.add_child(arena)
	var floor_body: StaticBody2D = load("res://platform.gd").new()
	floor_body.size = Vector2(30000, 100)
	floor_body.position = Vector2(0, 50)
	floor_body.collision_layer = 2
	arena.add_child(floor_body)
	player = load("res://playerr.tscn").instantiate()
	player.position = Vector2(0, -2)
	arena.add_child(player)
	var target: Node2D = load("res://training_dummy.tscn").instantiate()
	target.position = Vector2(400, -2)
	target.max_health = 100
	arena.add_child(target)
	await frames(6)
	print("== Vuelo, marca y heavy independiente")
	player._on_knife_input(0)
	var fire: Node2D = player.thrown_knife
	await frames(35)
	check(is_instance_valid(fire) and fire.state == fire.State.MARKED and fire.target == target, "el lanzamiento real clava la lanza y deja una marca en el enemigo")
	check(target.current_health == 100 and fire.sprite.visible and not player.has_knife, "la lanza queda visible y el impacto no añade daño instantáneo")
	player.attack_cooldown_timer = 0
	player._start_heavy_attack(false)
	check(player.attack_mode == player.ATTACK_HEAVY_GROUND, "se puede hacer heavy aunque el fuego esté marcado")
	player._cancel_all_states()
	player.velocity = Vector2.ZERO
	var before: Vector2 = target.position
	player._on_knife_input(0)
	check(fire.state == fire.State.RETURNING and fire.sprite.visible, "recall devuelve físicamente la lanza visible")
	await frames(21)
	check(target.position.x < before.x and target.current_health == 100 and player.has_knife, "soul pull acerca al objetivo sin daño y libera el lanzamiento")
	player._on_knife_input(0)
	check(player.has_knife and not is_instance_valid(player.thrown_knife), "el cooldown evita volver a lanzar inmediatamente")
	await frames(8)
	player._on_knife_input(0)
	check(not player.has_knife and is_instance_valid(player.thrown_knife), "el lanzamiento vuelve a estar disponible tras el cooldown")
	player._respawn_player()
	await frames(4)

	print("== Teleejecución en un objetivo open")
	target.current_health = 20
	player.current_health = 40
	fire = fire_on(target)
	var distant := player.global_position
	fire.recall()
	check(player.execution_core == target.ruby_core and player.global_position.distance_to(target.global_position) < 80, "recall de un open teletransporta e inicia una ejecución aérea")
	check(player.global_position.distance_to(distant) > 200, "el acercamiento es un salto espacial, no un viaje del proyectil")
	await frames(3)
	check(player.animated_sprite.animation == player.ANIMATION_RUBY_SPIN, "la captura usa el giro de ejecución aérea existente")
	for tick in range(60):
		await frames(1)
		if player.execution_core == null:
			break
	check(target.current_health == 0 and not target.visible and player.current_health > 40, "rompe el Ruby y solo entonces cura al jugador")
	check(player.execution_core == null and player.velocity.y < 0, "la ejecución termina con el rebote encadenable")
	player._respawn_player()
	await frames(4)

	print("== Terreno: lanza clavada y regreso")
	fire = load("res://knife.gd").new()
	arena.add_child(fire)
	fire.launch(player, Vector2(800, -60), Vector2(0, 600))
	player.thrown_knife = fire
	player.has_knife = false
	await frames(15)
	var residues := arena.get_children().filter(func(n): return n is Sprite2D and n.name.begins_with("JadeFireResidue"))
	check(is_instance_valid(fire) and fire.state == fire.State.STUCK_WORLD and fire.sprite.visible and not player.has_knife and residues.is_empty(), "el terreno conserva la lanza clavada, sin el fuego antiguo")
	await frames(130)
	check(is_instance_valid(fire) and fire.sprite.visible, "la lanza permanece clavada después de dos segundos")
	player._on_knife_input(0)
	check(fire.is_returning() and fire.sprite.visible, "el input real llama la lanza desde el terreno")
	await frames(40)
	check(not is_instance_valid(fire) and player.has_knife, "el regreso desde terreno recupera la lanza")
	print("RESULTADO: %d/%d OK" % [checks - fails, checks])
	quit(1 if fails else 0)
