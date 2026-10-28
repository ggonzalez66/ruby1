extends Node2D

const Catalog := preload("res://weapon_catalog.gd")
const MODE := 8
const CHAIN_WINDOW := 0.55
const CHARGE_TIME := 0.85
const FORM_COOLDOWN := 0.45
var player: CharacterBody2D
var equipped: StringName = &"unarmed"
var active := false
var charging := false
var charge := 0.0
var charge_ratio := 0.0
var elapsed := 0.0
var duration := 0.0
var step := -1
var heavy := false
var last_heavy := false
var window := 0.0
var queued := &""
var move: Dictionary = {}
var hit_sets: Array = []
var aim := false
var aim_direction := Vector2.RIGHT
var form_cooldown := 0.0
var breath := false
var breath_tick := 0.0
var weapon_sprite: Sprite2D
var status: Label
var display_texture: StringName = &""

func _ready() -> void:
	player = get_parent()
	z_index = 5
	weapon_sprite = Sprite2D.new()
	weapon_sprite.centered = false
	weapon_sprite.offset = Vector2(-18, -40)
	weapon_sprite.scale = Vector2.ONE * 0.72
	add_child(weapon_sprite)
	var layer := CanvasLayer.new()
	layer.layer = 11
	add_child(layer)
	status = Label.new()
	status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	status.position = Vector2(18, -64)
	status.add_theme_font_size_override("font_size", 15)
	status.add_theme_color_override("font_outline_color", Color("102a24"))
	status.add_theme_constant_override("outline_size", 5)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(status)

func current_weapon() -> StringName:
	return equipped if player.has_knife else &"unarmed"

func equip(id: StringName) -> bool:
	if id not in Catalog.IDS or player.dead or player.execution_core != null or player.wrath.controls_movement():
		return false
	player._cancel_all_states()
	if is_instance_valid(player.thrown_knife):
		player.thrown_knife.queue_free()
	player.thrown_knife = null
	equipped = id
	player.has_knife = id != &"unarmed"
	player.knife_changed.emit(player.has_knife)
	player.jade_fire_cooldown_timer = 0.0
	cancel()
	return true

func toggle_form() -> void:
	if form_cooldown > 0.0 or player._blocks_actions() or player.execution_core != null or player.dead or player.wrath.controls_movement():
		return
	player._cancel_all_states()
	player.liquid_beast = not player.liquid_beast
	form_cooldown = FORM_COOLDOWN
	aim = false
	breath = false
	Fx.jade_splash(player.get_parent(), player.global_position + Vector2(0, -25), Vector2.UP, 0.45)

func tick(delta: float) -> void:
	form_cooldown = maxf(form_cooldown - delta, 0.0)
	window = maxf(window - delta, 0.0)
	if Input.is_action_just_pressed("transform"):
		toggle_form()
	aim = Input.is_action_pressed("throw_knife") and not player.liquid_beast and not player._blocks_actions()
	if aim:
		if player.dash_timer > 0.0:
			player.dash_timer = 0.0
			player._set_dash_visual_active(false)
		player._stop_sprint()
		player.long_jump_active = false
		player.backflip_active = false
		player.velocity.x = clampf(player.velocity.x, -player.max_speed, player.max_speed)
		_update_aim()
	breath = player.liquid_beast and Input.is_action_pressed("attack") and not player._is_attack_active() and not player._blocks_actions() and player.dash_timer <= 0.0
	breath_tick -= delta
	if breath and breath_tick <= 0.0:
		breath_tick = 0.16
		_breath_hit()
	if active:
		if charging:
			charge = minf(charge + delta, CHARGE_TIME)
			if not Input.is_action_pressed("heavy_attack"):
				charging = false
				charge_ratio = charge / CHARGE_TIME
				Sfx.play("swing_heavy", 0.0, 0.85)
		else:
			var previous := elapsed
			elapsed += delta
			# Revisar todo el intervalo: un frame largo no puede saltarse una ventana de daño.
			for pulse in range(int(move.pulses)):
				if not active:
					break
				var at := duration * (0.16 + float(pulse) * 0.52 / maxf(float(move.pulses), 1.0))
				if current_weapon() == &"unarmed" and not heavy and step < 3:
					at = 0.0
				var until := at + duration * (0.55 if int(move.pulses) == 1 else 0.18)
				if elapsed >= at and previous <= until:
					_strike(pulse)
			if active and elapsed >= duration:
				_finish()
	queue_redraw()

