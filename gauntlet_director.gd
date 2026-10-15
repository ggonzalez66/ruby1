extends Node2D

# Director del Gauntlet por oleadas. Cada ronda:
# 1. Oleada de enemigos normales (perseguidores y tiradores; más en cada ronda): hay que matarlos a todos.
# 2. Con todos muertos, se prepara el guardián (a veces salen los tres) y aparece.
# 3. Al vencerlo aparecen dos portales: el de la derecha sigue a la siguiente ronda; el de la izquierda
#    termina el Gauntlet y muestra la pantalla de fin con las medallas.
# Si Rengar muere, la ronda actual empieza de nuevo desde su oleada.

const CHASER_SCRIPT := preload("res://chaser_dummy.gd")
const DUMMY_SCENE := preload("res://training_dummy.tscn")
const PORTAL_SCRIPT := preload("res://portal.gd")

enum Phase { WAVE, BOSS_INTRO, BOSS, PORTALS, DONE }

@export var arena_min_x := 1400.0
@export var arena_max_x := 4100.0
@export var ground_y := 0.0
@export var spawner_path: NodePath
@export var boss_intro_time := 2.5
@export var left_portal_x := 600.0
@export var right_portal_x := 4150.0

var round_number := 1
var phase := Phase.WAVE
var phase_timer := 0.0
var enemies: Array = []
var portals: Array = []
var spawner: Node
var banner: Label
var banner_tween: Tween

func _ready() -> void:
	add_to_group(&"gauntlet_director")
	spawner = get_node(spawner_path)
	_build_banner()
	_start.call_deferred()

func _start() -> void:
	var player := get_tree().get_first_node_in_group(&"player")
	if player:
		player.respawned.connect(_restart_round)
	_start_wave()

func _physics_process(delta: float) -> void:
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
				spawner.spawn_round()

# ---------- Rondas

func _start_wave() -> void:
	_clear_wave()
	_clear_portals()
	spawner.clear_bosses()
	phase = Phase.WAVE
	_show_banner("RONDA %d · OLEADA" % round_number, Color(1.0, 0.9, 0.55))
	# Más enemigos cada ronda, repartidos por la arena.
	var chasers: int = 2 + round_number
	var shooters: int = 1 + round_number / 2
	var total: int = chasers + shooters
	for index in range(total):
		var x: float = lerp(arena_min_x, arena_max_x, (index + 0.5) / total)
		if index % 2 == 1 and shooters > 0:
			shooters -= 1
			var aerial: bool = (index / 2) % 2 == 1
			var dummy: Node2D = DUMMY_SCENE.instantiate()
			dummy.shoot_interval = 2.4
			dummy.shoot_direction = Vector2(-1, 0.25 if aerial else 0.0)
			dummy.shine_chance = 0.2
			dummy.max_health = 6
			dummy.aerial = aerial
			dummy.position = Vector2(x, ground_y - (220.0 if aerial else 0.0))
			_add_enemy(dummy)
		else:
			var chaser: Area2D = Area2D.new()
			chaser.set_script(CHASER_SCRIPT)
			chaser.position = Vector2(x, ground_y)
			_add_enemy(chaser)

func _add_enemy(enemy: Node2D) -> void:
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
	_show_banner("¡RONDA %d SUPERADA!" % round_number, Color(0.6, 1.0, 0.6))
	_spawn_portal(left_portal_x, "TERMINAR", Color(1.0, 0.55, 0.35), _finish)
	_spawn_portal(right_portal_x, "SEGUIR", Color(0.4, 0.8, 1.0), _next_round)

func _next_round() -> void:
	round_number += 1
	_start_wave()

func _finish() -> void:
	phase = Phase.DONE
	_clear_portals()
	var screen := get_tree().get_first_node_in_group(&"demo_complete")
	if screen:
		screen.message_text = "Rondas superadas: %d" % round_number
		screen.show_results()

func _restart_round() -> void:
	# Rengar murió o reinició: la ronda actual vuelve a su oleada.
	if phase == Phase.DONE:
		return
	_start_wave()

func _spawn_portal(x: float, text: String, color: Color, action: Callable) -> void:
	var portal: Area2D = Area2D.new()
	portal.set_script(PORTAL_SCRIPT)
	portal.label_text = text
	portal.color = color
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

func _build_banner() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
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
