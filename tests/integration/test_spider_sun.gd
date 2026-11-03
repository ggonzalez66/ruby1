extends SceneTree

# Pedido del 2026-11-03: efectos remasterizados con PixelFX, cámaras destructibles (estilo sin rubíes),
# la Araña Colosal tras el trío de la Torre (4 rubíes en las patas, núcleo central protegido, sin
# aturdirse, esbirros una vez al desplomarse), el mundo espiritual del sol (6 pisos de plataformeo, lava
# que devuelve al checkpoint, plataformas que caen, rebotes y un piso para el Ruby) y la mejora
# "Ira encadenada" de la Ira de la Naturaleza.
var checks := 0
var fails := 0
var upgrades: Node

func _initialize() -> void:
	_run.call_deferred()

func frames(count: int) -> void:
	for _i in range(count):
		await physics_frame

func check(ok: bool, label: String) -> void:
	checks += 1
	fails += 0 if ok else 1
	print("  OK   " if ok else "  FAIL ", label)

func open(path: String) -> void:
	change_scene_to_file(path)
	for _i in range(60):
		await frames(1)
		if current_scene != null and current_scene.scene_file_path == path:
			break
	await frames(10)

func player() -> CharacterBody2D:
	return get_first_node_in_group(&"player")

func pixel_sprites(parent: Node, sheet: String) -> Array:
	return parent.get_children().filter(func(n): return n is AnimatedSprite2D and String(n.name).begins_with("PixelFx_" + sheet))

func _run() -> void:
	root.size = Vector2i(1152, 648)
	upgrades = root.get_node("Upgrades")
	await pixel_fx()
	await cameras()
	await spider()
	await sun_world()
	await wrath_chain()
	print("RESULTADO: %d/%d" % [checks - fails, checks])
	quit(1 if fails else 0)

func pixel_fx() -> void:
	print("== PixelFX")
	await open("res://factory_boss.tscn")
	get_first_node_in_group(&"gauntlet_director").set_physics_process(false)
	var level := current_scene
	var data: Script = load("res://pixel_fx_data.gd")
	var missing := []
	for sheet in data.SHEETS:
		if not ResourceLoader.exists("res://assets/fx/pixelfx/%s.png" % sheet):
			missing.append(sheet)
	check(data.SHEETS.size() >= 15 and missing.is_empty(), "%d hojas de PixelFX importadas (faltan: %s)" % [data.SHEETS.size(), missing])
	check(FileAccess.file_exists("res://assets/fx/pixelfx/LICENSE-pixelfx.txt"), "la licencia MIT de PixelFX viaja con las hojas")
	Fx.impact(level, Vector2(800, -200), Fx.GOLD, 2.0)
	var sparks := pixel_sprites(level, "hit_spark")
	check(sparks.size() == 1 and sparks[0].material is ShaderMaterial and sparks[0].texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "un impacto es una chispa de PixelFX teñida y en pixel art")
	check(pixel_sprites(level, "hit_heavy").size() == 1, "los golpes fuertes suman el impacto contundente")
	var gold: Color = sparks[0].material.get_shader_parameter("mid")
	check(gold.is_equal_approx(Fx.GOLD[1]), "la hoja gris toma la paleta del golpe")
	Fx.explosion(level, Vector2(900, -100))
	check(pixel_sprites(level, "explosion").size() == 1 and pixel_sprites(level, "explosion")[0].material == null, "las explosiones conservan sus colores de fuego")
	Fx.heal(player())
	check(pixel_sprites(player(), "heal").size() == 1, "la curación sigue a Viridy")
	await frames(90)
	check(pixel_sprites(level, "hit_spark").is_empty(), "los efectos se borran solos al terminar")
	await frames(60)
	var healed_before := pixel_sprites(player(), "heal").size()
	player().current_health = 50
	player().heal(10)
	check(pixel_sprites(player(), "heal").size() == healed_before + 1, "curarse muestra el anillo de curación")

