extends SceneTree

class Target extends Area2D:
	var hits := 0
	func _ready() -> void:
		collision_layer = 8
		collision_mask = 0
		var collision := CollisionShape2D.new()
		collision.shape = RectangleShape2D.new()
		collision.shape.size = Vector2(30, 60)
		add_child(collision)
	func take_hit(_from: Vector2, _direction: int, _damage: int) -> void:
		hits += 1

var player: CharacterBody2D
var target: Target
var checks := 0
var fails := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	fails += 0 if ok else 1
	print("OK " if ok else "FAIL ", label)

func frames(n: int) -> void:
	for _i in n:
		await physics_frame

func start(step: int = 0) -> void:
	player._cancel_all_states()
	player.attack_cooldown_timer = 0
	player.combo.step = step - 1
	player.combo.window = 0.5
	player.combo.request()
	target.hits = 0

func _run() -> void:
	var arena := Node2D.new()
	root.add_child(arena)
	player = load("res://playerr.tscn").instantiate()
	arena.add_child(player)
	await frames(3)
	player.set_physics_process(false)
	player.position = Vector2.ZERO
	player.facing = 1
	player._update_facing_visual()
	target = Target.new()
	target.position = Vector2(55, -30)
	arena.add_child(target)
	await frames(2)
	var w = player.combo
	check(w.chain().size() == 5 and w.chain()[3].kind == "kick" and w.chain()[4].kind == "kick", "Combo ligero: tres zarpazos y dos patadas")
	for step in w.chain().size():
		var label: String = "ligero %d" % (step + 1)
		start(step)
		w.tick(w.startup * 0.5)
		check(target.hits == 0 and w.phase == w.Phase.STARTUP, label + ": startup sin daño")
		w.tick(w.startup * 0.5 + 0.000001)
		check(target.hits == 1 and w.phase == w.Phase.ACTIVE, label + ": impacto al entrar en active")
		w.tick(0.000001)
		check(target.hits == 1, label + ": no repite el impacto")
		# Un enemigo que aparece en recovery no recibe daño, ni siquiera en el borde.
		w.hit_set.clear()
		w.elapsed = w.startup + w.active_time
		w.tick(w.recovery * 0.5)
		check(target.hits == 1 and w.active, label + ": recovery sin daño, ataque aún ocupado")
		w.tick(w.recovery)
		check(not w.active and w.phase == w.Phase.IDLE, label + ": termina tras recovery")
	# Un frame largo cruza la ventana una vez; el siguiente no hace daño tardío.
	start(3)
	w.tick(w.duration + 0.1)
	check(target.hits == 1 and not w.active, "Frame largo conserva el impacto de la patada")
	w.tick(1.0)
	check(target.hits == 1, "No hay impactos tardíos tras terminar")
	# El siguiente golpe espera al recovery y empieza con su propio startup.
	start()
	w.request()
	w.tick(w.startup + w.active_time + w.recovery * 0.5)
	check(w.step == 0 and w.phase == w.Phase.RECOVERY, "Buffer no omite el recovery")
	w.tick(w.recovery)
	check(w.step == 1 and w.phase == w.Phase.STARTUP and is_zero_approx(w.elapsed), "Siguiente golpe comienza con startup completo")
	start(2)
	w.tick(w.startup * 0.5)
	player._cancel_all_states()
	w.tick(10)
	check(target.hits == 0 and w.phase == w.Phase.IDLE and w.queued == &"", "Cancelar startup elimina daño y buffer pendientes")
	# Los zarpazos marcan una pose por fase; las patadas (6 frames) recorren guardia y recogidas en startup,
	# el golpe en active y recuperación y guardia en recovery.
	for step in [0, 2]:
		start(step)
		w.tick(w.startup * 0.5)
		player._update_character_animation()
		check(player.animated_sprite.animation == player.LIGHT_COMBO_ANIMATIONS[step] and player.animated_sprite.frame == 0, "golpe %d: pose de anticipación en startup" % (step + 1))
		w.tick(w.startup * 0.5 + 0.001)
		player._update_character_animation()
		check(player.animated_sprite.frame == 1, "golpe %d: pose de impacto al activar daño" % (step + 1))
		w.tick(w.active_time)
		player._update_character_animation()
		var last: int = player.animated_sprite.sprite_frames.get_frame_count(player.animated_sprite.animation) - 1
		check(player.animated_sprite.frame == last, "golpe %d: pose final durante recovery" % (step + 1))
	for step in [3, 4]:
		var label: String = "patada %d" % (step - 2)
		start(step)
		w.tick(0.0001)
		player._update_character_animation()
		check(player.animated_sprite.animation == player.LIGHT_COMBO_ANIMATIONS[step] and player.animated_sprite.sprite_frames.get_frame_count(player.animated_sprite.animation) == 6 and player.animated_sprite.frame == 0, label + ": empieza en guardia")
		w.tick(w.startup * 0.9)
		player._update_character_animation()
		check(player.animated_sprite.frame == 2 and target.hits == 0, label + ": recogida al final del startup, sin daño")
		w.tick(w.startup * 0.1 + 0.001)
		player._update_character_animation()
		check(player.animated_sprite.frame == 3 and target.hits == 1, label + ": pierna extendida en active")
		w.tick(w.active_time + w.recovery * 0.2)
		player._update_character_animation()
		check(player.animated_sprite.frame == 4, label + ": recuperación al empezar recovery")
		w.tick(w.recovery * 0.75)
		player._update_character_animation()
		check(player.animated_sprite.frame == 5, label + ": vuelve a la guardia al final")
	# El recovery de un ligero se cancela en la embestida al instante; antes, el pesado espera.
	start()
	w.tick(w.startup + w.active_time + w.recovery * 0.3)
	check(w.phase == w.Phase.RECOVERY, "Ligero llega a su recovery")
	player._start_heavy_attack(false)
	check(not w.active and player.attack_mode in [player.ATTACK_HEAVY, player.ATTACK_HEAVY_GROUND], "Pesado cancela el recovery del ligero al instante")
	start(3)
	w.tick(w.startup * 0.5)
	player._start_heavy_attack(false)
	check(w.queued == &"heavy" and w.active, "Pesado pulsado en el startup de la patada queda en cola")
	w.tick(w.startup * 0.5 + w.active_time + 0.001)
	check(not w.active and player.attack_mode in [player.ATTACK_HEAVY, player.ATTACK_HEAVY_GROUND], "El pesado en cola sale en cuanto empieza el recovery")
	start()
	player.show_hitbox_debug = true
	player._update_hitbox_visual_visibility()
	check(not player.slash_visual.visible and not player.attack_effects.visible, "Debug no muestra hitbox heredada durante startup")
	player.show_hitbox_debug = false
	# Input real: pulsaciones repetidas se guardan sin saltarse el recovery.
	start()
	player._cancel_all_states()
	Input.action_press("attack")
	player._physics_process(1.0 / 60.0)
	Input.action_release("attack")
	await frames(1)
	check(w.active and w.phase == w.Phase.STARTUP and target.hits == 0, "Input ligero real entra en startup")
	Input.action_press("attack")
	player._physics_process(1.0 / 60.0)
	Input.action_release("attack")
	check(w.queued == &"light" and w.step == 0, "Input repetido guarda combo sin adelantar fases")
	player._cancel_all_states()
	arena.queue_free()
	await frames(2)
	print("RESULTADO: %d/%d" % [checks - fails, checks])
	quit(1 if fails else 0)
