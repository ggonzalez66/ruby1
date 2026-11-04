extends "res://gauntlet_director.gd"

# Director de un territorio de combate de la run (RunState). Reutiliza el del Gauntlet: enemigos con
# sigilo, escalado de vida/postura/elementos (round_number = profundidad de la run), Enfoque, aliados,
# guardianes y menú de mejoras. Cada enfrentamiento tiene tres fases, una escena cada una:
#   1. OUTDOOR · afueras de la fábrica: al caer todos los enemigos se abre la puerta.
#   2. INDOOR · dentro, varios pisos: al limpiarlos se abre la puerta del guardián.
#   3. BOSS · la sala del guardián: al vencerlo, una mejora gratis y el portal de vuelta al mapa.
# TOWER es la Torre del final: los tres guardianes juntos y, al vencerlos, el sol que absorbe a Viridy
# (ruby_crystal.gd → RunState.go_to_parkour).
# Los enemigos salen de los Marker2D hijos de "spawns_path": metadata "kind" (tipo) y "min_depth" (desde
# qué enfrentamiento aparece). kind "bush" pone un bush para esconderse.
# Morir termina la run (pantalla de fin con vuelta al Árbol Madre).
# Variantes de nivel: cada cámara de seguridad colocada puede no estar (CAMERA_SKIP_CHANCE), siempre queda
# al menos una, así dos visitas al mismo territorio no se juegan igual.

enum Stage { OUTDOOR, INDOOR, BOSS, TOWER }

const SUN_SCRIPT := preload("res://ruby_crystal.gd")
const SPIDER_SCRIPT := preload("res://spider_boss.gd")
const SPIDER_DELAY := 2.6
const CAMERA_SKIP_CHANCE := 0.35
# Las pruebas que cuentan cámaras lo apagan antes de abrir la escena.
static var layout_variants := true
# Vida de la araña: el núcleo central y cada pata (escalan con la profundidad como los guardianes).
const SPIDER_HEALTH := 90
const SPIDER_LEG_HEALTH := 36
const STAGE_NAMES := ["FÁBRICA · AFUERAS", "FÁBRICA · DENTRO", "FÁBRICA · GUARDIÁN", "LA TORRE"]

@export var stage := Stage.OUTDOOR
@export var spawns_path: NodePath
@export var exit_path: NodePath
@export var sun_position := Vector2(3900, 0)

var cleared := false
var exit_door: Node
var sun: Node2D
var standalone := false
# La Torre: tras el trío llega la araña; el sol aparece al vencerla.
var spider: Node2D
var spider_called := false

func _ready() -> void:
	add_to_group(&"gauntlet_director")
	if not spawner_path.is_empty():
		spawner = get_node(spawner_path)
	round_number = RunState.depth() if RunState.active else 1
	# Abierta directamente (editor o pruebas): una run de mejoras propia para que los rubíes cuenten.
	standalone = not RunState.active and not Upgrades.active
	if standalone:
		Upgrades.begin_run()
	_build_banner()
	if layout_variants:
		_vary_layout()
	stealth = STEALTH_SCRIPT.new()
	add_child(stealth)
	var bush_points: Array = _markers().filter(func(marker): return marker.get_meta(&"kind", "") == "bush").map(func(marker): return marker.global_position)
	if not bush_points.is_empty():
		stealth.spawn_bushes(bush_points, get_parent())
	upgrade_menu = UPGRADE_MENU_SCRIPT.new()
	upgrade_menu.free_only = true
	add_child(upgrade_menu)
	upgrade_menu.closed.connect(_on_upgrades_closed)
	focus = FOCUS_SCRIPT.new()
	add_child(focus)
	Upgrades.rubies_changed.connect(_on_rubies_changed)
	_on_rubies_changed(Upgrades.rubies, 0)
	exit_door = get_node_or_null(exit_path)
	if exit_door != null:
		exit_door.entered.connect(_on_exit_entered)
	_start.call_deferred()

