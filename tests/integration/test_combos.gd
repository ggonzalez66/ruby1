extends SceneTree

# Uppercut más generoso que levanta al enemigo, rebote del heavy aéreo que devuelve el uppercut y buffer
# de combos (dash attack -> giro -> heavy aéreo, dash attack -> giro -> uppercut -> heavy aéreo,
# uppercut -> dash attack -> giro -> heavy aéreo).
# Uso (desde la raíz del proyecto): godot --headless --path . -s res://tests/integration/test_combos.gd

var level: Node
var player: CharacterBody2D
var F: Node
var fails := 0
var checks := 0
const GROUND := Vector2(2300, -2)

func frames(n: int) -> void:
	for i in range(n):
		await physics_frame

func _initialize() -> void:
	_run.call_deferred()

func check(c: bool, label: String) -> void:
	checks += 1
	print("  OK   " if c else "  FAIL ", label)
	if not c:
		fails += 1

func release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "jump", "attack", "heavy_attack", "dash", "throw_knife", "roar"]:
		Input.action_release(a)

func tap(a: String) -> void:
	Input.action_press(a)
	await frames(1)
	Input.action_release(a)

func tap_up_heavy() -> void:
	Input.action_press("move_up")
	Input.action_press("heavy_attack")
	await frames(1)
	Input.action_release("heavy_attack")
	Input.action_release("move_up")

func reset(at: Vector2 = GROUND) -> void:
	release_all()
	F.reset()
	player._respawn_player()
	player.global_position = at
	player.velocity = Vector2.ZERO
	player.has_knife = true
	await frames(5)

func make_chaser(at: Vector2) -> Area2D:
	var chaser: Area2D = Area2D.new()
	chaser.set_script(load("res://chaser_dummy.gd"))
	chaser.position = at
	level.add_child(chaser)
	return chaser

# Avanza n frames y devuelve los modos de ataque por los que pasó.
func watch_modes(n: int) -> Array:
	var seen := []
	for i in range(n):
		await frames(1)
		if not player.attack_mode in seen:
			seen.append(player.attack_mode)
	return seen

func start_sprinting() -> void:
	Input.action_press("move_right")
	Input.action_press("dash")
	await frames(20)

