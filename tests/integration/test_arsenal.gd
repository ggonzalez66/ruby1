extends SceneTree

# Armas a distancia del Gauntlet y lo que las rodea: confirmación de reemplazo, elementos a distancia, pistola,
# granada, railgun, hechizo de Enfoque, vida y postura por ronda, variantes elementales, alarma y estilo.
var checks := 0
var fails := 0
var director: Node
var stealth: Node2D
var player: CharacterBody2D
var upgrades: Node
var style: Node
var time_control: Node
var spawned: Array = []

func _initialize() -> void:
	_run.call_deferred()

func frames(count: int) -> void:
	for _i in range(count):
		await physics_frame

func check(ok: bool, label: String) -> void:
	checks += 1
	fails += 0 if ok else 1
	print("  OK   " if ok else "  FAIL ", label)

func enemy_at(at: Vector2, script_path := "res://chaser_dummy.gd") -> Area2D:
	var enemy: Area2D = load(script_path).new()
	enemy.position = at
	enemy.max_health = 60
	player.get_parent().add_child(enemy)
	spawned.append(enemy)
	await frames(2)
	enemy.set_physics_process(false)
	return enemy

func reset() -> void:
	for enemy in spawned:
		if is_instance_valid(enemy):
			enemy.queue_free()
	spawned.clear()
	director._clear_wave()
	stealth.stand_down()
	director.focus.cancel()
	upgrades.begin_run()
	style.reset()
	player._respawn_player()
	player.position = Vector2(2000, -2)
	player.velocity = Vector2.ZERO
	player.jade_fire_cooldown_timer = 0.0
	player.invulnerability_timer = 0.0
	await frames(4)

func hit_again() -> void:
	player.invulnerability_timer = 0.0
	player.hurt_lock_timer = 0.0

func aim_rifle(rifle: Area2D) -> void:
	# Al centro del cuerpo de Viridy, que mide 28 px de alto.
	rifle.aim_direction = (player.global_position + Vector2(0, -14) - rifle._muzzle()).normalized()

func card_keys(count := 80) -> Array:
	return upgrades.offers(count).map(func(card): return card["key"])