func cameras() -> void:
	print("== Cámaras destructibles")
	await open("res://factory_outdoor.tscn")
	var director: Node = get_first_node_in_group(&"gauntlet_director")
	var stealth: Node = get_first_node_in_group(&"stealth_director")
	await frames(5)
	for enemy in director.enemies:
		if is_instance_valid(enemy):
			enemy.global_position = Vector2(80, -2000)
			enemy.process_mode = Node.PROCESS_MODE_DISABLED
	var camera: Area2D = current_scene.get_node("CameraDoor")
	check(camera.collision_layer == 8 and camera.monitorable, "la cámara tiene hurtbox en la capa de los enemigos")
	# Lejos del cono, para romperla sin que la vea.
	for other in get_nodes_in_group(&"security_cameras"):
		other.aim_angle = -30.0
		other.sweep = 0.0
		other.angle = deg_to_rad(-30.0)
	player().global_position = Vector2(3250, -2)
	await frames(3)
	stealth._clear_alert()
	var rubies: int = upgrades.rubies
	var style: Node = root.get_node("Ferocity")
	var points: float = style.points
	camera.take_hit(player().global_position, 1, 1)
	camera.take_hit(player().global_position, 1, 1)
	check(not camera.destroyed, "aguanta un par de golpes")
	camera.take_hit(player().global_position, 1, 1)
	check(camera.destroyed, "al tercer golpe se rompe")
	check(upgrades.rubies == rubies and style.points > points, "romperla da estilo pero no rubíes")
	check(not stealth.alarm_active() and stealth.level == 0.0, "romperla no alerta a los guardias")
	# Rota, ya no ve aunque apunte a Viridy.
	camera.aim_angle = rad_to_deg((player().global_position + Vector2(0, -40) - camera.global_position).angle())
	camera.angle = deg_to_rad(camera.aim_angle)
	await frames(40)
	check(not camera.spotting and stealth.level == 0.0 and not camera.monitorable, "una cámara rota no ve ni recibe más golpes")

func kill_trio(director: Node) -> void:
	director.phase_timer = 0.0
	await frames(30)
	for boss in get_nodes_in_group(&"boss"):
		boss.take_hit(Vector2.ZERO, 1, 9999)
		boss.ruby_core.claim(player())
		boss.ruby_core.complete(player())

