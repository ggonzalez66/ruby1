extends SceneTree

const Catalog := preload("res://weapon_catalog.gd")
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

func start(id: StringName, heavy: bool, step: int = 0) -> void:
	player._cancel_all_states()
	player.attack_cooldown_timer = 0
	player.weapons.equip(id)
	player.weapons.step = step - 1
	player.weapons.last_heavy = heavy
	player.weapons.window = 0.5
	player.weapons.request(heavy)
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
	var w = player.weapons
	for id in Catalog.IDS:
		for heavy in [false, true]:
			for step in Catalog.chain(id, heavy).size():
				var label := "%s %s %d" % [id, "heavy" if heavy else "light", step + 1]
				start(id, heavy, step)
				w.tick(w.startup * 0.5)
				check(target.hits == 0 and w.phase == w.Phase.STARTUP, label + ": startup sin daño")
				w.tick(w.startup * 0.5 + 0.000001)
				check(target.hits == 1 and w.phase == w.Phase.ACTIVE, label + ": primer impacto al entrar en active")
				w.tick(0.000001)
				check(target.hits == 1, label + ": no repite el mismo pulso")
				w.tick(w.startup + w.active_time - w.elapsed + 0.000001)
				check(target.hits == int(w.move.pulses) and w.phase == w.Phase.RECOVERY, label + ": todos los pulsos antes de recovery")
				# An enemy newly available in recovery must not be hit, even at its boundary.
				for hit_set in w.hit_sets:
					hit_set.clear()
				var before: int = target.hits
				w.elapsed = w.startup + w.active_time
				w.tick(w.recovery * 0.5)
				check(target.hits == before and w.active, label + ": recovery sin daño, ataque aún ocupado")
				w.tick(w.recovery)
				check(not w.active and w.phase == w.Phase.IDLE, label + ": termina tras recovery")
	# Large ticks cross every pulse once; the following tick cannot deal late damage.
	start(&"sword", true, 1)
	w.tick(w.duration + 0.1)
	check(target.hits == 3 and not w.active, "Frame largo conserva los tres impactos de la ráfaga")
	w.tick(1.0)
	check(target.hits == 3, "No hay impactos tardíos tras terminar")
	# The next command waits for recovery and begins with its own startup.
	start(&"hammer", false)
	w.request(false)
	w.tick(w.startup + w.active_time + w.recovery * 0.5)
	check(w.step == 0 and w.phase == w.Phase.RECOVERY, "Buffer no omite recovery del martillo")
	w.tick(w.recovery)
	check(w.step == 1 and w.phase == w.Phase.STARTUP and is_zero_approx(w.elapsed), "Siguiente golpe comienza con startup completo")
	start(&"axe", true)
	w.tick(w.startup * 0.5)
	player._cancel_all_states()
	w.tick(10)
	check(target.hits == 0 and w.phase == w.Phase.IDLE and w.queued == &"", "Cancelar startup elimina daño y buffer pendientes")
	# Charging is separate from startup; release does not make the hit instant.
	Input.action_press("heavy_attack")
	start(&"hammer", true)
	w.tick(2.0)
	check(w.charging and target.hits == 0 and is_zero_approx(w.elapsed), "Carga sostenida no adelanta las tres fases")
	Input.action_release("heavy_attack")
	w.tick(0.01)
	check(not w.charging and w.charge_ratio == 1 and w.phase == w.Phase.STARTUP and target.hits == 0, "Soltar carga comienza startup sin daño")
	w.tick(w.startup + 0.001)
	check(target.hits == 1, "Heavy cargado golpea al llegar a active")
	# Speed modifiers scale every phase together.
	player.attack_speed_multiplier = 2.0
	start(&"sword", false)
	check(is_equal_approx(w.startup, 2.0 / 60.0) and is_equal_approx(w.active_time, 2.5 / 60.0) and is_equal_approx(w.recovery, 2.5 / 60.0), "Velocidad escala startup, active y recovery")
	player.attack_speed_multiplier = 1.0
	# Both the four-frame strikes and the three-frame finisher follow the phases.
	for entry in [[&"sword", 0], [&"unarmed", 2]]:
		start(entry[0], false, entry[1])
		w.tick(w.startup * 0.5)
		player._update_character_animation()
		check(player.animated_sprite.frame == 0, "%s: pose de anticipación en startup" % entry[0])
		w.tick(w.startup * 0.5 + 0.001)
		player._update_character_animation()
		check(player.animated_sprite.frame == 1, "%s: pose de impacto al activar daño" % entry[0])
		w.tick(w.active_time)
		player._update_character_animation()
		var last: int = player.animated_sprite.sprite_frames.get_frame_count(player.animated_sprite.animation) - 1
		check(player.animated_sprite.frame == last, "%s: pose final durante recovery" % entry[0])
	start(&"hammer", false)
	player.show_hitbox_debug = true
	player._update_hitbox_visual_visibility()
	check(not player.slash_visual.visible and not player.attack_effects.visible, "Debug no muestra hitbox heredada durante startup")
	player.show_hitbox_debug = false
	# Input routing: repeated taps queue without skipping the slow weapon's recovery.
	start(&"hammer", false)
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