func _vary_layout() -> void:
	var cameras: Array = get_parent().get_children().filter(func(node): return node.is_in_group(&"security_cameras"))
	cameras.shuffle()
	for index in range(1, cameras.size()):
		if randf() < CAMERA_SKIP_CHANCE:
			cameras[index].remove_from_group(&"security_cameras")
			cameras[index].queue_free()

func _exit_tree() -> void:
	if standalone:
		Upgrades.end_run()

func _markers() -> Array:
	var holder := get_node_or_null(spawns_path)
	return holder.get_children() if holder != null else []

# ---------- Fases

func _start_wave() -> void:
	_clear_wave()
	_clear_portals()
	if spawner != null:
		spawner.clear_bosses()
	phase = Phase.WAVE
	spawn_grace_left = 0.0
	stealth.begin_wave()
	_sync_allies()
	if stage in [Stage.BOSS, Stage.TOWER]:
		phase = Phase.BOSS_INTRO
		phase_timer = boss_intro_time
		_show_banner("¡LOS TRES GUARDIANES!" if stage == Stage.TOWER else "¡EL GUARDIÁN DE LA FÁBRICA!", Color(1.0, 0.75, 0.4))
		return
	_show_banner("%s · ENFRENTAMIENTO %d" % [STAGE_NAMES[stage], round_number], Color(1.0, 0.9, 0.55))
	for marker in _markers():
		var kind: String = marker.get_meta(&"kind", "")
		if kind != "bush" and round_number >= int(marker.get_meta(&"min_depth", 1)):
			_spawn_kind(kind, marker.global_position)

func _spawn_kind(kind: String, at: Vector2) -> void:
	match kind:
		"melee":
			_add_chaser(at)
		"shooter":
			_add_shooter(at, false, 0.0)
		"shooter_high":
			_add_shooter(at, false, 0.35)
		"flyer":
			_add_shooter(at, true, 0.25)
		"shield":
			var shield: Area2D = SHIELD_SCRIPT.new()
			shield.position = at
			_add_enemy(shield)
		"rifleman":
			_add_scripted(RIFLEMAN_SCRIPT, at)
		"hound":
			_add_scripted(HOUND_SCRIPT, at)
		"sentinel":
			_add_scripted(SENTINEL_SCRIPT, at)
		"stinger":
			_add_scripted(STINGER_SCRIPT, at)
		"restorer":
			_add_scripted(RESTORER_SCRIPT, at)
		"hawk":
			var hawk: Area2D = HAWK_SCRIPT.new()
			hawk.position = at
			hawk.patrol_direction = -1.0 if enemies.size() % 2 == 0 else 1.0
			_add_enemy(hawk)
		_:
			push_warning("Tipo de enemigo desconocido en la run: %s" % kind)

func _physics_process(delta: float) -> void:
	if phase == Phase.WAVE:
		spawn_grace_left = maxf(spawn_grace_left - delta, 0.0)
		_call_down_stragglers()
		if not cleared and _alive_enemies() == 0:
			_on_area_cleared()
		return
	super(delta)

func _on_area_cleared() -> void:
	cleared = true
	phase = Phase.PORTALS
	stealth.stand_down()
	if exit_door != null:
		exit_door.open()
	_show_banner("¡LA PUERTA SE ABRE!" if stage == Stage.OUTDOOR else "¡EL GUARDIÁN TE ESPERA!", Color(0.6, 1.0, 0.6))

func _on_exit_entered() -> void:
	if phase == Phase.DONE:
		return
	phase = Phase.DONE
	focus.cancel()
	RunState.next_fight_phase(get_parent().scene_file_path)