func _run() -> void:
	F = root.get_node("Ferocity")
	level = load("res://main.tscn").instantiate()
	root.add_child(level)
	await frames(10)
	player = get_first_node_in_group(&"player")

	print("== Uppercut: dura más y levanta al enemigo")
	await reset()
	check(player.light_uppercut_duration >= 0.2, "el uppercut golpea durante %.2f s (antes 0.08)" % player.light_uppercut_duration)
	var chaser := make_chaser(GROUND + Vector2(34, 0))
	await frames(2)
	var health_before: int = chaser.current_health
	await tap_up_heavy()
	await frames(int(player.UPPERCUT_LAUNCH_RISE * 60.0) + 4)
	check(chaser.current_health < health_before, "le pega")
	check(chaser.global_position.y < GROUND.y - player.UPPERCUT_LAUNCH_HEIGHT * 0.8, "lo levanta (%.0f px por encima del suelo)" % (GROUND.y - chaser.global_position.y))
	check((chaser.global_position.x - player.global_position.x) * player.facing > 10.0, "y queda delante de Viridy")
	await frames(int(player.UPPERCUT_LAUNCH_HANG * 60.0) - 8)
	check(chaser.launched and chaser.global_position.y < GROUND.y - 100.0, "flota un momento en el aire")
	await frames(90)
	check(not chaser.launched and abs(chaser.global_position.y - GROUND.y) < 6.0 and chaser.state != chaser.State.DEAD, "luego cae al suelo sin reventar")
	chaser.queue_free()

	print("== Rebote del heavy aéreo: devuelve el uppercut")
	await reset(GROUND + Vector2(0, -300))
	player.air_uppercut_available = false
	player.attack_mode = player.ATTACK_HEAVY
	player._bounce_out_of_heavy_attack(true)
	check(player.air_uppercut_available, "tras rebotar en un enemigo se puede volver a hacer el uppercut en el aire")

	print("== Combo: dash attack -> giro -> heavy aéreo (con buffer)")
	await reset()
	await start_sprinting()
	await tap("attack")
	await frames(2)
	check(player.attack_mode == player.ATTACK_GROUND_CHARGED, "dash attack")
	await tap("jump")
	check(player.attack_mode == player.ATTACK_SPIN, "giro")
	# El pesado se pulsa pronto, antes de que el giro abra su ventana: queda guardado.
	await tap("heavy_attack")
	check(player.attack_mode == player.ATTACK_SPIN and player.combo_buffer == &"heavy", "el pesado pulsado pronto queda en el buffer")
	var seen: Array = await watch_modes(20)
	check(player.ATTACK_HEAVY in seen, "y sale el heavy aéreo al abrirse la ventana")

	print("== Giro como screw attack")
	await reset()
	await start_sprinting()
	await tap("attack")
	await frames(2)
	await tap("jump")
	await frames(2)
	var texture: Texture2D = player.animated_sprite.sprite_frames.get_frame_texture(&"spin", 0)
	check(player.animated_sprite.animation == &"spin" and texture.resource_path.ends_with("viridy_frontflip.png"), "el giro usa la pose encogida del frontflip")
	var angle_before: float = player.animated_sprite.rotation
	await frames(4)
	check(abs(angle_before - player.animated_sprite.rotation) > 1.0, "y gira rápido (%.1f rad en 4 frames)" % abs(angle_before - player.animated_sprite.rotation))
	check(player.screw_embers.emitting, "con brasas de fuego verde")
	var fire_line: Line2D = player.effect_strokes[0][1]
	var flame: Color = fire_line.gradient.get_color(1)
	check(player.attack_effects.visible and fire_line.visible and Color(flame, 1.0).is_equal_approx(Color(F.style_color(), 1.0)), "y llamas del color del rango girando alrededor (%s)" % flame.to_html(false))
	var ember_mid: Color = player.screw_embers.color_ramp.get_color(1)
	check(ember_mid.is_equal_approx(F.style_color()), "las brasas también")
	await frames(40)
	check(not player.screw_embers.emitting, "al terminar el giro se apagan las brasas")
	release_all()

	print("== Combo: dash attack -> giro -> uppercut -> heavy aéreo")
	await reset()
	await start_sprinting()
	await tap("attack")
	await frames(2)
	await tap("jump")
	check(player.attack_mode == player.ATTACK_SPIN, "giro")
	await tap_up_heavy()
	seen = await watch_modes(20)
	check(player.ATTACK_UPPERCUT in seen, "del giro sale el uppercut")
	await tap("heavy_attack")
	seen = await watch_modes(25)
	check(player.ATTACK_HEAVY in seen, "y del uppercut, el heavy aéreo")

	print("== Combo: uppercut -> dash attack -> giro -> heavy aéreo")
	await reset()
	await tap_up_heavy()
	await frames(2)
	check(player.attack_mode == player.ATTACK_UPPERCUT, "uppercut")
	await tap("attack")
	seen = await watch_modes(20)
	check(player.ATTACK_LIGHT_CHARGED_AIR in seen, "del uppercut sale el dash attack aéreo")
	await tap("jump")
	check(player.attack_mode == player.ATTACK_SPIN, "saltando: el giro")
	await tap("heavy_attack")
	seen = await watch_modes(25)
	check(player.ATTACK_HEAVY in seen, "y el heavy aéreo")

	print("== Heavy de suelo nuevo (tajo con el cuchillo)")
	await reset()
	var heavy_texture: Texture2D = player.animated_sprite.sprite_frames.get_frame_texture(&"ground_heavy", 0)
	check(heavy_texture.atlas.resource_path.ends_with("viridy_ground_heavy.png") and heavy_texture.region.size.x == 1086.0, "usa la hoja nueva de 2 frames")
	# El cuchillo conserva los colores de Rengar: mismos píxeles que la hoja original en la hoja.
	var viridy_img: Image = heavy_texture.atlas.get_image()
	var rengar_img: Image = (load("res://assets/sprites/player/rengar/reng_heavyNEW.png") as Texture2D).get_image()
	var same := 0
	var probes := [Vector2i(700, 40), Vector2i(620, 30), Vector2i(2040, 600), Vector2i(2030, 520)]
	for point in probes:
		var a: Color = viridy_img.get_pixelv(point)
		var b: Color = rengar_img.get_pixelv(point)
		if b.a > 0.5 and abs(a.r - b.r) < 0.02 and abs(a.g - b.g) < 0.02 and abs(a.b - b.b) < 0.02:
			same += 1
	check(same == probes.size(), "la hoja del cuchillo no cambia de color (%d/%d puntos iguales)" % [same, probes.size()])
	var victim := make_chaser(GROUND + Vector2(60, 0))
	await frames(2)
	var victim_health: int = victim.current_health
	Input.action_press("heavy_attack")
	await frames(2)
	Input.action_release("heavy_attack")
	check(player.attack_mode == player.ATTACK_HEAVY_GROUND and player.animated_sprite.animation == &"ground_heavy", "sale el heavy de suelo")
	var steel: Line2D = player.effect_strokes[0][1]
	var gilt: Line2D = player.effect_strokes[1][1]
	check(steel.visible and gilt.visible and steel.gradient.get_color(1).b > 0.8 and gilt.gradient.get_color(1).r > 0.9 and gilt.gradient.get_color(1).b < 0.3, "con la estela de acero y el filo dorado")
	await frames(10)
	check(victim.current_health < victim_health, "y el tajo conecta con el enemigo de delante")
	victim.queue_free()

	print("== Uppercut corriendo contra una pared: wallrun")
	await reset()
	var wall: StaticBody2D = load("res://platform.gd").new()
	wall.size = Vector2(60, 600)
	wall.position = GROUND + Vector2(900, -300)
	level.add_child(wall)
	await frames(2)
	await start_sprinting()
	var gap: float = wall.global_position.x - 30.0 - player.global_position.x
	check(player.is_sprinting and gap > 40.0, "corriendo hacia la pared (a %.0f px)" % gap)
	for i in range(60):
		await frames(1)
		if wall.global_position.x - 30.0 - player.global_position.x < 70.0:
			break
	Input.action_press("move_up")
	await frames(2)
	Input.action_press("heavy_attack")
	await frames(2)
	Input.action_release("heavy_attack")
	Input.action_release("move_up")
	var saw_uppercut := false
	var saw_wallride := false
	for i in range(40):
		await frames(1)
		saw_uppercut = saw_uppercut or player.attack_mode == player.ATTACK_UPPERCUT
		if player.wallride_active:
			saw_wallride = true
			break
	check(saw_uppercut, "sale el uppercut corriendo")
	check(saw_wallride, "y al tocar la pared empieza el wallrun")
	release_all()
	wall.queue_free()

	print("== Tras el uppercut: aerial stall")
	await reset()
	await tap_up_heavy()
	await frames(int((player.light_uppercut_duration + 0.35) * 60.0) + 4)
	check(not player.is_on_floor() and player.animated_sprite.animation == &"aerial_stall", "al terminar el uppercut queda en aerial stall (%s)" % player.animated_sprite.animation)
	for i in range(120):
		await frames(1)
		if player.is_on_floor():
			break
	await frames(2)
	check(player.is_on_floor() and player.animated_sprite.animation != &"aerial_stall", "y al aterrizar lo deja")

	print("== Aterrizaje del heavy aéreo: el cuchillo se clava (solo visual)")
	await reset(GROUND + Vector2(0, -160))
	Input.action_press("heavy_attack")
	await frames(2)
	Input.action_release("heavy_attack")
	check(player.attack_mode == player.ATTACK_HEAVY, "heavy aéreo")
	var landed_anim: StringName = &""
	var slide_speed := 0.0
	for i in range(90):
		await frames(1)
		if player.is_on_floor() and player.heavy_ground_impact_wave_timer > 0.0:
			landed_anim = player.animated_sprite.animation
			slide_speed = abs(player.velocity.x)
			break
	var landing_texture: Texture2D = player.animated_sprite.sprite_frames.get_frame_texture(&"heavy_landing", 0)
	check(landed_anim == &"heavy_landing" and landing_texture.region.position.x == 1086.0, "al tocar el suelo: el 2º frame del heavy de suelo (%s)" % landed_anim)
	check(player.attack_mode == player.ATTACK_NONE and abs(slide_speed - player.heavy_ground_impact_slide_speed) < 60.0, "la mecánica no cambia: ataque terminado y deslizamiento de siempre (%.0f)" % slide_speed)
	await frames(int(player.heavy_ground_impact_wave_duration * 60.0) + 4)
	check(player.animated_sprite.animation != &"heavy_landing", "y al acabar la onda vuelve a lo normal")

	print("== Cámara lenta (RB)")
	await reset()
	var TC: Node = root.get_node("TimeControl")
	var rb_bound := false
	for event in InputMap.action_get_events("slow_motion"):
		rb_bound = rb_bound or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_RIGHT_SHOULDER)
	check(rb_bound, "la acción slow_motion va en RB")
	var pause_menu: Node = null
	for node in level.find_children("*", "CanvasLayer", true, false):
		if node.get_script() == load("res://pause_menu.gd"):
			pause_menu = node
	var rb := InputEventJoypadButton.new()
	rb.button_index = JOY_BUTTON_RIGHT_SHOULDER
	rb.pressed = true
	pause_menu._unhandled_input(rb)
	check(TC.slow_motion and is_equal_approx(Engine.time_scale, TC.SLOW_SCALE), "RB activa la cámara lenta (×%.2f)" % Engine.time_scale)
	check(pause_menu.slow_label.visible, "con su aviso en pantalla")
	player._apply_hitstop(0.05)
	check(Engine.time_scale < TC.SLOW_SCALE * 0.1, "un golpe sigue congelando un instante")
	await create_timer(0.15, true, false, true).timeout
	check(is_equal_approx(Engine.time_scale, TC.SLOW_SCALE), "y al terminar vuelve a cámara lenta, no a velocidad normal")
	player._respawn_player()
	await frames(2)
	check(is_equal_approx(Engine.time_scale, TC.SLOW_SCALE), "reaparecer no la quita")
	pause_menu._unhandled_input(rb)
	check(not TC.slow_motion and is_equal_approx(Engine.time_scale, 1.0) and not pause_menu.slow_label.visible, "otro RB vuelve a velocidad normal y quita el aviso")

	print("== El buffer caduca")
	await reset()
	player.combo_buffer = &"heavy"
	player.combo_buffer_timer = 0.05
	player.attack_cooldown_timer = 5.0
	await frames(8)
	check(player.combo_buffer == &"", "una acción guardada que no pudo salir se descarta a los %.1f s" % player.COMBO_BUFFER_TIME)

	release_all()
	print("RESULTADO: %d/%d OK" % [checks - fails, checks])
	quit()