func request(is_heavy: bool) -> bool:
	if player.liquid_beast or aim or player._blocks_actions() or player.dash_timer > 0.0:
		return false
	if active:
		queued = &"heavy" if is_heavy else &"light"
		return true
	if player._is_attack_active() or player.attack_cooldown_timer > 0.0:
		return false
	var chain := Catalog.chain(current_weapon(), is_heavy)
	if window > 0.0 and last_heavy == is_heavy and step + 1 < chain.size():
		step += 1
	else:
		step = 0
	heavy = is_heavy
	last_heavy = heavy
	move = chain[step]
	duration = float(move.duration) / maxf(player.attack_speed_multiplier, 0.1)
	elapsed = 0.0
	charge = 0.0
	charge_ratio = 0.0
	charging = Catalog.chargeable(current_weapon(), heavy, step) and Input.is_action_pressed("heavy_attack")
	hit_sets.clear()
	for _pulse in range(int(move.pulses)):
		hit_sets.append([])
	active = true
	queued = &""
	window = 0.0
	player._face_attack_input()
	player.attack_mode = MODE
	player.attack_timer = 0.0
	player._set_attack_active(false)
	player.light_combo_step = step + 1
	if heavy:
		player._consume_riposte()
	if not player.is_on_floor():
		player.velocity.y = minf(player.velocity.y, -50.0)
	if not charging:
		Sfx.play("swing_heavy" if heavy else "swing_light")
		if current_weapon() == &"unarmed" and not heavy and step < 3:
			_strike(0)
	return true

func apply_movement(delta: float, horizontal: float) -> void:
	if player.is_sprinting and not heavy:
		player._apply_sprint_movement(horizontal, delta)
	else:
		player.velocity.x = move_toward(player.velocity.x, horizontal * player.max_speed * 0.45, player.ground_acceleration * delta)
	if not charging and move.get("kind") == "lunge" and elapsed < duration * 0.7:
		player.velocity.x = player.facing * (480.0 + charge_ratio * 520.0)
	if player.is_on_floor():
		player.velocity.y = 0.0
	else:
		# Cada string tiene suspensión, también si los golpes no encuentran un enemigo.
		player.velocity.y = minf(player.velocity.y + player.gravity * delta * (0.35 if charging else 0.08), 85.0)

func _finish() -> void:
	var next := queued
	active = false
	charging = false
	queued = &""
	player.attack_mode = player.ATTACK_NONE
	player.riposte_attack = false
	player.attack_effects.visible = false
	player.claw_slash_sprite.hide()
	window = CHAIN_WINDOW
	var chain := Catalog.chain(current_weapon(), heavy)
	if step + 1 >= chain.size():
		step = -1
		window = 0.0
		player.attack_cooldown_timer = 0.12
	if next != &"":
		# El buffer no vuelve a iniciar una cadena completa tras su último golpe.
		if window > 0.0 or (next == &"heavy") != heavy:
			player.attack_cooldown_timer = 0.0
			request(next == &"heavy")

func cancel() -> void:
	active = false
	charging = false
	breath = false
	queued = &""
	window = 0.0
	step = -1
	if is_instance_valid(player) and is_instance_valid(player.claw_slash_sprite):
		player.claw_slash_sprite.hide()

func super_armor() -> bool:
	return (active or player.common_moves.enabled) and current_weapon() == &"hammer"