func on_bosses_defeated() -> void:
	if phase != Phase.BOSS:
		return
	rounds_cleared = round_number
	if stage == Stage.TOWER:
		# Cada guardián del trío avisa al caer: solo cuenta la araña vencida para pasar al sol.
		if not (is_instance_valid(spider) and spider.is_defeated()):
			if not spider_called:
				spider_called = true
				_show_banner("¡ALGO ENORME SE ACERCA!", Color(1.0, 0.45, 0.35))
				Sfx.play("boss_alert", 2.0, 0.6)
				get_tree().create_timer(SPIDER_DELAY).timeout.connect(_spawn_spider)
			return
		phase = Phase.PORTALS
		_show_banner("¡EL SOL TE LLAMA!", Color(1.0, 0.85, 0.4))
		_spawn_sun()
		return
	# Solo los guardianes dan una mejora gratis; el resto de rubíes se guarda para el zorro.
	phase = Phase.REWARD
	phase_timer = reward_delay
	_show_banner("¡GUARDIÁN VENCIDO!", Color(0.6, 1.0, 0.6))

func _on_upgrades_closed() -> void:
	_sync_allies()
	var player := get_tree().get_first_node_in_group(&"player")
	if player:
		player.sync_ranged_weapon()
	_spawn_portal(right_portal_x, "AL MAPA", Color(0.4, 0.8, 1.0), _back_to_map)

func _back_to_map() -> void:
	if phase == Phase.DONE:
		return
	phase = Phase.DONE
	focus.cancel()
	RunState.complete_fight()

func _spawn_spider() -> void:
	if phase != Phase.BOSS or is_instance_valid(spider):
		return
	var scale_factor: float = 1.0 + GUARDIAN_HEALTH_PER_ROUND * (round_number - 1)
	spider = Area2D.new()
	spider.set_script(SPIDER_SCRIPT)
	spider.boss_name = "LA ARAÑA COLOSAL"
	spider.boss_subtitle = "Cuatro patas, cinco rubíes"
	spider.max_health = ceili(SPIDER_HEALTH * scale_factor)
	spider.leg_health = ceili(SPIDER_LEG_HEALTH * scale_factor)
	spider.min_x = spawner.arena_min_x if spawner != null else 300.0
	spider.max_x = spawner.arena_max_x if spawner != null else 3600.0
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	# Entra por el lado contrario al de Viridy.
	var middle: float = (spider.min_x + spider.max_x) * 0.5
	var from_right: bool = player == null or player.global_position.x < middle
	spider.position = Vector2(spider.max_x - 400.0 if from_right else spider.min_x + 400.0, ground_y)
	spider.facing = -1 if from_right else 1
	spider.set_meta(&"spawn_grace", spawn_grace_time)
	get_parent().add_child(spider)
	Fx.big_explosion(get_parent(), spider.position, 0.9)
	_show_banner("¡LA ARAÑA COLOSAL!", Color(1.0, 0.45, 0.35))

func _spawn_sun() -> void:
	sun = SUN_SCRIPT.new()
	sun.goal_style = "sun"
	sun.position = sun_position
	sun.scale = Vector2.ONE * 0.1
	get_parent().add_child(sun)
	sun.create_tween().tween_property(sun, "scale", Vector2.ONE, 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _show_death_screen() -> void:
	var screen := get_tree().get_first_node_in_group(&"demo_complete")
	if screen == null:
		return
	if RunState.active:
		RunState.show_defeat(screen)
		return
	super()

# ---------- Contador

func _update_counter() -> void:
	var text: String = STAGE_NAMES[stage]
	if stage != Stage.TOWER:
		text += "  ·  ENFRENTAMIENTO %d" % round_number
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
			if spawn_grace_left > 0.0:
				text += "  ·  PREPARACIÓN: %.1f s" % spawn_grace_left
		Phase.PORTALS, Phase.REWARD:
			text += "  ·  ¡SUPERADO!" if stage in [Stage.BOSS, Stage.TOWER] else "  ·  ¡PUERTA ABIERTA!"
		Phase.DONE:
			text += "  ·  FIN"
	counter_label.text = text
