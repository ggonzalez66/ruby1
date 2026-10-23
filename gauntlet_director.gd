extends Node2D

# Director del Gauntlet por oleadas. Cada ronda:
# 1. Oleada de enemigos normales: hay que matarlos a todos. Perseguidores y tiradores; desde la ronda 2
#    también escuderos y halcones, y desde la 3 enemigos en las plataformas altas (más arriba cada ronda).
# 2. Con todos muertos, se prepara el guardián (a veces salen los tres) y aparece.
# 3. Al vencerlo aparecen dos portales: el de la derecha sigue a la siguiente ronda; el de la izquierda
#    termina el Gauntlet y muestra la pantalla de fin con las medallas.
# Si Rengar muere se acaba: tras un momento aparece la pantalla de fin con las oleadas sobrevividas y
# "Empezar de nuevo" (sin checkpoint, y la tecla de reinicio no funciona, para que no haya trampa).
# Junto al reloj se muestra la oleada actual y los enemigos que quedan por matar.

const CHASER_SCRIPT := preload("res://chaser_dummy.gd")
const DUMMY_SCENE := preload("res://training_dummy.tscn")
const PORTAL_SCRIPT := preload("res://portal.gd")
const HAWK_SCRIPT := preload("res://hawk.gd")
const SHIELD_SCRIPT := preload("res://shield_bearer.gd")
# Plataformas altas de la arena donde aparecen enemigos en las oleadas mayores: [x, altura del suelo de
# la plataforma respecto al suelo, piso (1 = la más baja)].
const UPPER_SPOTS := [
	[1930.0, -330.0, 2], [3120.0, -320.0, 2],
	[2680.0, -480.0, 3], [3560.0, -480.0, 3],
	[2380.0, -640.0, 4], [3120.0, -640.0, 4], [3860.0, -640.0, 4],
	[2700.0, -800.0, 5], [3540.0, -800.0, 5],
	[3100.0, -960.0, 6], [2370.0, -960.0, 6], [3870.0, -960.0, 6],
	[2690.0, -1120.0, 7], [3550.0, -1120.0, 7],
	[2980.0, -1280.0, 8],
]

enum Phase { WAVE, BOSS_INTRO, BOSS, PORTALS, DONE }

@export var arena_min_x := 1400.0
@export var arena_max_x := 4100.0
@export var ground_y := 0.0
@export var spawner_path: NodePath
@export var boss_intro_time := 2.5
@export var left_portal_x := 600.0
@export var right_portal_x := 4150.0
@export var death_screen_delay := 2.5
@export var spawn_grace_time := 2.0

var round_number := 1
var phase := Phase.WAVE
var phase_timer := 0.0
var enemies: Array = []
var portals: Array = []
var spawner: Node
var banner: Label
var banner_tween: Tween
var counter_label: Label
# Rondas completadas (oleada + guardián vencidos).
var rounds_cleared := 0
var spawn_grace_left := 0.0

func _ready() -> void:
	add_to_group(&"gauntlet_director")
	spawner = get_node(spawner_path)
	_build_banner()
	_start.call_deferred()

func _start() -> void:
	var player := get_tree().get_first_node_in_group(&"player")
	if player:
		player.respawn_enabled = false
		player.died.connect(_on_player_died)
	_start_wave()

func _process(_delta: float) -> void:
	_update_counter()

func _physics_process(delta: float) -> void:
	spawn_grace_left = maxf(spawn_grace_left - delta, 0.0)
	match phase:
		Phase.WAVE:
			if not enemies.is_empty() and _alive_enemies() == 0:
				phase = Phase.BOSS_INTRO
				phase_timer = boss_intro_time
				_show_banner("¡SE ACERCA EL GUARDIÁN!", Color(1.0, 0.75, 0.4))
		Phase.BOSS_INTRO:
			phase_timer -= delta
			if phase_timer <= 0.0:
				phase = Phase.BOSS
				spawn_grace_left = spawn_grace_time
				spawner.spawn_round()

# ---------- Rondas

func _start_wave() -> void:
	_clear_wave()
	_clear_portals()
	spawner.clear_bosses()
	phase = Phase.WAVE
	spawn_grace_left = spawn_grace_time
	# Ningún proyectil de la ronda anterior puede golpear durante la preparación.
	for projectile in get_tree().get_nodes_in_group(&"projectiles"):
		projectile.queue_free()
	_show_banner("RONDA %d · OLEADA" % round_number, Color(1.0, 0.9, 0.55))
	_spawn_ground_wave()
	_spawn_hawks()
	_spawn_upper_wave()

