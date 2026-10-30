extends SceneTree

# Rework sin armas ni Liquid Beast: la ejecución es un pesado, encadena DYING, devuelve recursos aéreos,
# y la bestia solo aparece en los pesados, las ejecuciones y Wrath of Nature.
var checks := 0
var fails := 0
var arena: Node2D
var player: CharacterBody2D
var style: Node

func _initialize() -> void:
	_run.call_deferred()

func frames(count: int) -> void:
	for _i in range(count):
		await physics_frame

func check(ok: bool, label: String) -> void:
	checks += 1
	fails += 0 if ok else 1
	print("  OK   " if ok else "  FAIL ", label)

func dummy(at: Vector2, health := 20) -> Area2D:
	var enemy: Area2D = load("res://training_dummy.tscn").instantiate()
	enemy.position = at
	enemy.max_health = health
	enemy.shoot_interval = 0.0
	arena.add_child(enemy)
	enemy.set_physics_process(false)
	return enemy

func wait_execution() -> void:
	for _i in range(90):
		await frames(1)
		if player.execution_core == null:
			return

func _run() -> void:
	style = root.get_node("Ferocity")
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
	await frames(8)
	check(not InputMap.has_action("transform"), "no queda acción de transformación")
	check(not player.beast_trail.visible, "en reposo no hay estela de bestia")

	print("== El estallido de una ejecución reinicia el DYING de los vecinos")
	var first := dummy(Vector2(70, -2))
	var second := dummy(Vector2(150, -2))
	await frames(2)
	first.take_hit(Vector2.ZERO, 1, 999)
	second.take_hit(Vector2.ZERO, 1, 999)
	second.ruby_core.dying_left = 0.5
	player.attack_mode = player.ATTACK_HEAVY_GROUND
	player.attack_targets_hit.clear()
	player._hit_area(first)
	check(player.execution_core == first.ruby_core, "el pesado reclama el DYING")
	await frames(2)
	check(player.beast_trail.visible, "la ejecución saca el cuerpo de la bestia")
	await wait_execution()
	check(first.ruby_core.broken and second.ruby_core.dying and second.ruby_core.dying_left > second.ruby_core.DYING_TIME - 0.1, "el vecino en DYING vuelve a tener los cuatro segundos")
	check(second.visible and second.ruby_core.is_executable(), "y sigue ejecutable para encadenar")
	first.queue_free()
	second.queue_free()
	player._respawn_player()
	await frames(4)

	print("== Un DYING que expira solo golpea a los vecinos")
	first = dummy(Vector2(400, -2))
	second = dummy(Vector2(480, -2))
	await frames(2)
	first.take_hit(Vector2.ZERO, 1, 999)
	second.take_hit(Vector2.ZERO, 1, 999)
	first.ruby_core.dying_left = 0.01
	var left_before: float = second.ruby_core.dying_left
	await frames(3)
	check(first.ruby_core.broken and second.ruby_core.dying_left < left_before - 1.0, "la explosión sin ejecución resta tiempo, no lo reinicia")
	first.queue_free()
	second.queue_free()
	player._respawn_player()
	await frames(4)

	print("== Ejecutar devuelve el salto aéreo y el uppercut")
	var aerial := dummy(Vector2(220, -260))
	aerial.aerial = true
	await frames(2)
	aerial.take_hit(Vector2.ZERO, 1, 999)
	player.position = Vector2(200, -300)
	await frames(1)
	player.air_jumps_remaining = 0
	player.air_uppercut_available = false
	player.attack_mode = player.ATTACK_HEAVY
	player.attack_targets_hit.clear()
	player._hit_area(aerial)
	await wait_execution()
	check(aerial.ruby_core.broken and player.air_jumps_remaining == player.max_air_jumps and player.air_uppercut_available, "tras la ejecución aérea vuelven el doble salto y el uppercut")
	aerial.queue_free()
	player._respawn_player()
	await frames(4)

	print("== Wrath of Nature: Viridy carga agachada en SSS; la bestia sale en el avance")
	var wrath: Node = player.wrath
	style._set_points(650.0)
	Input.action_press("move_down")
	for _i in range(int(wrath.charge_duration * 60.0) + 20):
		await frames(1)
		if wrath.state == wrath.State.READY:
			break
	Input.action_release("move_down")
	check(wrath.state == wrath.State.READY, "agacharse en SSS carga Wrath sin transformarse")
	await frames(2)
	Input.action_press("heavy_attack")
	await frames(1)
	Input.action_release("heavy_attack")
	check(wrath.state == wrath.State.AIM, "el pesado abre la dirección de Wrath")
	wrath.launch(Vector2.RIGHT)
	await frames(3)
	var rush: AtlasTexture = player.animated_sprite.sprite_frames.get_frame_texture(player.ANIMATION_WRATH_RUSH, 0)
	check(player.animated_sprite.animation == player.ANIMATION_WRATH_RUSH and rush.atlas == player.WRATH_BEAST_SHEET, "el avance usa la bestia completa arremetiendo")
	check(not player.beast_trail.visible, "sin la estela dibujada: la bestia trae su propia llama")
	wrath.cancel()
	style.reset()
	arena.queue_free()
	await frames(2)
	print("RESULTADO: %d/%d" % [checks - fails, checks])
	quit(1 if fails else 0)