func _targets(center: Vector2, size: Vector2, original_claw := false) -> Array:
	var shapes: Array[Shape2D] = []
	var transform := Transform2D(0.0, center)
	if original_claw:
		# Conservar la geometría exacta de los primeros tres ataques, incluida su concavidad.
		var outline: PackedVector2Array = player.claw_finisher_polygon if step == 2 else player.claw_hitbox_polygon
		for polygon in Geometry2D.decompose_polygon_in_convex(outline):
			var shape := ConvexPolygonShape2D.new()
			shape.points = polygon
			shapes.append(shape)
		transform = player.hitbox.global_transform
	else:
		var shape := RectangleShape2D.new()
		shape.size = size
		shapes.append(shape)
	var query := PhysicsShapeQueryParameters2D.new()
	query.transform = transform
	query.collision_mask = 8
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var result: Array = []
	var excluded: Array[RID] = []
	for shape in shapes:
		query.shape = shape
		while true:
			query.exclude = excluded
			var hits := get_world_2d().direct_space_state.intersect_shape(query, 32)
			if hits.is_empty():
				break
			for hit in hits:
				excluded.append(hit.rid)
				var enemy: Node2D = hit.collider
				if not enemy.has_method("take_hit") or not enemy.visible:
					continue
				var point: Vector2 = player._get_target_center(enemy)
				var ray := PhysicsRayQueryParameters2D.create(player.global_position + Vector2(0, -26), point, 2)
				if get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
					result.append(enemy)
	return result

func attack_rect() -> Rect2:
	var reach := float(move.get("reach", 0.0)) * (1.0 + charge_ratio * 0.25)
	var height := float(move.get("height", 0.0))
	var both: bool = move.get("kind") in ["spin", "slam"]
	var size := Vector2(reach * (2.0 if both else 1.0), height)
	var center := Vector2(0 if both else player.facing * (reach * 0.5 + 8), -30)
	return Rect2(center - size * 0.5, size)

func _strike(pulse: int) -> void:
	var rect := attack_rect()
	for enemy in _targets(player.global_position + rect.get_center(), rect.size, current_weapon() == &"unarmed" and not heavy and step < 3):
		if enemy in hit_sets[pulse]:
			continue
		hit_sets[pulse].append(enemy)
		if not heavy and enemy.has_method("try_block") and enemy.try_block(player.global_position):
			player._on_attack_blocked(enemy)
			return
		var damage := maxi(1, roundi(float(move.damage) * (1.0 + charge_ratio) * player.damage_multiplier * Ferocity.damage_multiplier() * (2.0 if player.riposte_attack else 1.0)))
		var direction := 1 if enemy.global_position.x >= player.global_position.x else -1
		enemy.take_hit(player.global_position, direction, damage)
		var core: Node = enemy.get_node_or_null("RubyCore")
		if core != null:
			core.stagger(float(move.stagger) * (1.0 + charge_ratio))
		if enemy.has_method("on_shine_hit"):
			enemy.on_shine_hit(direction, float(move.push) * (1.0 + charge_ratio))
		player._spawn_hit_feedback(enemy)
		Ferocity.add("weapon_" + str(current_weapon()) + ("_heavy" if heavy else "_light"), 6.0 + step * 2.0, "COMBO %d" % (step + 1))
		Sfx.play("hit_heavy" if heavy else "hit_light")
		if not player.is_on_floor():
			player._apply_light_hit_air_boost()

func _breath_hit() -> void:
	for enemy in _targets(player.global_position + Vector2(player.facing * 105, -32), Vector2(180, 75)):
		enemy.take_hit(player.global_position, player.facing, maxi(1, roundi(player.damage_multiplier)))
		Ferocity.add("beast_breath", 2.0, "ALIENTO JADE")