func _run() -> void:
	upgrades = root.get_node("Upgrades")
	style = root.get_node("Ferocity")
	time_control = root.get_node("TimeControl")
	root.add_child(load("res://gauntlet.tscn").instantiate())
	await frames(10)
	director = get_first_node_in_group(&"gauntlet_director")
	stealth = get_first_node_in_group(&"stealth_director")
	player = get_first_node_in_group(&"player")

	print("== Cartas de armas y elementos a distancia")
	await reset()
	var keys := card_keys()
	check(upgrades.ranged_weapon() == "spear", "se empieza con la lanza")
	for key in ["ranged_fire", "ranged_electric", "ranged_ice", "weapon_pistol", "weapon_grenade", "weapon_railgun", "time_stop"]:
		check(key in keys, "se ofrece %s" % key)
	check(not "greed" in keys and not "alarm_hunter" in keys, "Codicia y Sangre de alarma ya no existen")
	check(not "weapon_spear" in keys and not "spear_burn" in keys and not "pistol" in keys, "ni el arma actual ni las mejoras antiguas")
	upgrades.grant(upgrades._element_card("electric", upgrades.RANGED_SLOT))
	keys = card_keys()
	check(not keys.any(func(key): return key.begins_with("ranged_")), "un elemento por arma a distancia")
	upgrades.grant(upgrades._weapon_card("railgun"))
	keys = card_keys()
	check("weapon_spear" in keys and not "weapon_railgun" in keys, "la lanza se puede recuperar")
	check(not "spear_pierce" in keys, "la railgun no ofrece perforar: ya atraviesa todo")
	await reset()
	upgrades.grant(upgrades._weapon_card("grenade"))
	check(not "ranged_ice" in card_keys(), "la granada no ofrece hielo: ya hiela")
	await reset()
	upgrades.end_run()
	check(upgrades.ranged_weapon() == "spear", "fuera del Gauntlet siempre es la lanza")
	upgrades.begin_run()

	print("== Confirmar el reemplazo")
	await reset()
	var menu: CanvasLayer = director.upgrade_menu
	upgrades.add_rubies(30)
	menu.open()
	menu.cards = [upgrades._weapon_card("pistol"), upgrades._card("long_cloak"), upgrades._card("temper")]
	menu.choose(0)
	check(menu.is_confirming() and upgrades.ranged_weapon() == "spear", "elegir un arma pregunta antes de cambiarla")
	check(menu.confirm_label.text == "¿Reemplazar Lanza de jade por Pistola?", "nombra las dos armas: %s" % menu.confirm_label.text)
	check(not menu.main_column.visible and root.gui_get_focus_owner() == menu.confirm_back, "el foco va a Volver")
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	menu._input(cancel)
	check(not menu.is_confirming() and menu.stage == menu.Stage.FREE and menu.main_column.visible, "cancelar vuelve a las cartas")
	check(upgrades.ranged_weapon() == "spear", "y no cambia nada")
	menu.choose(0)
	menu.accept_replace()
	check(upgrades.ranged_weapon() == "pistol" and upgrades.rubies == 30, "aceptar la gratis cambia el arma sin cobrar")
	check(menu.stage == menu.Stage.SHOP, "y sigue a la tienda")
	menu.cards = [upgrades._weapon_card("railgun"), upgrades._weapon_card("pistol"), upgrades._element_card("fire", "light")]
	menu.choose(0)
	check(menu.is_confirming() and upgrades.rubies == 30, "en la tienda tampoco cobra antes de confirmar")
	check(menu.confirm_label.text == "¿Reemplazar Pistola por Railgun?", "reemplaza la que lleva: %s" % menu.confirm_label.text)
	menu.accept_replace()
	check(upgrades.ranged_weapon() == "railgun" and upgrades.rubies == 12, "aceptar cobra y cambia (%d)" % upgrades.rubies)
	menu.choose(1)
	check(not menu.is_confirming(), "el arma comprada ya no se puede elegir")
	upgrades.rubies = 1
	menu.cards = [upgrades._weapon_card("pistol"), upgrades._card("long_cloak"), upgrades._card("temper")]
	menu.choose(0)
	check(not menu.is_confirming(), "sin rubíes no se llega a confirmar")
	upgrades.add_rubies(40)
	menu.bought.clear()
	menu.cards = [upgrades._element_card("fire", "light"), upgrades._element_card("ice", "light"), upgrades._card("temper")]
	menu.choose(0)
	var after_first: int = upgrades.rubies
	menu.choose(1)
	check(upgrades.element_for("light") == "fire" and upgrades.rubies == after_first, "una carta que quedó ocupada no se cobra")
	menu.close()
	await frames(3)
	director._clear_portals()
	director.phase = director.Phase.WAVE

	print("== La lanza vuelve a la mano al cambiar de arma")
	await reset()
	player._throw_spear()
	check(not player.has_knife, "lanza fuera")
	upgrades.grant(upgrades._weapon_card("pistol"))
	player.sync_ranged_weapon()
	check(player.has_knife and player.thrown_knife == null, "vuelve al equipar otra arma")

	print("== Pistola: cadencia alta y daño bajo")
	await reset()
	upgrades.grant(upgrades._weapon_card("pistol"))
	var target := await enemy_at(Vector2(2300, -2))
	# Con mando: sin esto la mira sigue al mouse.
	var hints: Node = root.get_node("InputHints")
	hints.device = hints.Device.JOYPAD
	Input.action_press("throw_knife")
	await frames(3)
	player.combo.aim_direction = Vector2(1, 0).rotated(-0.02)
	Input.action_press("dash")
	await frames(62)
	Input.action_release("dash")
	await frames(20)
	check(60 - target.current_health == 1, "semiautomática: mantener el gatillo dispara una sola bala (%d)" % (60 - target.current_health))
	for _i in range(8):
		Input.action_press("dash")
		await frames(2)
		Input.action_release("dash")
		await frames(6)
	await frames(20)
	check(60 - target.current_health == 9, "cada toque es una bala de 1 de daño (%d)" % (60 - target.current_health))
	for _i in range(6):
		Input.action_press("dash")
		await frames(2)
		Input.action_release("dash")
		await frames(2)
	Input.action_release("throw_knife")
	await frames(20)
	var lost: int = 60 - target.current_health - 9
	check(lost >= 1 and lost < 6, "tocar más rápido que la cadencia no suma balas (%d de 6)" % lost)
	await reset()
	upgrades.grant(upgrades._weapon_card("pistol"))
	upgrades.grant(upgrades._element_card("ice", upgrades.RANGED_SLOT))
	target = await enemy_at(Vector2(2300, -2))
	player.combo.aim_direction = Vector2(1, 0).rotated(-0.02)
	player.pistol_shots = 0
	for shot_number in range(2):
		player.jade_fire_cooldown_timer = 0.0
		player._throw_spear()
		await frames(16)
	check(target.get_node_or_null("ElementStatus") == null, "dos disparos sin elemento")
	player.jade_fire_cooldown_timer = 0.0
	player._throw_spear()
	await frames(16)
	check(target.get_node("ElementStatus").ice_stacks == 1, "el tercero lleva el elemento")

	print("== Cargador de la pistola")
	await reset()
	upgrades.grant(upgrades._weapon_card("pistol"))
	player.pistol_ammo = player.PISTOL_MAGAZINE
	# Hacia arriba: las balas no alcanzan a nadie de las pruebas siguientes.
	player.combo.aim_direction = Vector2(0, -1)
	for _i in range(player.PISTOL_MAGAZINE - 1):
		player.jade_fire_cooldown_timer = 0.0
		player._throw_spear()
	check(player.pistol_ammo == 1 and is_equal_approx(player.jade_fire_cooldown_timer, player.PISTOL_COOLDOWN), "cada disparo gasta una bala (queda %d)" % player.pistol_ammo)
	player.jade_fire_cooldown_timer = 0.0
	player._throw_spear()
	check(player.pistol_ammo == player.PISTOL_MAGAZINE and is_equal_approx(player.jade_fire_cooldown_timer, player.PISTOL_RELOAD), "al vaciarse recarga (%.2f s)" % player.jade_fire_cooldown_timer)
	var shots_before: int = player.pistol_shots
	player._throw_spear()
	check(player.pistol_shots == shots_before, "mientras recarga no dispara")
	for shot in player.get_parent().get_children().filter(func(node): return node.get_script() == load("res://pistol_shot.gd")):
		shot.queue_free()
	await frames(2)

	print("== Elemento en la lanza")
	await reset()
	upgrades.grant(upgrades._element_card("ice", upgrades.RANGED_SLOT))
	target = await enemy_at(Vector2(2200, -30))
	player._throw_spear()
	player.thrown_knife.global_position = target.global_position + target.impact_offset
	player.thrown_knife._stick_in_enemy(target)
	check(target.get_node("ElementStatus").ice_stacks == 1 and target.current_health == 60, "clavarse aplica el elemento sin daño")
	player.thrown_knife.queue_free()
	player.thrown_knife = null

	print("== Granada de hielo")
	await reset()
	upgrades.grant(upgrades._weapon_card("grenade"))
	target = await enemy_at(Vector2(2200, -2))
	var near := await enemy_at(Vector2(2290, -2))
	var far := await enemy_at(Vector2(3000, -2))
	player.combo.aim_direction = Vector2(1, -0.12).normalized()
	player._throw_spear()
	check(player.has_knife and is_equal_approx(player.jade_fire_cooldown_timer, player.GRENADE_COOLDOWN), "tiene enfriamiento")
	player._throw_spear()
	var grenades := func(): return player.get_parent().get_children().filter(func(node): return node.get_script() == load("res://ice_grenade.gd"))
	check(grenades.call().size() == 1, "no se puede lanzar otra durante el enfriamiento")
	var saw_clusters := false
	for _i in range(90):
		await frames(1)
		saw_clusters = saw_clusters or grenades.call().size() > 1
	check(saw_clusters, "explota y suelta racimos")
	check(grenades.call().is_empty(), "los racimos también explotan")
	check(target.current_health < 60 and near.current_health < 60, "daña a los de la zona (%d, %d)" % [target.current_health, near.current_health])
	check(far.current_health == 60, "no a los lejanos")
	check(target.get_node("ElementStatus").ice_stacks > 0 or target.get_node("ElementStatus").is_frozen(), "y los hiela")
	await reset()
	upgrades.grant(upgrades._weapon_card("grenade"))
	var walled := await enemy_at(Vector2(2200, -2))
	var wall := StaticBody2D.new()
	wall.collision_layer = 2
	var wall_shape := CollisionShape2D.new()
	wall_shape.shape = RectangleShape2D.new()
	wall_shape.shape.size = Vector2(20, 300)
	wall.add_child(wall_shape)
	wall.position = Vector2(2150, -100)
	player.get_parent().add_child(wall)
	await frames(2)
	var blast: Node2D = load("res://ice_grenade.gd").new()
	player.get_parent().add_child(blast)
	blast.global_position = Vector2(2110, -30)
	blast.cluster = true
	blast._explode()
	check(walled.current_health == 60, "las paredes cubren de la explosión")
	wall.queue_free()

	print("== Railgun")
	await reset()
	upgrades.grant(upgrades._weapon_card("railgun"))
	var first := await enemy_at(Vector2(2200, -2))
	var second := await enemy_at(Vector2(2400, -2))
	var shield := await enemy_at(Vector2(2600, -2), "res://shield_bearer.gd")
	shield.facing = -1
	player.position = Vector2(2000, -2)
	await frames(2)
	player.combo.aim_direction = Vector2(1, 0).rotated(-0.02)
	player.velocity = Vector2.ZERO
	var health_shield: int = shield.current_health
	player._throw_spear()
	check(first.current_health == 48 and second.current_health == 48, "atraviesa a todos (%d, %d)" % [first.current_health, second.current_health])
	check(shield.current_health < health_shield, "y a los escudos")
	check(player.hitstop_end_msec > 0, "con mucho hitstop")
	check(player.velocity.x < -100.0, "y un empujón hacia atrás (%.0f)" % player.velocity.x)
	check(player.jade_fire_cooldown_timer > 1.0, "es lenta")
	await frames(30)
	await reset()
	upgrades.grant(upgrades._weapon_card("railgun"))
	player.combo.aim_direction = Vector2(1, 0)
	player.velocity = Vector2.ZERO
	player._throw_spear()
	check(player.velocity.x == 0.0, "sin conectar no hay retroceso")
	await frames(30)

	print("== Hechizo de Enfoque")
	await reset()
	Input.action_press("slow_motion")
	await process_frame
	await process_frame
	check(director.focus.casting and time_control.slow_motion, "pulsar RB pone cámara lenta")
	Input.action_release("slow_motion")
	await process_frame
	await process_frame
	check(director.focus.casting and time_control.slow_motion, "es un toggle: soltar RB no lo termina")
	var spent: float = upgrades.focus
	await create_timer(0.4, true, false, true).timeout
	check(upgrades.focus < spent - 5.0, "gasta Enfoque (%.0f → %.0f)" % [spent, upgrades.focus])
	Input.action_press("slow_motion")
	await process_frame
	await process_frame
	Input.action_release("slow_motion")
	await process_frame
	check(not director.focus.casting and not time_control.slow_motion and is_equal_approx(Engine.time_scale, 1.0), "pulsar RB otra vez lo termina")
	upgrades.focus = 10.0
	Input.action_press("slow_motion")
	await process_frame
	await process_frame
	check(not director.focus.casting, "con poco Enfoque no se lanza")
	Input.action_release("slow_motion")
	await process_frame
	upgrades.focus = 21.0
	Input.action_press("slow_motion")
	await process_frame
	await process_frame
	check(director.focus.casting, "lo mínimo alcanza")
	Input.action_release("slow_motion")
	await process_frame
	upgrades.focus = 0.5
	await create_timer(0.1, true, false, true).timeout
	await process_frame
	check(not director.focus.casting and not time_control.slow_motion, "sin Enfoque se acaba")
	upgrades.focus = 80.0
	await process_frame
	await process_frame
	check(not director.focus.casting, "hay que volver a pulsar")
	Input.action_release("slow_motion")
	await process_frame
	var regen: float = upgrades.focus
	await create_timer(0.3, true, false, true).timeout
	check(upgrades.focus > regen, "vuelve solo, despacio")
	upgrades.focus = 0.0
	player.register_execution(false)
	check(is_equal_approx(upgrades.focus, upgrades.FOCUS_PER_EXECUTION), "ejecutar lo recarga")
	target = await enemy_at(Vector2(2200, -2))
	var charge: float = upgrades.focus
	upgrades.strike(target, "light", 1)
	check(upgrades.focus > charge, "golpear también")
	var pause_menu: Node = get_first_node_in_group(&"pause_menu")
	var event := InputEventAction.new()
	event.action = "slow_motion"
	event.pressed = true
	if pause_menu != null:
		pause_menu._unhandled_input(event)
	check(not time_control.slow_motion, "en el Gauntlet RB no es la cámara lenta libre")
	upgrades.focus = 100.0
	Input.action_press("slow_motion")
	await process_frame
	await process_frame
	director.focus.cancel()
	Input.action_release("slow_motion")
	await process_frame
	check(not time_control.slow_motion, "cancelar devuelve la velocidad (al abrir la tienda o morir)")

	print("== Reloj detenido")
	await reset()
	upgrades.grant(upgrades._card("time_stop"))
	target = await enemy_at(Vector2(2300, -2))
	target.ruby_core.stagger_left = 2.0
	var bullet: Area2D = load("res://projectile.gd").new()
	bullet.velocity = Vector2(-300, 0)
	bullet.life = 3.0
	player.get_parent().add_child(bullet)
	bullet.global_position = Vector2(2500, -60)
	await frames(2)
	Input.action_press("slow_motion")
	await process_frame
	await process_frame
	check(director.focus.world_stopped and not time_control.slow_motion and is_equal_approx(Engine.time_scale, 1.0), "el tiempo del mundo para, no el de Viridy")
	check(target.ruby_core.time_stopped and target.ruby_core.holds_actor(), "el enemigo queda quieto")
	var bullet_at := bullet.global_position
	var stagger_at: float = target.ruby_core.stagger_left
	await frames(20)
	check(bullet.global_position == bullet_at, "los proyectiles se detienen")
	check(is_equal_approx(target.ruby_core.stagger_left, stagger_at), "y los temporizadores del enemigo")
	check(director.focus.bar_label.text == "TIEMPO DETENIDO", "el HUD lo dice")
	Input.action_release("slow_motion")
	await process_frame
	await process_frame
	check(target.ruby_core.time_stopped, "es un toggle: soltar RB no lo termina")
	Input.action_press("slow_motion")
	await process_frame
	await process_frame
	Input.action_release("slow_motion")
	check(not target.ruby_core.time_stopped, "pulsar RB otra vez vuelve el tiempo")
	await frames(10)
	check(bullet.global_position != bullet_at, "y los proyectiles siguen")
	bullet.queue_free()
	await reset()
	upgrades.grant(upgrades._card("time_stop"))
	target = await enemy_at(player.global_position + Vector2(60, 0))
	Input.action_press("slow_motion")
	await process_frame
	await process_frame
	target.take_hit(player.global_position, 1, 999)
	player.attack_mode = player.ATTACK_HEAVY_GROUND
	player.attack_targets_hit.clear()
	player._hit_area(target)
	for _i in range(90):
		await frames(1)
		if player.execution_core == null:
			break
	player.attack_mode = player.ATTACK_NONE
	check(player.execution_core == null and upgrades.rubies == 1 and not target.visible, "se puede ejecutar con el tiempo detenido")
	Input.action_release("slow_motion")
	await process_frame
	await process_frame
	await reset()
	target = await enemy_at(Vector2(2300, -2))
	var pistol_focus: float
	upgrades.focus = 10.0
	upgrades.strike(target, "", 1)
	pistol_focus = upgrades.focus
	check(is_equal_approx(pistol_focus, 10.0), "las balas sin cargar no recargan Enfoque")

	print("== Vida y postura por ronda")
	await reset()
	director.round_number = 1
	director._add_chaser(Vector2(3200, 0))
	await frames(3)
	var rookie: Area2D = director.enemies[0]
	check(rookie.max_health == 10 and rookie.current_health == 10, "ronda 1: un poco más de vida (%d)" % rookie.max_health)
	check(rookie.ruby_core.posture_toughness == 1.0, "ronda 1: un parry lo abre")
	director.round_number = 5
	director._add_chaser(Vector2(3300, 0))
	director._add_scripted(load("res://stinger.gd"), Vector2(3400, -200))
	await frames(3)
	var veteran: Area2D = director.enemies[1]
	var stinger: Area2D = director.enemies[2]
	check(veteran.max_health == 17 and veteran.current_health == 17, "ronda 5: más vida (%d)" % veteran.max_health)
	check(stinger.max_health == ceili(3 * 2.05), "escala sobre la vida de cada tipo (%d)" % stinger.max_health)
	check(veteran.ruby_core.posture_toughness == 3.0, "ronda 5: aguanta 3 parries")
	check(not veteran.ruby_core.register_parry() and veteran.ruby_core.open_time == 0.0, "el primer parry no lo abre")
	check(not veteran.ruby_core.register_parry() and veteran.ruby_core.open_time == 0.0, "el segundo tampoco")
	check(veteran.ruby_core.register_parry() and veteran.ruby_core.open_time > 0.0, "el tercero sí")
	check(is_equal_approx(veteran.ruby_core.posture, veteran.ruby_core.POSTURE_MAX), "y la postura se recupera")
	director.spawner.spawn_round()
	var guardian: Area2D = director.spawner.bosses[0]
	var normal_health: int = guardian.max_health
	director._tune_guardians()
	check(guardian.max_health == ceili(normal_health * 1.6) and guardian.current_health == guardian.max_health, "los guardianes también (%d → %d)" % [normal_health, guardian.max_health])
	check(is_equal_approx(guardian.ruby_core.posture_toughness, 2.0), "y su postura dura el doble")
	director.spawner.clear_bosses()
	director.round_number = 1
	director.spawner.spawn_round()
	guardian = director.spawner.bosses[0]
	normal_health = guardian.max_health
	director._tune_guardians()
	check(guardian.max_health == normal_health and guardian.ruby_core.posture_toughness == 1.0, "el primer guardián sigue igual")
	director.spawner.clear_bosses()

	print("== Variantes elementales")
	await reset()
	var fiery := await enemy_at(Vector2(2300, -2))
	director.make_variant(fiery, "fire")
	check(fiery.get_meta(&"element") == "fire" and fiery.modulate != Color.WHITE, "se distingue por su color")
	var variant_status: Node = upgrades.status_of(fiery)
	variant_status.apply("fire", 5)
	check(variant_status.burn_left == 0.0, "no sufre su propio elemento")
	var tint: Color = fiery.modulate
	await frames(3)
	check(fiery.modulate == tint, "el estado no le borra el color")
	var ailments: Node2D = player.ailments
	var health: int = player.current_health
	player.take_damage(10, fiery.global_position, fiery)
	check(ailments.burn_left > 0.0, "su golpe quema a Viridy")
	await frames(120)
	check(player.current_health < health - 10, "daño en el tiempo (%d)" % player.current_health)
	player.current_health = 2
	ailments.burn_left = 5.0
	ailments.burn_wait = 0.01
	await frames(90)
	check(player.current_health == 1, "la quemadura no mata")
	await reset()
	ailments = player.ailments
	var shot: Area2D = load("res://projectile.gd").new()
	shot.element = "ice"
	player.get_parent().add_child(shot)
	await frames(1)
	shot._on_body_entered(player)
	check(ailments.slow_left > 0.0 and ailments.ice_stacks == 1, "los proyectiles también lo aplican")
	check(is_equal_approx(ailments.movement_scale(), ailments.SLOW_SCALE), "el hielo la ralentiza")
	player.velocity = Vector2(400, 0)
	var start_x := player.global_position.x
	await frames(1)
	var slowed_step := player.global_position.x - start_x
	check(slowed_step < 400.0 / 60.0, "avanza menos (%.2f)" % slowed_step)
	hit_again()
	player.take_damage(1, Vector2(2100, -2), null, "ice")
	hit_again()
	player.take_damage(1, Vector2(2100, -2), null, "ice")
	check(ailments.ice_stacks == 0 and player.hurt_lock_timer > 0.5, "con 3 queda congelada")
	await reset()
	ailments = player.ailments
	for _i in range(3):
		hit_again()
		player.take_damage(1, Vector2(2100, -2), null, "electric")
	check(ailments.marks == 0 and player.hurt_lock_timer > 0.5, "3 marcas eléctricas la aturden")
	await reset()
	ailments = player.ailments
	var long_burn: float
	player.take_damage(1, Vector2(2100, -2), null, "fire")
	long_burn = ailments.burn_left
	await reset()
	ailments = player.ailments
	upgrades.grant(upgrades._card("temper"))
	player.take_damage(1, Vector2(2100, -2), null, "fire")
	check(is_equal_approx(ailments.burn_left, long_burn * 0.5), "Temple elemental lo reduce a la mitad")
	await reset()
	ailments = player.ailments
	player.take_damage(1, Vector2(2100, -2), null, "")
	check(ailments.burn_left == 0.0 and ailments.slow_left == 0.0, "un golpe normal no aplica nada")
	director.round_number = 50
	check(is_equal_approx(director.variant_chance(), director.MAX_VARIANT_CHANCE), "la probabilidad tiene tope")
	director.round_number = 1

	print("== Otras mejoras")
	await reset()
	upgrades.grant(upgrades._card("focus_reserve"))
	check(is_equal_approx(upgrades.focus_capacity(), 140.0), "más Enfoque máximo")
	await reset()
	upgrades.grant(upgrades._card("long_cloak"))
	check(is_equal_approx(stealth._cloak_time(), 10.0), "Manto largo alarga la invisibilidad")

	print("== Balas de los fusileros")
	await reset()
	var rifle := await enemy_at(Vector2(2300, -2), "res://rifleman.gd")
	player.position = Vector2(2150, -2)
	await frames(2)
	aim_rifle(rifle)
	director.make_variant(rifle, "ice")
	rifle._fire()
	await frames(1)
	var bullet_shot: Area2D = get_nodes_in_group(&"projectiles")[-1]
	check(bullet_shot.style == "bullet" and bullet_shot.velocity.length() == load("res://pistol_shot.gd").SPEED, "disparan la bala de la pistola, a su velocidad")
	check(bullet_shot.element == "ice", "la variante le pasa su elemento")
	check(absf(angle_difference(bullet_shot.rotation, bullet_shot.velocity.angle())) < 0.001, "el trazador apunta hacia donde vuela")
	await frames(12)
	check(not is_instance_valid(bullet_shot) and player.current_health < player.max_health, "golpea a Viridy sin atravesarla (%d)" % player.current_health)
	check(player.ailments.slow_left > 0.0, "y le aplica el elemento")
	await reset()
	rifle = await enemy_at(Vector2(2300, -2), "res://rifleman.gd")
	aim_rifle(rifle)
	var thin := StaticBody2D.new()
	thin.collision_layer = 2
	var thin_shape := CollisionShape2D.new()
	thin_shape.shape = RectangleShape2D.new()
	thin_shape.shape.size = Vector2(4, 300)
	thin.add_child(thin_shape)
	thin.position = Vector2(2150, -100)
	player.get_parent().add_child(thin)
	await frames(2)
	rifle._fire()
	await frames(1)
	var blocked: Area2D = get_nodes_in_group(&"projectiles")[-1]
	await frames(14)
	check(not is_instance_valid(blocked) and player.current_health == player.max_health, "una pared fina la detiene")
	thin.queue_free()
	await reset()
	rifle = await enemy_at(Vector2(2300, -2), "res://rifleman.gd")
	player.position = Vector2(2100, -2)
	await frames(2)
	aim_rifle(rifle)
	player._start_roar()
	await frames(1)
	rifle._fire()
	await frames(1)
	var parried: Area2D = get_nodes_in_group(&"projectiles")[-1]
	await frames(8)
	check(player.current_health == player.max_health and (not is_instance_valid(parried) or parried.reflected), "el rugido la devuelve aunque venga tan rápida")
	await reset()
	rifle = await enemy_at(Vector2(2300, -2), "res://rifleman.gd")
	rifle.aim_direction = Vector2(-1, 0)
	rifle._fire()
	await frames(1)
	var returned: Area2D = get_nodes_in_group(&"projectiles")[-1]
	returned._reflect(player)
	var reflect_health: int = rifle.current_health
	check(returned.reflected and returned.velocity.length() <= returned.BULLET_MAX_SPEED + 0.01, "se puede devolver sin pasar de velocidad")
	await frames(24)
	check(rifle.current_health < reflect_health, "y golpea al fusilero")
	var orb: Area2D = load("res://projectile.gd").new()
	orb.velocity = Vector2(720, 0)
	player.get_parent().add_child(orb)
	await frames(1)
	orb._reflect(player)
	check(is_equal_approx(orb.velocity.length(), 1440.0), "los demás proyectiles siguen igual")
	orb.queue_free()

	print("== Alarma")
	await reset()
	stealth.begin_wave()
	player.position = Vector2(1500, -2)
	director._add_chaser(Vector2(4000, 0))
	director._add_chaser(Vector2(4100, 0))
	await frames(3)
	var spotter: Node = director.enemies[0].get_node("StealthAgent")
	var other: Node = director.enemies[1].get_node("StealthAgent")
	spotter.mode = spotter.Mode.ENGAGED
	await frames(20)
	var one_rate: float = stealth.level * 3.0
	check(one_rate > 0.75 and one_rate < 0.92, "un enemigo la llena en unos 1,2 s (%.2f por segundo)" % one_rate)
	stealth.level = 0.0
	other.mode = other.Mode.ENGAGED
	await frames(20)
	check(stealth.level * 3.0 > one_rate * 1.8, "cada enemigo más la acelera (%.2f por segundo)" % (stealth.level * 3.0))
	stealth.trigger_alarm()
	await frames(2)
	check(stealth.alarm_label.text == "ALARMA", "en alarma solo dice ALARMA")
	check(stealth.alarm_fill.get_global_rect().position.y > stealth.alarm_label.get_global_rect().position.y + 10.0, "la barra va debajo del texto")
	stealth.stand_down()

	print("== Conos de visión")
	await reset()
	stealth.begin_wave()
	director._add_chaser(player.global_position + Vector2(800, 0))
	await frames(3)
	var drawn: Node2D = director.enemies[0].get_node("StealthAgent")
	check(not player.show_hitbox_debug, "sin hitboxes activas")
	check(not _cone_visible(drawn), "los conos no se dibujan")
	player.toggle_hitbox_debug()
	check(_cone_visible(drawn), "con H sí")
	player.toggle_hitbox_debug()
	stealth.stand_down()

	print("== Estilo: SSS cuesta más")
	await reset()
	style._set_points(400.0)
	var climb := 0
	var hits := 0
	while style.rank < 6 and climb < 1800:
		if climb % 36 == 0:
			style.add("heavy_hit", 18.0, "")
			hits += 1
		if climb % 180 == 0:
			style.add("ruby_execution", 50.0, "")
		await frames(1)
		climb += 1
	print("  frames de S a SSS con combate constante: %d" % climb)
	check(climb > 360, "con combate constante, de S a SSS tarda más de 6 s (%.1f s)" % (climb / 60.0))
	check(style.rank == 6, "pero se puede")
	await reset()
	style._set_points(450.0)
	for _i in range(4):
		style.add("heavy_hit", 18.0, "")
		await frames(60)
	check(style.points < 480.0, "un golpe por segundo apenas sube en S (%.0f)" % style.points)
	await reset()
	style._set_points(560.0)
	for _i in range(4):
		style.add("heavy_hit", 18.0, "")
		await frames(60)
	check(style.points < 560.0, "y en SS ya no alcanza (%.0f)" % style.points)
	await reset()
	style._set_points(560.0)
	for _i in range(60):
		style.update_airtime(1.0 / 60.0, false, false)
		style.add_speed(1.0 / 60.0, 1240, 560)
		style.add_running(1.0 / 60.0)
		await frames(1)
	check(style.points < 540.0, "volar y correr ya no sostienen SS (%.0f)" % style.points)
	await reset()
	style._set_points(150.0)
	var gain_low: float = style.points
	style.add("test_low", 20.0, "")
	gain_low = style.points - gain_low
	style._set_points(550.0)
	var gain_high: float = style.points
	style.add("test_high", 20.0, "")
	gain_high = style.points - gain_high
	check(is_equal_approx(gain_low, 20.0) and gain_high < gain_low * 0.7, "las ganancias rinden menos arriba (%.0f → %.0f)" % [gain_low, gain_high])

	await reset()
	print("RESULTADO: %d/%d" % [checks - fails, checks])
	quit(1 if fails > 0 else 0)

func _cone_visible(agent: Node2D) -> bool:
	# La misma condición que corta el _draw del agente.
	return not (agent.enemy == null or not agent.enemy.visible or agent.is_aware() or agent.director.player == null or agent.director.alarm_active() or not agent.director.player.show_hitbox_debug)