func spider() -> void:
	print("== La Araña Colosal")
	await open("res://tower_finale.tscn")
	var director: Node = get_first_node_in_group(&"gauntlet_director")
	await frames(40)
	# Los tres caen a la vez: sus avisos no deben saltarse la araña.
	await kill_trio(director)
	await frames(130)
	check(director.spider_called and not is_instance_valid(director.sun), "vencido el trío no aparece el sol: llega la araña")
	await frames(200)
	var boss: Area2D = get_first_node_in_group(&"spider_boss")
	check(boss != null and get_nodes_in_group(&"spider_boss").size() == 1, "aparece una sola araña")
	if boss == null:
		return
	check(boss.legs.size() == 4 and boss.legs_alive() == 4, "cuatro patas con su ruby")
	var leg_cores: Array = boss.legs.filter(func(leg): return leg.get_node_or_null("RubyCore") != null)
	check(leg_cores.size() == 4 and boss.ruby_core.get_script() == load("res://spider_core.gd"), "cinco rubíes: uno por pata y el central")
	player().global_position = boss.global_position + Vector2(-700, -2)
	player().current_health = 100
	var health: int = boss.current_health
	boss.take_hit(player().global_position, 1, 50)
	check(boss.current_health == health, "el ruby central está protegido mientras quedan patas")
	check(not boss.ruby_core.claim_wrath(player()), "ni la ultimate lo arranca con patas")
	check(not boss.ruby_core.register_parry(1) and is_equal_approx(boss.ruby_core.posture, boss.ruby_core.POSTURE_MAX), "los parries no le bajan la postura")
	boss.ruby_core.stagger(2.0)
	check(boss.ruby_core.stagger_left == 0.0, "no se aturde")

	print("== Ataques")
	boss.ruby_core.spawn_grace_left = 0.0
	boss.combat_started = true
	# Estocada: Viridy quieta donde la clava.
	player().global_position = boss.global_position + Vector2(-380, -2)
	await frames(2)
	boss._start_stab_windup(player())
	var stabbed := false
	for _i in range(120):
		await frames(1)
		player().global_position = boss.global_position + Vector2(-380, -2)
		if player().current_health < 100:
			stabbed = true
			break
	check(stabbed, "la estocada de una pata hiere (%d)" % player().current_health)
	# Con parry la estocada no hace daño y la araña sigue igual.
	player().current_health = 100
	player().invulnerability_timer = 0.0
	await frames(70)
	boss.state = boss.State.IDLE
	boss.state_timer = 99.0
	player().global_position = boss.global_position + Vector2(-380, -2)
	await frames(10)
	boss._start_stab_windup(player())
	for _i in range(int(boss.stab_windup * 60.0) - 4):
		await frames(1)
	Input.action_press("roar")
	var parried := false
	for _i in range(30):
		await frames(1)
		if boss.state == boss.State.RECOVER:
			parried = player().current_health == 100
			break
	Input.action_release("roar")
	check(parried and boss.ruby_core.stagger_left == 0.0, "el parry anula la estocada sin aturdirla")
	# Railgun: tres disparos.
	await frames(70)
	player().invulnerability_timer = 0.0
	player().current_health = 100
	boss.state = boss.State.IDLE
	boss.rail_cooldown = 0.0
	boss._start_rail()
	var shots := 0
	var last_left: int = boss.shots_left
	for _i in range(400):
		await frames(1)
		if boss.shots_left < last_left:
			shots += last_left - boss.shots_left
			last_left = boss.shots_left
		if boss.state == boss.State.RECOVER:
			break
	check(shots == 3, "la railgun fija y dispara tres veces (%d)" % shots)
	# Arremetida: avanza a toda velocidad.
	await frames(80)
	boss.state = boss.State.IDLE
	player().global_position = boss.global_position + Vector2(-900, -2)
	boss.facing = -1
	var start_x: float = boss.global_position.x
	boss._start_windup(boss.State.CHARGE_WINDUP, boss.charge_windup, "")
	await frames(int(boss.charge_windup * 60.0) + 40)
	check(start_x - boss.global_position.x > 300.0, "la arremetida la lanza hacia delante (%.0f px)" % (start_x - boss.global_position.x))

	print("== Rubíes de las patas")
	boss.state = boss.State.IDLE
	boss.state_timer = 99.0
	player().current_health = 50
	var leg: Area2D = boss.legs[0]
	leg.take_hit(player().global_position, 1, 999)
	check(leg.ruby_core.dying and leg.ruby_core.is_executable(), "a cero, el ruby de la pata queda expuesto")
	check(leg.ruby_core.claim(player()), "se reclama con un pesado")
	leg.ruby_core.complete(player())
	await frames(3)
	check(leg.broken and boss.legs_alive() == 3, "ejecutarlo rompe la pata")
	for other in boss.legs.slice(1):
		other.take_hit(Vector2.ZERO, 1, 999)
		other.ruby_core._expire_dying()
	await frames(100)
	check(boss.collapsed, "sin patas se desploma")
	var minions := get_nodes_in_group(&"spider_minions").size()
	check(minions == boss.minion_count, "llama esbirros pequeños (%d)" % minions)
	boss._call_minions()
	await frames(3)
	check(get_nodes_in_group(&"spider_minions").size() == minions, "los esbirros llegan una sola vez")
	health = boss.current_health
	boss.take_hit(player().global_position, 1, 5)
	check(boss.current_health == health - 5, "desplomada, el ruby central ya recibe daño")
	boss.take_hit(player().global_position, 1, 9999)
	check(boss.ruby_core.final_open and not boss.defeated, "a cero no muere: hay que romper el ruby central")
	boss.ruby_core.claim(player())
	boss.ruby_core.complete(player())
	check(boss.defeated, "romper el ruby central la vence")
	await frames(130)
	check(is_instance_valid(director.sun), "vencida la araña aparece el sol")