func _update_aim() -> void:
	if InputHints.device == InputHints.Device.KEYBOARD:
		var direction := player.get_global_mouse_position() - (player.global_position + Vector2(0, -26))
		if direction.length() > 12:
			aim_direction = direction.normalized()
	else:
		var direction := Vector2.ZERO
		for device in Input.get_connected_joypads():
			direction = Vector2(Input.get_joy_axis(device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y))
			if direction.length() > 0.25:
				break
		if direction.length() > 0.25:
			aim_direction = direction.normalized()
		elif Input.is_action_just_pressed("throw_knife"):
			aim_direction = Vector2(player.facing, 0)

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	var id := current_weapon()
	if display_texture != id:
		display_texture = id
		weapon_sprite.texture = Catalog.texture(id)
	weapon_sprite.visible = id != &"unarmed" and not player.liquid_beast and not player.dead and player.execution_core == null
	weapon_sprite.position = Vector2(player.facing * 20, -26)
	weapon_sprite.scale = Vector2(player.facing * 0.72, 0.72)
	weapon_sprite.rotation = -0.7 * player.facing
	if aim:
		weapon_sprite.scale = Vector2.ONE * 0.72
		weapon_sprite.rotation = aim_direction.angle()
	elif active:
		var t := clampf(elapsed / maxf(duration, 0.001), 0, 1)
		var angle := lerpf(-1.5, 1.3, t)
		if move.kind in ["stab", "lunge"]:
			angle = 0.0
			weapon_sprite.position.x += player.facing * sin(t * PI) * 30.0
		elif move.kind == "spin":
			angle = t * TAU * float(move.pulses)
		elif charging:
			angle = -1.8
		weapon_sprite.rotation = angle * player.facing
	if player.common_moves.enabled:
		if player.attack_mode == player.ATTACK_SPIN:
			weapon_sprite.rotation = player.hitbox.rotation * player.facing
		elif player.attack_mode == player.ATTACK_UPPERCUT:
			weapon_sprite.rotation = -1.2 * player.facing
		elif player.attack_mode == player.ATTACK_HEAVY:
			weapon_sprite.rotation = 1.2 * player.facing
	var text := "LIQUID BEAST" if player.liquid_beast else str(Catalog.NAMES[id])
	if is_instance_valid(player.thrown_knife):
		text += " · arma fuera"
	if charging:
		text += " · Carga %d%%" % roundi(charge / CHARGE_TIME * 100)
	if aim:
		text += " · %s: %s" % [InputHints.binding("weapon_throw"), "Lanzar" if player.has_knife else "Recuperar"]
	else:
		text += " · %s: transformar" % InputHints.binding("transform")
	status.text = text

func _draw() -> void:
	if aim:
		var origin := Vector2(0, -26)
		var end := origin + aim_direction * 165.0
		draw_line(origin + aim_direction * 40, end, Color(0.5, 1, 0.75, 0.6), 2, true)
		draw_arc(end, 8, 0, TAU, 16, Color(0.8, 1, 0.65), 2, true)
	if active and not charging:
		var rect := attack_rect()
		if player.show_hitbox_debug:
			draw_rect(rect, Color(0.5, 1, 0.7, 0.15))
			draw_rect(rect, Color(0.5, 1, 0.7), false, 2)
		var progress := clampf(elapsed / maxf(duration, 0.001), 0, 1)
		var color := Color(0.7, 1.0, 0.8, sin(progress * PI) * 0.8)
		if move.kind in ["stab", "lunge", "kick"]:
			draw_line(Vector2(player.facing * 28, -30), Vector2(player.facing * float(move.reach), -30), color, 7, true)
		else:
			draw_set_transform(Vector2(0, -30), 0, Vector2(player.facing, 0.65))
			var angle := progress * TAU * float(move.pulses) if move.kind == "spin" else lerpf(-1.5, 1.5, progress)
			draw_arc(Vector2.ZERO, float(move.reach), angle - 0.8, angle, 20, color, 5, true)
			draw_set_transform(Vector2.ZERO)
	if breath:
		var texture: Texture2D = preload("res://jade_fire_visual.gd").TEXTURE
		var cell := texture.get_size() * 0.5
		var clock := Time.get_ticks_msec() * 0.001
		draw_set_transform(Vector2(player.facing * 32, -32), 0, Vector2(player.facing, 1))
		for index in range(4):
			var frame := (int(clock * 16) + index) % 4
			var t := float(index) / 3.0
			var width := 76.0 + t * 40.0
			var height := 62.0 + t * 32.0
			var rect := Rect2(Vector2(index * 31.0 - 20, -height * 0.5 + sin(clock * 12 + index) * 4), Vector2(width, height))
			var region := Rect2(Vector2(frame % 2, frame / 2) * cell, cell)
			draw_texture_rect_region(texture, rect, region, Color(1, 1, 1, 0.8 - t * 0.3))
		draw_set_transform(Vector2.ZERO)
