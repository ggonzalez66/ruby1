extends SceneTree

# Efectos de sonido: que se carguen todos, que suenen por el bus SFX y que las acciones principales
# disparen el suyo.
# Uso (desde la raíz del proyecto): godot --headless --path . -s res://tests/integration/test_sfx.gd

var level: Node
var player: CharacterBody2D
var S: Node
var F: Node
var fails := 0
var checks := 0
const GROUND := Vector2(2300, -2)

func frames(n: int) -> void:
	for i in range(n):
		await physics_frame

func _initialize() -> void:
	_run.call_deferred()

func check(c: bool, label: String) -> void:
	checks += 1
	print("  OK   " if c else "  FAIL ", label)
	if not c:
		fails += 1

func release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "jump", "attack", "heavy_attack", "dash", "throw_knife", "roar"]:
		Input.action_release(a)

func tap(a: String) -> void:
	Input.action_press(a)
	await frames(1)
	Input.action_release(a)

func reset(at: Vector2 = GROUND) -> void:
	release_all()
	F.reset()
	player._respawn_player()
	player.global_position = at
	player.velocity = Vector2.ZERO
	player.has_knife = true
	await frames(5)

# Marca de tiempo antes de una acción: luego se mira si el sonido sonó después.
func played_since(sound: String, since: int) -> bool:
	return int(S.last_played.get(sound, -1)) >= since

func _run() -> void:
	S = root.get_node("Sfx")
	F = root.get_node("Ferocity")
	level = load("res://main.tscn").instantiate()
	root.add_child(level)
	await frames(10)
	player = get_first_node_in_group(&"player")

	print("== Carga")
	var files := 0
	for file in DirAccess.get_files_at("res://assets/sounds/sfx"):
		if file.ends_with(".wav"):
			files += 1
	check(files >= 30 and S.streams.size() == files, "se cargan todos los sonidos (%d de %d)" % [S.streams.size(), files])
	check(AudioServer.get_bus_index(&"SFX") >= 0 and S.players.size() == S.VOICES and S.players[0].bus == &"SFX", "suenan por el bus SFX, con %d voces" % S.VOICES)

	print("== Acciones")
	await reset()
	var t := Time.get_ticks_msec()
	Input.action_press("jump")
	await frames(6)
	Input.action_release("jump")
	check(played_since("jump", t), "saltar")
	await frames(60)

	await reset()
	var chaser: Area2D = Area2D.new()
	chaser.set_script(load("res://chaser_dummy.gd"))
	chaser.position = GROUND + Vector2(30, 0)
	level.add_child(chaser)
	await frames(2)
	t = Time.get_ticks_msec()
	await tap("attack")
	await frames(6)
	check(played_since("swing_light", t), "zarpazo")
	check(played_since("hit_light", t), "golpe que conecta")
	chaser.queue_free()
	await frames(30)

	await reset()
	t = Time.get_ticks_msec()
	await tap("heavy_attack")
	await frames(4)
	check(played_since("swing_heavy", t), "heavy de suelo")
	await frames(40)

	await reset()
	t = Time.get_ticks_msec()
	await tap("roar")
	await frames(4)
	check(played_since("shine", t), "shine")
	await frames(40)

	await reset()
	t = Time.get_ticks_msec()
	await tap("dash")
	await frames(4)
	check(played_since("dash", t), "dash")
	await frames(40)

	await reset()
	t = Time.get_ticks_msec()
	player.take_damage(5, player.global_position + Vector2(30, 0))
	await frames(2)
	check(played_since("hurt", t), "recibir daño")

	t = Time.get_ticks_msec()
	F.reset()
	F.add("test", F.RANK_POINTS * 1.2, "TEST")
	await frames(2)
	check(played_since("rank_up", t), "subir de rango de estilo")

	await reset()
	t = Time.get_ticks_msec()
	Input.action_press("move_up")
	await frames(2)
	Input.action_press("heavy_attack")
	await frames(2)
	release_all()
	await frames(2)
	check(played_since("uppercut", t), "uppercut")

	print("== Shine: estallido y zumbido mantenido")
	check(S.streams["shine_hold"].loop_mode == AudioStreamWAV.LOOP_FORWARD, "el zumbido está en bucle")
	await reset()
	Input.action_press("roar")
	await frames(20)
	check(player.roar_active and S.is_looping("shine_hold"), "mantener el shine deja sonando el zumbido")
	Input.action_release("roar")
	await frames(40)
	await create_timer(0.2, true, false, true).timeout
	check(not player.roar_active and not S.is_looping("shine_hold"), "y al soltarlo se apaga")

	print("== Enemigos")
	await reset()
	t = Time.get_ticks_msec()
	var chaser2: Area2D = Area2D.new()
	chaser2.set_script(load("res://chaser_dummy.gd"))
	chaser2.position = GROUND + Vector2(120, 0)
	level.add_child(chaser2)
	for i in range(90):
		await frames(1)
		if chaser2.state == chaser2.State.TELEGRAPH:
			break
	check(played_since("enemy_alert", t), "el perseguidor avisa antes de atacar")
	t = Time.get_ticks_msec()
	chaser2.take_hit(player.global_position, 1, 1)
	check(played_since("enemy_hurt", t), "y se queja al recibir un golpe")
	chaser2.queue_free()
	await reset(GROUND + Vector2(-600, 0))
	t = Time.get_ticks_msec()
	var shooter: Node2D = load("res://training_dummy.tscn").instantiate()
	shooter.shoot_interval = 0.8
	shooter.shoot_warning_time = 0.3
	shooter.position = GROUND + Vector2(-350, 0)
	level.add_child(shooter)
	await frames(90)
	check(played_since("enemy_charge", t) and played_since("enemy_shoot", t), "el tirador carga y dispara")
	await frames(90)
	check(played_since("projectile_pop", t) or played_since("hurt", t), "y su proyectil estalla o le pega a Viridy")
	shooter.queue_free()

	print("== Todo sonido tiene su mezcla")
	var missing := []
	for sound in S.streams.keys():
		if not S.MIX.has(sound):
			missing.append(sound)
	var orphan := []
	for sound in S.MIX.keys():
		if not S.streams.has(sound):
			orphan.append(sound)
	check(missing.is_empty() and orphan.is_empty(), "cada sonido tiene volumen definido y viceversa (sin mezcla: %s, sin archivo: %s)" % [missing, orphan])

	print("== No se repite el mismo sonido en el mismo instante")
	var before: int = int(S.last_played.get("hit_light", 0))
	S.play("hit_light")
	var first: int = int(S.last_played["hit_light"])
	S.play("hit_light")
	check(int(S.last_played["hit_light"]) == first and first >= before, "dos golpes a la vez suenan una sola vez")

	release_all()
	print("RESULTADO: %d/%d OK" % [checks - fails, checks])
	quit()