func sun_world() -> void:
	print("== El mundo del sol")
	check(load("res://run_state.gd").PARKOUR_SCENE == "res://sun_world.tscn", "el sol lleva al mundo espiritual")
	await open("res://sun_world.tscn")
	var level := current_scene
	var checkpoints := get_nodes_in_group(&"checkpoints")
	var floors := {}
	for checkpoint in checkpoints:
		floors[int(round(-checkpoint.global_position.y / 640.0))] = true
	check(floors.size() >= 7, "seis pisos de plataformeo y el del Ruby (%d pisos con checkpoint)" % floors.size())
	var ruby: Node2D = level.get_node("Ruby1")
	var top_y := 0.0
	for checkpoint in checkpoints:
		top_y = minf(top_y, checkpoint.global_position.y)
	check(is_equal_approx(ruby.global_position.x, 1600.0) and ruby.global_position.y < top_y, "el Ruby, en el centro del último piso")
	var thorns: Array = level.get_children().filter(func(n): return n.get_script() == load("res://hazard.gd"))
	var lava := get_nodes_in_group(&"lava")
	check(thorns.is_empty() and lava.size() >= 6, "sin pinchos: %d tramos de lava y géiseres" % lava.size())
	check(get_nodes_in_group(&"falling_platforms").size() >= 20, "plataformas que se caen (%d)" % get_nodes_in_group(&"falling_platforms").size())
	var spirits: Array = get_nodes_in_group(&"training_dummies").filter(func(n): return n.aerial)
	check(spirits.size() >= 18, "espíritus para rebotar (%d)" % spirits.size())
	# La lava devuelve al checkpoint sin quitar vida.
	var hero := player()
	await frames(5)
	hero.current_health = 100
	var pool: Area2D = lava.filter(func(n): return n.get_script() == load("res://lava.gd"))[0]
	hero.global_position = pool.global_position + Vector2(0, 30)
	await frames(4)
	check(hero.global_position.distance_to(hero.spawn_position) < 2.0 and hero.current_health == 100, "la lava te devuelve al checkpoint sin quitar vida")
	# Una plataforma que cae.
	var platform: StaticBody2D = get_nodes_in_group(&"falling_platforms")[0]
	hero.global_position = platform.global_position + Vector2(0, -20)
	hero.velocity = Vector2.ZERO
	await frames(10)
	check(platform.timer > 0.0 or platform.fallen, "pisarla la hace temblar")
	await frames(60)
	check(platform.fallen and platform.collision.disabled, "y luego cae")
	await frames(int((platform.respawn_time + 1.2) * 60.0))
	check(not platform.fallen and platform.position.is_equal_approx(platform.home), "al rato reaparece en su sitio")

func wrath_chain() -> void:
	print("== Ira encadenada")
	check(upgrades.CATALOG.has("wrath_chain"), "la mejora está en el catálogo")
	await open("res://factory_boss.tscn")
	get_first_node_in_group(&"gauntlet_director").set_physics_process(false)
	var level := current_scene
	var hero := player()
	hero.global_position = Vector2(600, -2)
	var style: Node = root.get_node("Ferocity")
	var wrath: Node2D = hero.wrath
	var make := func(at: Vector2, aerial: bool = false) -> Node2D:
		var target: Node2D = load("res://training_dummy.tscn").instantiate()
		target.max_health = 100
		target.aerial = aerial
		target.position = at
		level.add_child(target)
		return target
	var first: Node2D = make.call(Vector2(800, -2))
	var second: Node2D = make.call(Vector2(300, -500), true)
	await frames(5)
	upgrades.owned["wrath_chain"] = 1
	style._set_points(650)
	wrath.arm()
	check(wrath.launch(Vector2.RIGHT), "se lanza")
	var stopped := false
	for _i in range(40):
		await frames(1)
		if wrath.state == wrath.State.AIM:
			stopped = true
			break
	check(stopped and wrath.chain_count == 1 and wrath.captured.size() == 1, "al morder un enemigo se detiene a elegir otra dirección")
	# El segundo, justo encima de donde se detuvo.
	second.anchor_position = hero.global_position + Vector2(0, -260)
	Input.action_press("move_up")
	for _i in range(40):
		await frames(1)
		if wrath.state == wrath.State.RUSH:
			break
	Input.action_release("move_up")
	check(wrath.state in [wrath.State.RUSH, wrath.State.AIM] and wrath.direction.is_equal_approx(Vector2.UP), "se relanza en la nueva dirección")
	check(wrath.current_speed > wrath.rush_speed * 1.2, "cada relanzamiento va más rápido (%.0f)" % wrath.current_speed)
	for _i in range(120):
		await frames(1)
		if wrath.state == wrath.State.IDLE:
			break
	check(not first.visible and not second.visible, "al final rompe a todos los mordidos")
	# Manteniendo el ataque ligero pasa de largo.
	await frames(30)
	hero.global_position = Vector2(600, -2)
	var third: Node2D = make.call(Vector2(800, -2))
	await frames(5)
	style._set_points(650)
	wrath.arm()
	Input.action_press("attack")
	wrath.launch(Vector2.RIGHT)
	var paused := false
	for _i in range(30):
		await frames(1)
		if wrath.state == wrath.State.AIM:
			paused = true
	Input.action_release("attack")
	check(not paused and wrath.chain_count == 0, "con el ligero apretado atraviesa sin detenerse")
	for _i in range(120):
		await frames(1)
		if wrath.state == wrath.State.IDLE:
			break
	check(not third.visible, "y lo rompe igual al terminar")
	upgrades.owned.erase("wrath_chain")
