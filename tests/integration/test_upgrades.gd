extends SceneTree

# Rubíes y mejoras del Gauntlet: recolección por cadena, guardián, pantalla de mejoras, tienda y cada mejora.
var checks := 0
var fails := 0
var director: Node
var stealth: Node2D
var player: CharacterBody2D
var upgrades: Node
var style: Node
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
	# Sin agente de sigilo ni IA: un blanco quieto.
	var enemy: Area2D = load(script_path).new()
	enemy.position = at
	enemy.max_health = 40
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
	upgrades.begin_run()
	style.reset()
	player._respawn_player()
	player.position = Vector2(2000, -2)
	await frames(4)

func execute(enemy: Area2D) -> void:
	enemy.take_hit(player.global_position, 1, 999)
	player.attack_mode = player.ATTACK_HEAVY_GROUND
	player.attack_targets_hit.clear()
	player._hit_area(enemy)
	for _i in range(90):
		await frames(1)
		if player.execution_core == null:
			break
	player.attack_mode = player.ATTACK_NONE

func _run() -> void:
	upgrades = root.get_node("Upgrades")
	style = root.get_node("Ferocity")
	root.add_child(load("res://gauntlet.tscn").instantiate())
	await frames(10)
	director = get_first_node_in_group(&"gauntlet_director")
	stealth = get_first_node_in_group(&"stealth_director")
	player = get_first_node_in_group(&"player")
	director._clear_wave()
	stealth.stand_down()
	check(upgrades.active, "el Gauntlet activa los rubíes")

	print("== Rubíes: cada eslabón de la cadena da uno más")
	await reset()
	for expected in [1, 3, 6]:
		var target := await enemy_at(player.global_position + Vector2(60, 0))
		await execute(target)
		check(upgrades.rubies == expected, "total %d tras la cadena x%d" % [upgrades.rubies, player.execution_chain])
	player.execution_chain_timer = 0.01
	await frames(2)
	var target := await enemy_at(player.global_position + Vector2(60, 0))
	await execute(target)
	check(upgrades.rubies == 7, "cadena cortada: vuelve a dar 1 (%d)" % upgrades.rubies)
	check(upgrades.chain_rubies(4, true) == 10, "un guardián da 10")
	var before: int = upgrades.rubies
	player.register_execution(true)
	check(upgrades.rubies == before + 10, "al ejecutarlo suma 10")
	check(director.rubies_label.text == "RUBÍES: %d" % upgrades.rubies, "el HUD muestra el contador")

	print("== Cartas")
	await reset()
	var offers: Array = upgrades.offers(3)
	var keys: Array = offers.map(func(card): return card["key"])
	check(offers.size() == 3 and keys[0] != keys[1] and keys[1] != keys[2] and keys[0] != keys[2], "3 cartas distintas %s" % [keys])
	var element_card: Dictionary = upgrades._element_card("fire", "uppercut")
	upgrades.grant(element_card)
	check(upgrades.element_for("uppercut") == "fire", "un elemento se asigna a un tipo de ataque")
	check(upgrades.offers(30).all(func(card): return card.get("slot", "") != "uppercut"), "ese tipo de ataque ya no se ofrece")
	upgrades.grant(upgrades._card("spear_pierce"))
	check(upgrades.offers(30).any(func(card): return card["key"] == "spear_pierce"), "la punta perforante se acumula")
	upgrades.grant(upgrades._card("pistol"))
	check(not upgrades.offers(30).any(func(card): return card["key"] == "pistol"), "una mejora única no se repite")

	print("== Pantalla de mejoras y tienda")
	await reset()
	upgrades.add_rubies(20)
	director.phase = director.Phase.BOSS
	director.on_bosses_defeated()
	check(director.phase == director.Phase.REWARD and director.portals.is_empty(), "al ganar aún no hay portales")
	await frames(110)
	var menu: CanvasLayer = director.upgrade_menu
	check(menu.is_open() and paused, "se abre la pantalla y pausa")
	check(menu.stage == menu.Stage.FREE and menu.cards.size() == 3, "tres cartas gratis")
	check(root.gui_get_focus_owner() != null, "con foco para el mando")
	check(not menu.continue_button.visible, "la gratis no se puede saltar")
	var first_cards: Array = menu.cards.map(func(card): return card["key"])
	menu.reroll()
	check(upgrades.rubies == 15, "el reroll cuesta 5 (%d)" % upgrades.rubies)
	check(menu.cards.size() == 3, "reroll da tres cartas nuevas (antes %s)" % [first_cards])
	var pick: Dictionary = menu.cards[0]
	menu.choose(0)
	check(upgrades.rubies == 15, "la mejora elegida es gratis")
	check(menu.stage == menu.Stage.SHOP and menu.continue_button.visible, "después viene la tienda")
	check(not menu.cards.any(func(card): return card["key"] == pick["key"] and card["id"] != "element" and not card.get("max", false) and pick["id"] != "spear_pierce"), "la tienda no repite la elegida")
	var price: int = menu.cards[0]["price"]
	menu.choose(0)
	check(upgrades.rubies == 15 - price, "comprar descuenta el precio (%d)" % upgrades.rubies)
	menu.choose(0)
	check(upgrades.rubies == 15 - price, "no se compra dos veces")
	upgrades.rubies = 1
	var dear: Dictionary = menu.cards[1]
	var owned_before: int = upgrades.owned.size() + upgrades.element_slots.size()
	menu.choose(1)
	check(upgrades.owned.size() + upgrades.element_slots.size() == owned_before, "sin rubíes no se puede comprar %s" % dear["title"])
	menu.close()
	await frames(4)
	check(not paused and director.phase == director.Phase.PORTALS and director.portals.size() == 2, "al continuar aparecen los portales")
	director._clear_portals()

	print("== Flips invulnerables")
	await reset()
	var health: int = player.current_health
	player.backflip_active = true
	player.backflip_elapsed = 0.0
	player.backflip_rotation_duration = 0.5
	player.take_damage(10, Vector2.ZERO)
	check(player.current_health == health - 10, "sin la mejora el backflip recibe daño")
	await reset()
	health = player.current_health
	upgrades.grant(upgrades._card("backflip_iframes"))
	player.backflip_active = true
	player.backflip_elapsed = 0.0
	player.backflip_rotation_duration = 0.5
	player.take_damage(10, Vector2.ZERO)
	check(player.current_health == health, "con la mejora, invulnerable al girar")
	player.backflip_elapsed = 0.6
	player.take_damage(10, Vector2.ZERO)
	check(player.current_health == health - 10, "solo mientras gira")
	player.backflip_active = false
	await reset()
	health = player.current_health
	upgrades.grant(upgrades._card("frontflip_iframes"))
	player.frontflip_active = true
	player.frontflip_elapsed = 0.0
	player.frontflip_rotation_duration = 0.5
	check(not player.can_be_pinned(), "el sabueso tampoco la atrapa en el flip")
	player.take_damage(10, Vector2.ZERO)
	check(player.current_health == health, "el frontflip también")
	player.frontflip_active = false

	print("== Lanza: fuego y perforar")
	await reset()
	upgrades.grant(upgrades._card("spear_burn"))
	var burned := await enemy_at(Vector2(2200, 0))
	var life: int = burned.current_health
	player._throw_spear()
	player.thrown_knife.global_position = burned.global_position + burned.impact_offset
	player.thrown_knife._stick_in_enemy(burned)
	check(burned.get_node("ElementStatus").burn_left > 0.0, "la lanza prende fuego")
	await frames(100)
	check(burned.current_health < life, "el fuego hace daño en el tiempo (%d → %d)" % [life, burned.current_health])
	await reset()
	upgrades.grant(upgrades._card("spear_pierce"))
	var front := await enemy_at(Vector2(2200, -30))
	var behind := await enemy_at(Vector2(2300, -30))
	var knife: Node2D = load("res://knife.gd").new()
	player.get_parent().add_child(knife)
	knife.launch(player, Vector2(2150, -56), Vector2(1300, 0))
	knife.straight_timer = 1.0
	check(knife.recall_damage == 3, "aumenta el daño del recall")
	await frames(20)
	check(front.current_health < 40, "atraviesa al primero haciéndole daño")
	check(knife.target == behind, "y se clava en el siguiente")
	knife.queue_free()

	print("== Pistola")
	await reset()
	upgrades.grant(upgrades._card("pistol"))
	var shot_target := await enemy_at(Vector2(2300, -2))
	player.combo.aim_direction = Vector2(1, 0).rotated(-0.02)
	player._throw_spear()
	check(player.has_knife and player.thrown_knife == null, "dispara sin soltar la lanza")
	check(player.jade_fire_cooldown_timer > 0.0 and player.jade_fire_cooldown_timer < 0.5, "con cadencia corta")
	await frames(16)
	check(shot_target.current_health == 37, "la bala golpea (%d)" % shot_target.current_health)

	print("== Estampida en SSS")
	await reset()
	upgrades.grant(upgrades._card("sss_run"))
	var runner := await enemy_at(player.global_position + Vector2(10, 0))
	var runner_life: int = runner.current_health
	player.is_sprinting = true
	style.rank = 3
	player._update_stampede()
	check(runner.current_health == runner_life, "fuera de SSS no daña")
	style._set_points(650.0)
	player._update_stampede()
	var hit_life: int = runner.current_health
	check(hit_life < runner_life, "corriendo en SSS daña al atravesar (%d)" % (runner_life - hit_life))
	player._update_stampede()
	check(runner.current_health == hit_life, "no golpea cada frame")
	player.is_sprinting = false

	print("== Screw reflector")
	await reset()
	var shot: Area2D = load("res://projectile.gd").new()
	shot.velocity = Vector2(-300, 0)
	player.get_parent().add_child(shot)
	shot.global_position = player.global_position + Vector2(30, -26)
	player.attack_mode = player.ATTACK_SPIN
	player._destroy_projectiles_with_attack()
	check(not shot.reflected, "sin la mejora no devuelve")
	upgrades.grant(upgrades._card("screw_reflect"))
	var durability: float = player.shine_durability
	player._destroy_projectiles_with_attack()
	check(shot.reflected, "con la mejora devuelve el proyectil")
	check(is_equal_approx(player.shine_durability, durability), "sin gastar durabilidad")
	player.attack_mode = player.ATTACK_NONE
	shot.queue_free()

	print("== Electricidad")
	await reset()
	upgrades.grant(upgrades._element_card("electric", "light"))
	var main_enemy := await enemy_at(Vector2(2200, 0))
	var side_enemy := await enemy_at(Vector2(2300, 0))
	var damage: int = upgrades.strike(main_enemy, "light", 4)
	check(damage > 4, "más daño, y más aún contra máquinas (%d)" % damage)
	check(side_enemy.current_health < 40, "el daño salta al cercano")
	check(upgrades.strike(main_enemy, "uppercut", 4) == 4, "solo en el tipo de ataque elegido")
	upgrades.strike(main_enemy, "light", 4)
	upgrades.strike(main_enemy, "light", 4)
	check(main_enemy.ruby_core.stagger_left > 0.9, "3 marcas aturden")
	check(side_enemy.ruby_core.stagger_left > 0.9, "el aturdimiento también salta")

	print("== Fuego")
	await reset()
	upgrades.grant(upgrades._element_card("fire", "heavy"))
	var machine := await enemy_at(Vector2(2200, 0))
	check(upgrades.strike(machine, "heavy", 4) == 4, "contra máquinas, daño normal")
	var beast: Area2D = load("res://hawk.gd").new()
	beast.position = Vector2(2400, -200)
	player.get_parent().add_child(beast)
	spawned.append(beast)
	await frames(2)
	beast.set_physics_process(false)
	check(upgrades.strike(beast, "heavy", 4) == 6, "contra bestias, más daño")
	var stinger: Area2D = load("res://stinger.gd").new()
	check(upgrades.kind_of(stinger) == &"machine", "los drones son máquinas")
	stinger.free()
	machine.current_health = 1
	await frames(60)
	check(machine.ruby_core.dying, "el fuego puede dejarlo en DYING")

	print("== Hielo")
	await reset()
	upgrades.grant(upgrades._element_card("ice", "light"))
	var frozen := await enemy_at(Vector2(2200, 0))
	upgrades.strike(frozen, "light", 2)
	var status: Node = frozen.get_node("ElementStatus")
	check(status.ice_stacks == 1 and status.slow_left > 2.0, "ralentiza y acumula")
	await frames(2)
	var skipped := [frozen.ruby_core.slow_skip]
	await frames(1)
	skipped.append(frozen.ruby_core.slow_skip)
	check(skipped[0] != skipped[1], "se salta un tick de cada dos")
	upgrades.strike(frozen, "light", 2)
	upgrades.strike(frozen, "light", 2)
	check(status.is_frozen() and frozen.ruby_core.holds_actor(), "con 3 queda congelado")
	check(upgrades.strike(frozen, "heavy", 5, false) == 5, "un pesado de suelo no lo rompe")
	var shattered: int = upgrades.strike(frozen, "heavy", 5, true)
	check(shattered >= 20, "un pesado aéreo rompe el hielo y pega mucho (%d)" % shattered)
	check(not status.is_frozen() and status.ice_cooldown > 0.0, "queda en enfriamiento")
	upgrades.strike(frozen, "light", 2)
	check(status.ice_stacks == 0, "no acumula durante el enfriamiento")

	print("== Aliados espirituales")
	await reset()
	upgrades.grant(upgrades._card("spirit_hawk"))
	upgrades.grant(upgrades._card("spirit_hound"))
	director._sync_allies()
	await frames(3)
	var hawk: Node2D = director.allies["spirit_hawk"]
	var hound: Node2D = director.allies["spirit_hound"]
	check(is_instance_valid(hawk) and is_instance_valid(hound), "aparecen al comprarlos")
	var quiet := await enemy_at(player.global_position + Vector2(200, 0))
	quiet.set_meta(&"stealth_agent", true)
	var quiet_agent: Node2D = load("res://stealth_agent.gd").new()
	quiet.add_child(quiet_agent)
	stealth.running = true
	# De espaldas a Viridy desde antes de su primer tick: no la descubre.
	quiet_agent._bind()
	quiet_agent.timer = 999.0
	quiet_agent._turn(1)
	await frames(30)
	check(quiet_agent.mode == quiet_agent.Mode.UNAWARE and quiet.current_health == 40, "no atacan a quien no la ha visto")
	quiet_agent.mode = quiet_agent.Mode.ENGAGED
	await frames(100)
	check(quiet.current_health < 40, "atacan a los enemigos en alerta (%d)" % quiet.current_health)
	check(hound.mode == hound.Mode.PIN or hound.cooldown > 0.0, "el sabueso lo inmoviliza")
	check(quiet.ruby_core.stagger_left > 0.0 or hound.cooldown > 0.0, "queda aturdido")
	hawk.hurt(99)
	check(not hawk.visible and hawk.respawn_left > 0.0, "el halcón puede morir")
	hawk.respawn_left = 0.02
	await frames(3)
	check(hawk.visible and hawk.health == hawk.max_health, "y reaparece")
	var enemy_shot: Area2D = load("res://projectile.gd").new()
	player.get_parent().add_child(enemy_shot)
	enemy_shot.velocity = Vector2.ZERO
	enemy_shot.global_position = hound.global_position
	var hound_health: int = hound.health
	await frames(3)
	check(hound.health < hound_health, "los proyectiles los dañan")
	stealth.running = false

	print("RESULTADO: %d/%d" % [checks - fails, checks])
	quit(1 if fails else 0)
