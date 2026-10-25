extends SceneTree

var checks := 0
var fails := 0
var arena: Node2D
var player: CharacterBody2D

func _initialize() -> void:
	_run.call_deferred()

func frames(count: int) -> void:
	for index in range(count):
		await physics_frame

func check(ok: bool, label: String) -> void:
	checks += 1
	fails += 0 if ok else 1
	print("  OK   " if ok else "  FAIL ", label)

func block(at: Vector2, size: Vector2) -> StaticBody2D:
	var node := StaticBody2D.new()
	node.position = at
	node.collision_layer = 2
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collider.shape = shape
	node.add_child(collider)
	arena.add_child(node)
	return node

func mark(enemy: Node2D) -> Node2D:
	var fire: Node2D = load("res://knife.gd").new()
	arena.add_child(fire)
	fire.launch(player, enemy.global_position + enemy.impact_offset, Vector2.RIGHT)
	player.thrown_knife = fire
	player.has_knife = false
	fire._stick_in_enemy(enemy)
	return fire

func _run() -> void:
	arena = Node2D.new()
	root.add_child(arena)
	block(Vector2(0, 50), Vector2(30000, 100))
	var wall := block(Vector2(100, -200), Vector2(20, 400))
	player = load("res://playerr.tscn").instantiate()
	player.position = Vector2(2000, -2)
	arena.add_child(player)
	var bird: Area2D = load("res://hawk.gd").new()
	bird.position = Vector2(0, -160)
	arena.add_child(bird)
	bird.set_physics_process(false)
	await frames(5)
	print("== Halcón: volumen completo en todos los movimientos")
	bird.cooldown = 100.0
	bird.patrol_direction = 1.0
	bird._physics_process(1.0)
	check(bird.position.x + 24.0 <= 90.1 and bird.patrol_direction == -1, "patrullar contra una pared detiene el cuerpo y cambia el sentido")
	bird.position = Vector2(0, -160)
	bird.state = bird.State.DIVE
	bird.dive_direction = Vector2.RIGHT
	bird.dive_left = 1000
	bird._physics_process(0.4)
	check(bird.state == bird.State.STAGGER and bird.crashed and bird.position.x + 24.0 <= 90.1, "la picada rápida barre el cuerpo entero y se estrella sin atravesar")
	bird.position = Vector2(0, -160)
	bird.state = bird.State.WATCH
	bird.state_timer = 10.0
	bird.knock_velocity = 1200
	bird._physics_process(0.3)
	check(bird.position.x + 24.0 <= 90.1 and bird.knock_velocity == 0.0, "el empuje y soul pull tampoco atraviesan paredes")
	bird.position = Vector2(0, -80)
	bird.home = Vector2(0, 100)
	bird.state = bird.State.WATCH
	bird.state_timer = 10.0
	bird._physics_process(1.0)
	check(bird.position.y + 24.0 <= 0.1, "el planeo respeta el suelo")
	bird.position = Vector2(0, -80)
	bird.state = bird.State.STAGGER
	bird.crashed = false
	bird.state_timer = 10.0
	bird._physics_process(2.0)
	check(bird.position.y + 24.0 <= 0.1, "la caída aturdida respeta el suelo")
	var ceiling := block(Vector2(0, -250), Vector2(240, 20))
	await frames(2)
	bird.position = Vector2(0, -80)
	bird.home = Vector2(0, -500)
	bird.state = bird.State.CLIMB
	bird.facing = 1
	bird._physics_process(0.8)
	check(bird.position.x + 24.0 <= 90.1 and bird.position.y - 24.0 >= -240.1, "recuperar altura respeta pared y techo")
	bird.position = Vector2(0, -80)
	bird.launch_to(Vector2(0, -500), 0.01, 0.2)
	bird._update_launch(0.02)
	check(bird.position.y - 24.0 >= -240.1 and bird.position.y < -100, "el uppercut del halcón se detiene bajo el techo")
	bird.launched = false
	bird.position = Vector2(60, -160)
	bird.state = bird.State.DIVE
	bird.dive_direction = Vector2.LEFT
	bird.on_deflected(player)
	check(bird.position.x + 24.0 <= 90.1, "el retroceso del parry también barre el cuerpo")
	bird.ruby_core.reset_core()
	bird.position = Vector2(0, -160)
	player.position = Vector2(150, -2)
	check(not bird._can_see(player), "un muro impide detectar al jugador del otro lado")
	wall.queue_free()
	ceiling.queue_free()
	bird.queue_free()
	await frames(3)
	print("== Primer screw y estelas con la escala correcta")
	player._respawn_player()
	player.position = Vector2(2000, -2)
	Input.action_press("dash")
	Input.action_press("move_right")
	await frames(25)
	Input.action_press("attack")
	await frames(2)
	Input.action_release("attack")
	player.afterimage_timer = 0.0
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	var ghosts: Array = player.afterimage_container.get_children().filter(func(item): return item is Sprite2D and item.texture == player.FRONTFLIP_TEXTURE)
	check(player.attack_mode == player.ATTACK_SPIN and not ghosts.is_empty(), "el primer salto desde dash attack ya genera estelas del screw")
	check(ghosts.all(func(item): return item.texture.get_height() * absf(item.global_scale.y) < 140), "ninguna estela del cambio de animación usa la escala gigante anterior")
	Input.action_release("dash")
	Input.action_release("move_right")
	player._cancel_all_states()
	player.position = Vector2(2000, -100)
	player.wall_contact_direction = -1
	player.animated_sprite.scale = Vector2.ONE * 0.18
	player._start_wall_spin_attack()
	player._spawn_afterimage()
	var wall_ghost: Sprite2D = player.afterimage_container.get_child(player.afterimage_container.get_child_count() - 1)
	check(wall_ghost.texture == player.FRONTFLIP_TEXTURE and wall_ghost.texture.get_height() * absf(wall_ghost.global_scale.y) < 140, "el screw de pared también normaliza la pose antes de copiar la estela")
	player._respawn_player()
	player.position = Vector2(2000, -2)
	await frames(4)
	print("== Marca jade y tirón eléctrico")
	var enemy: Node2D = load("res://training_dummy.tscn").instantiate()
	enemy.max_health = 100
	enemy.position = Vector2(2400, -2)
	arena.add_child(enemy)
	var original: Material = enemy.body.material
	var fire := mark(enemy)
	check(enemy.body.material != original and fire.mark_effect.originals.size() >= 2, "la marca tiñe cuerpo y soporte, sin sustituir los colores originales")
	fire.mark_effect._process(0.03)
	check(fire.mark_effect.motes.emitting and not fire.mark_effect.motes.local_coords and fire.mark_effect.motes.emission_rect_extents.y > 15.0, "motas como las de la melena cubren el cuerpo en coordenadas del mundo")
	var before := enemy.position
	fire.recall()
	check(fire.state == fire.State.RETURNING and fire.sprite.visible, "la lanza se mantiene visible al regresar")
	check(root.get_node("Sfx").last_played.has("soul_snap"), "el tirón tiene un chasquido eléctrico propio")
	await frames(22)
	check(not is_instance_valid(fire) and enemy.position.x < before.x and enemy.current_health == 100, "el tirón termina rápido, mueve al objetivo y no inflige daño")
	check(enemy.body.material == original, "consumir la marca restaura su material")
	fire = mark(enemy)
	player._respawn_player()
	await frames(3)
	check(enemy.body.material == original and not is_instance_valid(fire), "reiniciar también elimina tintado y motas de la marca")
	var chaser: Area2D = load("res://chaser_dummy.gd").new()
	chaser.position = Vector2(2600, -2)
	arena.add_child(chaser)
	fire = mark(chaser)
	chaser.ruby_core.claim_wrath(player)
	fire._release()
	await frames(2)
	check(chaser.visual.modulate == Color(0.45, 0.75, 0.65, 0.65), "quitar la marca no altera el tintado de stasis de Wrath")
	chaser.ruby_core.release_claim(player)
	check(chaser.visual.modulate == Color.WHITE and chaser.body_poly.material == null, "liberar la stasis no deja al objetivo permanentemente verde")
	var boss: Area2D = load("res://boss_heavy.gd").new()
	boss.position = Vector2(3000, -2)
	boss.shine_chance = 0.0
	arena.add_child(boss)
	var boss_mark := mark(boss)
	check(boss_mark.mark_effect.motes.emission_rect_extents.y > boss.body_size.y * 0.4, "las motas cubren el cuerpo del jefe aunque no exponga collision_shape")
	boss_mark._release()
	print("== Opciones: llenar ferocidad")
	var style: Node = root.get_node("Ferocity")
	style.reset()
	var menu: CanvasLayer = load("res://pause_menu.gd").new()
	arena.add_child(menu)
	menu._open()
	menu._show_options_page()
	await process_frame
	check(menu.fill_ferocity_button.visible and not menu.fill_ferocity_button.disabled, "Opciones de pausa muestra Llenar ferocidad")
	menu.fill_ferocity_button.pressed.emit()
	check(style.rank == 6 and is_equal_approx(style.points, style.MAX_POINTS) and style.grace > 0, "el botón llena hasta SSS y permite cargar Wrath al reanudar")
	check(menu.options_page.get_global_rect().end.y <= root.get_visible_rect().end.y, "la opción nueva cabe completa en la ventana")
	style.reset()
	style.style_locked = true
	menu._show_options_page()
	check(menu.fill_ferocity_button.disabled, "no modifica una ultimate que ya está activa")
	style.reset()
	menu._resume()
	menu.queue_free()
	print("RESULTADO: %d/%d OK" % [checks - fails, checks])
	quit(1 if fails else 0)
