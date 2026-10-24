extends SceneTree

var checks := 0
var fails := 0
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

func _run() -> void:
	var arena := Node2D.new()
	root.add_child(arena)
	var floor_body: StaticBody2D = load("res://platform.gd").new()
	floor_body.size = Vector2(30000, 100)
	floor_body.position = Vector2(0, 50)
	floor_body.collision_layer = 2
	arena.add_child(floor_body)
	player = load("res://playerr.tscn").instantiate()
	player.position = Vector2(0, -2)
	arena.add_child(player)
	await frames(6)
	var style: Node = root.get_node("Ferocity")
	style.reset()

	print("== Daño: pose solo durante el aturdimiento existente")
	player.take_damage(1, player.position + Vector2(-20, 0))
	await frames(1)
	check(player.animated_sprite.animation == &"hurt" and player.hurt_lock_timer > 0, "el golpe interrumpe con la animación de daño")
	await frames(18)
	check(player.hurt_lock_timer <= 0 and player.animated_sprite.animation != &"hurt", "la animación no prolonga los 0,25 s de bloqueo")
	player.invulnerability_timer = 0.0
	style._set_points(350)
	player._start_attack()
	var mode: int = player.attack_mode
	player.take_damage(1, player.position + Vector2(-20, 0))
	await frames(1)
	check(player.hurt_lock_timer <= 0 and player.attack_mode == mode and player.animated_sprite.animation != &"hurt", "Imparable recibe daño y conserva su ataque sin pose de dolor")

	print("== Recuperación líquida puramente visual")
	player._cancel_all_states()
	style.reset()
	player.attack_cooldown_timer = 0.0
	player.ground_heavy_cooldown_timer = 0.0
	player._start_ground_heavy_attack()
	await frames(1)
	check(player.afterimage_container.get_children().any(func(n): return n.name == "HeavyBodyRemnant" and n is Sprite2D), "la parte abandonada es un sprite en el mundo")
	await frames(9)
	check(player.attack_mode == player.ATTACK_NONE and player.heavy_morph_recovery_timer > 0, "el heavy acaba a su tiempo aunque la transición visual siga")
	player.attack_cooldown_timer = 0.0
	player._start_attack()
	await frames(1)
	check(player.attack_mode == player.ATTACK_SLASH and player.animated_sprite.animation == &"light_hit", "otro ataque reemplaza la forma líquida sin esperar al dibujo")
	await frames(20)
	check(not player.afterimage_container.get_children().any(func(n): return n.name == "HeavyBodyRemnant"), "el remanente se elimina tras desvanecerse")

	print("== Mismo período de carrera con apoyos marcados")
	var animations: SpriteFrames = player.animated_sprite.sprite_frames
	var period := 0.0
	for i in range(animations.get_frame_count(&"sprint")):
		period += animations.get_frame_duration(&"sprint", i) / animations.get_animation_speed(&"sprint")
	check(is_equal_approx(period, 1.0 / 3.0), "las ocho poses conservan el período anterior de cuatro poses")
	check(animations.get_frame_duration(&"sprint", 0) > animations.get_frame_duration(&"sprint", 1), "se sostiene más el apoyo que la pose de paso")

	print("== Estelas y cuerpo independientes")
	player._cancel_all_states()
	player.attack_cooldown_timer = 0.0
	player._start_attack()
	player._update_attack_animation()
	check(player.claw_slash_sprite.visible and player.claw_slash_sprite.hframes == 8 and player.claw_slash_sprite.z_index < 0, "los slashes animados se dibujan detrás de la mano")
	player._cancel_all_states()
	player._start_ground_charged_attack()
	player._start_spin_attack()
	player._update_attack_animation()
	check(not player.claw_slash_sprite.visible and player.effect_strokes[0][1].visible, "el screw conserva su remolino y no arrastra el slash anterior")
	print("RESULTADO: %d/%d OK" % [checks - fails, checks])
	quit(1 if fails else 0)
