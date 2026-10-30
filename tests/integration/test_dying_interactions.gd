extends SceneTree

class RecallTarget extends Area2D:
	var damage_taken := 0
	var pulls := 0
	var impact_offset := Vector2.ZERO
	func _ready() -> void:
		collision_layer = 8
		collision_mask = 0
		var collision := CollisionShape2D.new()
		collision.shape = RectangleShape2D.new()
		collision.shape.size = Vector2(20, 30)
		add_child(collision)
	func take_hit(_from: Vector2, _dir: int, damage: int) -> void:
		damage_taken += damage
	func pull_towards(_goal: Vector2, _strength: float) -> void:
		pulls += 1

var checks := 0
var fails := 0
var arena: Node2D
var player: CharacterBody2D
func _initialize() -> void:
	_run.call_deferred()
func frames(n: int) -> void:
	for _i in range(n):
		await physics_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	fails += 0 if ok else 1
	print("  OK   " if ok else "  FAIL ", label)
func block(at: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 2
	body.position = at
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = size
	body.add_child(shape)
	arena.add_child(body)
	return body
func _run() -> void:
	arena = Node2D.new()
	root.add_child(arena)
	block(Vector2(0, 50), Vector2(10000, 100))
	player = load("res://playerr.tscn").instantiate()
	player.position = Vector2(0, -2)
	arena.add_child(player)
	await frames(8)
	# Registrar cuerpos en orden inverso al contacto para exigir ordenación geométrica.
	var targets: Array[RecallTarget] = []
	for x in [150, 280, 410]:
		var target := RecallTarget.new()
		target.position = Vector2(x, -18)
		arena.add_child(target)
		targets.append(target)
	var thrown: Node2D = load("res://knife.gd").new()
	thrown.recall_damage = 10
	arena.add_child(thrown)
	thrown.launch(player, Vector2(500, -18), Vector2.ZERO)
	thrown.set_physics_process(false)
	player.thrown_knife = thrown
	player.has_knife = false
	await frames(2)
	thrown.recall()
	thrown._return_to_player(0.22)
	check(targets[2].damage_taken == 10 and targets[1].damage_taken == 7 and targets[0].damage_taken == 5, "Recall ordena contactos: 100 %, 70 %, 49 %")
	thrown._return_to_player(0.1)
	check(targets.all(func(t): return t.pulls == 1), "Cada enemigo atravesado recibe una única atracción")
	check(player.has_knife, "Recupera la lanza jade")
	for target in targets:
		target.queue_free()
	await frames(3)
	# Los cuatro enemigos pequeños reciben DYING y ejecución real por input heavy.
	var enemy: Area2D
	for script in ["training_dummy", "chaser_dummy", "shield_bearer", "hawk"]:
		player._respawn_player()
		player.position = Vector2(0, -2)
		await frames(8)
		if script == "training_dummy":
			enemy = load("res://training_dummy.tscn").instantiate()
		else:
			enemy = load("res://%s.gd" % script).new()
		enemy.position = Vector2(43, -2 if script != "hawk" else -35)
		arena.add_child(enemy)
		enemy.set_physics_process(false)
		enemy.take_hit(Vector2.ZERO, 1, 999)
		check(enemy.ruby_core.dying and enemy.visible, "%s: permanece en DYING" % script)
		Input.action_press("heavy_attack")
		await frames(2)
		Input.action_release("heavy_attack")
		var captured: bool = player.execution_core != null
		for _i in range(80):
			await frames(1)
			captured = captured or player.execution_core != null
			if enemy.ruby_core.broken:
				break
		check(captured and enemy.ruby_core.broken and not enemy.visible, "%s: la embestida de Viridy ejecuta por colisión real" % script)
		enemy.queue_free()
		await frames(4)
	# Golpear a un enemigo en DYING acorta su temporizador hasta que explota.
	var core_script := load("res://ruby_core.gd")
	var hits_to_die := ceili(core_script.DYING_TIME / core_script.DYING_HIT_TIME)
	for script in ["training_dummy", "chaser_dummy", "shield_bearer", "hawk"]:
		enemy = load("res://training_dummy.tscn").instantiate() if script == "training_dummy" else load("res://%s.gd" % script).new()
		enemy.position = Vector2(400, -2 if script != "hawk" else -35)
		arena.add_child(enemy)
		enemy.set_physics_process(false)
		await frames(2)
		enemy.take_hit(Vector2.ZERO, 1, 999)
		var core: Node = enemy.ruby_core
		if script == "shield_bearer":
			check(not enemy.try_block(enemy.global_position + Vector2(enemy.facing * 30, 0)), "shield_bearer: en DYING no bloquea")
		for _i in range(hits_to_die - 1):
			var before: float = core.dying_left
			enemy.take_hit(Vector2.ZERO, 1, 1)
			if not is_equal_approx(before - core.dying_left, core_script.DYING_HIT_TIME):
				break
		check(core.dying and enemy.visible and core.dying_left > 0.0 and core.dying_left < core_script.DYING_HIT_TIME * 1.5, "%s: cada golpe en DYING resta tiempo sin matarlo antes de tiempo" % script)
		enemy.take_hit(Vector2.ZERO, 1, 1)
		check(not core.dying and core.broken and not enemy.visible, "%s: el último golpe en DYING lo hace explotar" % script)
		enemy.queue_free()
		await frames(2)
	# Con input real: un zarpazo recorta DYING; el núcleo sigue siendo ejecutable.
	player._respawn_player()
	player.position = Vector2(0, -2)
	player.facing = 1
	await frames(8)
	enemy = load("res://training_dummy.tscn").instantiate()
	enemy.position = Vector2(55, -2)
	arena.add_child(enemy)
	enemy.set_physics_process(false)
	await frames(2)
	enemy.take_hit(Vector2.ZERO, 1, 999)
	var left_before: float = enemy.ruby_core.dying_left
	Input.action_press("attack")
	await frames(2)
	Input.action_release("attack")
	await frames(20)
	check(enemy.ruby_core.dying and enemy.ruby_core.dying_left < left_before - 0.5 and enemy.ruby_core.is_executable(), "Zarpazo real acorta DYING y conserva la ejecución")
	enemy.queue_free()
	await frames(4)
	# Stagger interrumpe el ataque sin generar una oportunidad de ejecución.
	player._respawn_player()
	enemy = load("res://chaser_dummy.gd").new()
	enemy.position = Vector2(250, -2)
	arena.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.state = enemy.State.SWING
	enemy.ruby_core.stagger(0.5)
	check(enemy.state == enemy.State.STAGGER and enemy.ruby_core.holds_actor() and not enemy.ruby_core.is_executable(), "Stagger interrumpe SWING sin abrir el ruby")
	enemy.queue_free()
	# B y LB hacen parry (no hay transformación). LT es una acción mantenida.
	player._respawn_player()
	await frames(6)
	for button_index in [JOY_BUTTON_B, JOY_BUTTON_LEFT_SHOULDER]:
		player._end_roar()
		await frames(30)
		var button := InputEventJoypadButton.new()
		button.button_index = button_index
		button.pressed = true
		Input.parse_input_event(button)
		Input.flush_buffered_events()
		await frames(2)
		check(player.roar_active, "Evento real %s hace parry" % ("B" if button_index == JOY_BUTTON_B else "LB"))
		button = InputEventJoypadButton.new()
		button.button_index = button_index
		button.pressed = false
		Input.parse_input_event(button)
		Input.flush_buffered_events()
		await frames(2)
	player._end_roar()
	player._cancel_all_states()
	player._start_dash()
	Input.action_press("throw_knife")
	await frames(2)
	check(player.dash_timer <= 0 and absf(player.velocity.x) <= player.max_speed, "Entrar en Aim desde dash elimina velocidad de carrera")
	Input.action_release("throw_knife")
	arena.queue_free()
	await frames(4)
	print("RESULTADO: %d/%d" % [checks - fails, checks])
	quit(1 if fails else 0)