func _spawn_ground_wave() -> void:
	# En el suelo: perseguidores, tiradores (de suelo y voladores bajos) y, desde la ronda 2, escuderos;
	# más cada ronda y repartidos por la arena.
	var kinds: Array[String] = []
	var chasers: int = 2 + min(round_number, 4)
	var shooters: int = 1 + round_number / 2
	var shields: int = 0 if round_number < 2 else min(1 + (round_number - 2) / 2, 3)
	while chasers + shooters + shields > 0:
		if chasers > 0:
			kinds.append("melee")
			chasers -= 1
		if shooters > 0:
			kinds.append("shooter")
			shooters -= 1
		if shields > 0:
			kinds.append("shield")
			shields -= 1
	var aerial_toggle := false
	for index in range(kinds.size()):
		var x: float = lerp(arena_min_x, arena_max_x, (index + 0.5) / kinds.size())
		match kinds[index]:
			"melee":
				_add_chaser(Vector2(x, ground_y))
			"shield":
				var shield: Area2D = SHIELD_SCRIPT.new()
				shield.position = Vector2(x, ground_y)
				_add_enemy(shield)
			"shooter":
				# Uno sí y uno no, volador.
				_add_shooter(Vector2(x, ground_y - (220.0 if aerial_toggle else 0.0)), aerial_toggle, 0.25 if aerial_toggle else 0.0)
				aerial_toggle = not aerial_toggle

func _spawn_hawks() -> void:
	# Desde la ronda 2, halcones patrullando alto sobre la arena.
	if round_number < 2:
		return
	var count: int = min(1 + (round_number - 2) / 2, 4)
	for index in range(count):
		var hawk: Area2D = HAWK_SCRIPT.new()
		hawk.position = Vector2(lerp(arena_min_x + 500.0, arena_max_x - 300.0, (index + 0.5) / count), ground_y - 720.0 - 140.0 * (index % 2))
		hawk.patrol_direction = 1.0 if index % 2 == 0 else -1.0
		_add_enemy(hawk)

func _spawn_upper_wave() -> void:
	# Oleadas mayores (desde la ronda 3): enemigos en las plataformas de arriba, cada ronda más alto y más
	# numerosos, alternando cuerpo a cuerpo, tiradores y voladores, para obligar a subir con la movilidad.
	if round_number < 3:
		return
	var count: int = min((round_number - 2) * 2, 12)
	var max_tier: int = min(round_number + 1, 8)
	var spots: Array = UPPER_SPOTS.filter(func(spot): return spot[2] <= max_tier)
	# Primero las más altas.
	spots.sort_custom(func(a, b): return a[2] > b[2])
	for index in range(min(count, spots.size())):
		var spot: Array = spots[index]
		var feet := Vector2(spot[0], ground_y + spot[1])
		match (index + round_number) % 3:
			0:
				_add_chaser(feet)
			1:
				_add_shooter(feet, false, 0.35)
			2:
				_add_shooter(feet + Vector2(0, -120.0), true, 0.35)

func _add_chaser(feet: Vector2) -> void:
	var chaser: Area2D = Area2D.new()
	chaser.set_script(CHASER_SCRIPT)
	chaser.position = feet
	_add_enemy(chaser)

func _add_shooter(at: Vector2, aerial: bool, aim_down: float) -> void:
	var dummy: Node2D = DUMMY_SCENE.instantiate()
	dummy.shoot_interval = 2.4
	dummy.shoot_direction = Vector2(-1, aim_down)
	dummy.shine_chance = 0.2
	dummy.max_health = 6
	dummy.aerial = aerial
	dummy.position = at
	_add_enemy(dummy)

func _add_enemy(enemy: Node2D) -> void:
	enemy.set_meta(&"spawn_grace", spawn_grace_time)
	get_parent().add_child.call_deferred(enemy)
	enemies.append(enemy)

func _alive_enemies() -> int:
	var alive := 0
	# Muerto = oculto (los dummies y perseguidores se ocultan al morir); uno que aún no entró al árbol
	# (se agregan diferidos) cuenta como vivo.
	for enemy in enemies:
		if is_instance_valid(enemy) and (not enemy.is_inside_tree() or enemy.visible):
			alive += 1
	return alive

func on_bosses_defeated() -> void:
	# Lo llaman los guardianes al caer el último (en vez de la pantalla de fin).
	if phase != Phase.BOSS:
		return
	phase = Phase.PORTALS
	rounds_cleared = round_number
	_show_banner("¡RONDA %d SUPERADA!" % round_number, Color(0.6, 1.0, 0.6))
	_spawn_portal(left_portal_x, "TERMINAR", Color(1.0, 0.55, 0.35), _finish)
	_spawn_portal(right_portal_x, "SEGUIR", Color(0.4, 0.8, 1.0), _next_round)

func _next_round() -> void:
	round_number += 1
	_start_wave()

func _finish() -> void:
	RunSession.finish_stage()
	phase = Phase.DONE
	_clear_portals()
	var screen := get_tree().get_first_node_in_group(&"demo_complete")
	if screen:
		screen.message_text = "Rondas superadas: %d" % rounds_cleared
		screen.show_results()

func _on_player_died() -> void:
	RunSession.finish_stage()
	# Sin checkpoint: tras un momento, pantalla de fin con lo sobrevivido.
	if phase == Phase.DONE:
		return
	phase = Phase.DONE
	get_tree().create_timer(death_screen_delay).timeout.connect(_show_death_screen)

func _show_death_screen() -> void:
	var screen := get_tree().get_first_node_in_group(&"demo_complete")
	if screen == null:
		return
	screen.title_text = "FIN DEL GAUNTLET"
	screen.title_label.text = "FIN DEL GAUNTLET"
	screen.message_text = "Oleadas sobrevividas: %d" % rounds_cleared
	screen.show_custom_buttons([["Empezar de nuevo", screen.restart_scene], ["Menú principal", screen.go_to_main_menu]])
	screen.show_results()

func _spawn_portal(x: float, text: String, color: Color, action: Callable) -> void:
	var portal: Area2D = Area2D.new()
	portal.set_script(PORTAL_SCRIPT)
	portal.label_text = text
	portal.color = color
	portal.confirm_finish = text == "TERMINAR"
	portal.position = Vector2(x, ground_y)
	portal.entered.connect(action)
	get_parent().add_child.call_deferred(portal)
	portals.append(portal)

func _clear_wave() -> void:
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.remove_from_group(&"training_dummies")
			enemy.queue_free()
	enemies.clear()

func _clear_portals() -> void:
	for portal in portals:
		if is_instance_valid(portal):
			portal.queue_free()
	portals.clear()

# ---------- Cartel

func _update_counter() -> void:
	# Junto al reloj: oleada actual y enemigos vivos (o guardianes en pie).
	var text := "OLEADA %d" % round_number
	match phase:
		Phase.WAVE:
			text += "  ·  ENEMIGOS: %d" % _alive_enemies()
		Phase.BOSS_INTRO:
			text += "  ·  GUARDIÁN EN CAMINO"
		Phase.BOSS:
			var standing := 0
			for boss in get_tree().get_nodes_in_group(&"boss"):
				if not boss.is_defeated():
					standing += 1
			text += "  ·  GUARDIANES: %d" % standing
		Phase.PORTALS:
			text += "  ·  ¡SUPERADA!"
		Phase.DONE:
			text += "  ·  FIN"
	if phase in [Phase.WAVE, Phase.BOSS] and spawn_grace_left > 0.0:
		text += "  ·  PREPARACIÓN: %.1f s" % spawn_grace_left
	counter_label.text = text

func _build_banner() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	# Contador bajo el reloj (centrado arriba).
	var counter_panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.11, 0.09, 0.85)
	style.border_color = Color(0.55, 0.82, 0.45, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 2
	style.content_margin_bottom = 3
	counter_panel.add_theme_stylebox_override("panel", style)
	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_CENTER_TOP)
	anchor.position.y = 66
	layer.add_child(anchor)
	anchor.add_child(counter_panel)
	counter_label = Label.new()
	counter_label.add_theme_font_size_override("font_size", 16)
	counter_label.add_theme_color_override("font_color", Color(0.93, 1.0, 0.86))
	counter_panel.add_child(counter_label)
	counter_panel.resized.connect(func(): counter_panel.position.x = -counter_panel.size.x * 0.5)
	banner = Label.new()
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.size = Vector2(800, 60)
	banner.position = Vector2(-400, 110)
	banner.add_theme_font_size_override("font_size", 38)
	banner.add_theme_color_override("font_outline_color", Color(0.1, 0.04, 0.02))
	banner.add_theme_constant_override("outline_size", 10)
	banner.modulate.a = 0.0
	layer.add_child(banner)

func _show_banner(text: String, color: Color) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	if banner_tween:
		banner_tween.kill()
	banner.modulate.a = 0.0
	banner_tween = create_tween()
	banner_tween.tween_property(banner, "modulate:a", 1.0, 0.3)
	banner_tween.tween_interval(1.6)
	banner_tween.tween_property(banner, "modulate:a", 0.0, 0.6)
