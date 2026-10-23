extends SceneTree

# Sprites nuevos de Rengar (de pie respirando, pose orgullosa, caminar, sprint, mantle, enganche a la
# pared, dash attack), la pose orgullosa que sube el medidor de estilo, el cuchillo nuevo con su
# hitbox alargada y el Metatrón nuevo teñido por el desgaste.
# Uso (desde la raíz del proyecto): godot --headless --path . -s res://tests/integration/test_sprites.gd

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

func _run() -> void:
	F = root.get_node("Ferocity")
	level = load("res://main.tscn").instantiate()
	root.add_child(level)
	await frames(10)
	player = get_first_node_in_group(&"player")

	print("== Animaciones nuevas")
	var sprite_frames: SpriteFrames = player.animated_sprite.sprite_frames
	var expected := {"idle": [6, "viridy_idle"], "proud": [3, "viridy_proud"], "proud_loop": [2, "viridy_proud"], "walk": [8, "viridy_walk_v2"], "sprint": [6, "viridy_sprint_feral"], "wallride": [5, "viridy_wallrun"], "mantle": [1, "viridy_mantle"], "wall_slide": [1, "viridy_wall_cling"], "charge": [1, "viridy_dash_attack"], "jump": [3, "viridy_jump"], "jump_squat": [1, "viridy_jump_squat"], "fall": [1, "viridy_jump"], "roar": [1, "viridy_roar.png"], "backflip": [1, "viridy_backflip"], "uppercut": [2, "viridy_liquid_beast_v2"], "wall_jump": [1, "viridy_wall_jump"], "long_jump": [1, "viridy_wall_jump"], "heavy_aerial": [2, "viridy_liquid_beast"], "ground_heavy": [2, "viridy_liquid_beast"], "heavy_landing": [2, "viridy_liquid_landing"], "ruby_chew": [2, "viridy_liquid_beast"], "liquid_launch": [2, "viridy_liquid_beast_v2"], "dash": [2, "viridy_liquid_dash"], "roar_hold": [1, "viridy_roar_hold"], "aerial_stall": [1, "viridy_aerial_stall"], "frontflip": [1, "viridy_frontflip"], "spin": [4, "viridy_liquid_ouroboros"], "sprint_brake": [1, "viridy_brake"], "brake_recover": [1, "viridy_brake_recover"], "proud_roar": [1, "viridy_proud"]}
	for anim in expected:
		var texture := sprite_frames.get_frame_texture(anim, 0)
		var path: String = texture.atlas.resource_path if texture is AtlasTexture else texture.resource_path
		check(sprite_frames.get_frame_count(anim) == expected[anim][0] and path.contains(expected[anim][1]), "%s: %d frames de %s" % [anim, sprite_frames.get_frame_count(anim), path.get_file()])
	var mantle: AtlasTexture = sprite_frames.get_frame_texture("mantle", 0)
	check(mantle.region.position.x > 543.0 * 2.0 and mantle.region.end.x < 543.0 * 3.0, "mantle: solo el tercer frame")
	# Los pies quedan en el origen: el borde de abajo del frame en y = 0.
	for anim in ["idle", "proud", "walk", "sprint", "mantle", "charge", "jump", "jump_squat", "roar", "backflip", "uppercut", "wall_jump", "heavy_aerial", "dash", "roar_hold", "frontflip", "sprint_brake", "brake_recover", "proud_roar"]:
		player.animated_sprite.play(StringName(anim))
		player._align_character_animation(StringName(anim))
		var height: float = sprite_frames.get_frame_texture(anim, 0).get_height() * player.animated_sprite.scale.y
		check(abs(player.animated_sprite.position.y + height * 0.5) < 0.5 and height > 45.0 and height < 140.0, "%s: alineado a los pies (alto %.0f px)" % [anim, height])

	var proud_cells := {}
	for i in range(sprite_frames.get_frame_count("proud")):
		proud_cells[sprite_frames.get_frame_texture("proud", i).region] = true
	check(proud_cells.size() <= 3, "orgulloso: como mucho 3 frames distintos (%d)" % proud_cells.size())
	print("== Mordida líquida orientada hacia la caída")
	var ouroboros_image: Image = player.LIQUID_SPIN_SHEET.get_image()
	if ouroboros_image.is_compressed():
		ouroboros_image.decompress()
	for frame in range(sprite_frames.get_frame_count(&"spin")):
		var loop_texture: AtlasTexture = sprite_frames.get_frame_texture(&"spin", frame)
		check(ouroboros_image.get_pixelv(Vector2i(loop_texture.region.get_center())).a < 0.08, "ouroboros #%d: centro transparente y cuerpo alrededor" % frame)
	for facing in [-1, 1]:
		player.facing = facing
		player.velocity = Vector2(facing * 400, 900)
		player._update_character_orientation(&"heavy_aerial")
		var bite_direction := Vector2(facing, 0).rotated(player.animated_sprite.rotation)
		check(bite_direction.y > 0.8 and signf(bite_direction.x) == facing and player.animated_sprite.flip_h == (facing < 0), "la mordida diagonal apunta abajo y hacia %d" % facing)
		player.velocity = Vector2(0, 2000)
		player._update_character_orientation(&"heavy_aerial")
		bite_direction = Vector2(facing, 0).rotated(player.animated_sprite.rotation)
		check(bite_direction.dot(Vector2.DOWN) > 0.99, "el picado apunta al suelo mirando hacia %d" % facing)
		player._update_character_orientation(&"uppercut")
		bite_direction = Vector2(facing, 0).rotated(player.animated_sprite.rotation)
		check(bite_direction.y < -0.9 and signf(bite_direction.x) == facing, "la mordida del uppercut apunta arriba mirando hacia %d" % facing)

	# Ningún frame se mete en la celda del vecino: los bordes laterales de cada región (salvo el borde de la
	# hoja) tienen que estar vacíos; si no, se ve un pedazo del frame de al lado (pasó con el sprint).
	# Las hojas viejas de golpes ligeros y pesado tocan el borde sin cruzarlo, se dejan fuera.
	var touching_ok := ["viridy_ground_heavy.png", "viridy_light_hits.png"]
	var images := {}
	for anim in sprite_frames.get_animation_names():
		for i in range(sprite_frames.get_frame_count(anim)):
			var frame_texture := sprite_frames.get_frame_texture(anim, i)
			if not frame_texture is AtlasTexture or frame_texture.atlas.resource_path.get_file() in touching_ok:
				continue
			var path: String = frame_texture.atlas.resource_path
			if not images.has(path):
				images[path] = frame_texture.atlas.get_image()
			var image: Image = images[path]
			var region: Rect2i = Rect2i(frame_texture.region)
			var opaque := 0
			for column in [region.position.x, region.end.x - 1]:
				if column == 0 or column == image.get_width() - 1:
					continue
				for y in range(region.position.y, region.end.y):
					if image.get_pixel(column, y).a > 0.08:
						opaque += 1
			check(opaque == 0, "%s #%d: sin pedazos del frame vecino en los bordes (%d px)" % [anim, i, opaque])

	print("== Salto y uppercut")
	release_all()
	player._respawn_player()
	player.global_position = GROUND
	await frames(10)
	Input.action_press("jump")
	await frames(2)
	check(player.animated_sprite.animation == &"jump_squat", "al despegar del suelo: agachado")
	await frames(8)
	check(player.animated_sprite.animation == &"jump", "luego los frames del aire")
	Input.action_release("jump")
	await frames(60)
	Input.action_press("move_up")
	Input.action_press("heavy_attack")
	await frames(1)
	Input.action_release("heavy_attack")
	Input.action_release("move_up")
	await frames(int(player.light_uppercut_duration * 60.0) + 2)
	check(player.attack_mode != player.ATTACK_UPPERCUT and player.animated_sprite.animation == &"uppercut", "la pose del uppercut se mantiene mientras sube")
	await frames(60)

	print("== Pose orgullosa")
	release_all()
	F.reset()
	player._respawn_player()
	player.global_position = GROUND
	await frames(30)
	check(not player.proud_active, "recién quieto: de pie")
	for i in range(int(player.proud_delay * 60.0) + 60):
		await frames(1)
		if player.proud_active:
			break
	await frames(2)
	check(player.proud_active and player.animated_sprite.animation == &"proud_roar", "tras %.0f s quieto: primero ruge" % player.proud_delay)
	var waves := level.get_children().filter(func(n): return n.get_child_count() > 0 and n.get_child(0) is Line2D and n.z_index == 4)
	check(not waves.is_empty(), "con la onda del rugido")
	await frames(int(player.PROUD_ROAR_TIME * 60.0) + 4)
	check(player.animated_sprite.animation == &"proud", "y luego la pose orgullosa")
	await frames(int(3.0 / player.PROUD_FPS * 60.0) + 4)
	check(player.animated_sprite.animation == &"proud_loop", "tras un ciclo, repite sus 2 últimos frames")
	var loop_cells := {}
	for i in range(sprite_frames.get_frame_count("proud_loop")):
		loop_cells[sprite_frames.get_frame_texture("proud_loop", i).region.position.x] = true
	check(loop_cells.keys() == [768.0 * 2.0, 768.0 * 3.0], "que son los frames 3 y 4 de la hoja (%s)" % str(loop_cells.keys()))
	var before: float = F.points
	await frames(60)
	check(F.points > before + 3.0, "y el medidor de estilo sube (%.1f → %.1f)" % [before, F.points])
	await frames(900)
	check(F.rank == 0 and F.points <= 100.0, "sube sin pasar de rango (%.1f)" % F.points)
	Input.action_press("move_right")
	await frames(3)
	Input.action_release("move_right")
	check(not player.proud_active, "al moverse sale de la pose")

	print("== Cuchillo nuevo")
	var knife: Node2D = load("res://knife.gd").new()
	level.add_child(knife)
	await frames(1)
	check(knife.sprite.texture.resource_path.ends_with("viridy_knife.png"), "usa el sprite nuevo")
	var length: float = knife.KNIFE_REGION.size.length() * knife.VISUAL_SCALE
	check(length > 52.0 and length < 64.0, "un 30 %% más largo que antes (%.0f px)" % length)
	var target: Node2D = load("res://training_dummy.tscn").instantiate()
	target.aerial = true
	target.max_health = 99
	target.position = Vector2(2800, -300)
	level.add_child(target)
	await frames(3)
	var center: Vector2 = target.global_position + target.impact_offset
	var axis := Vector2.RIGHT
	knife.rotation = axis.angle() - knife.TIP_ANGLE
	knife.global_position = center - axis * 36.0
	check(knife._find_enemy([]) == target, "la punta alcanza a 36 px del centro (antes, radio 14)")
	knife.global_position = center + axis.orthogonal() * 40.0
	check(knife._find_enemy([]) == null, "pero no de lado a 40 px (hitbox alargada, no redonda)")
	knife.queue_free()
	target.queue_free()

	print("== Metatrón nuevo")
	check(player.roar_aura.texture != null and player.roar_aura.texture.resource_path.ends_with("metatronNEW.png"), "el aura usa el sprite nuevo")
	player._change_shine_durability(-60.0)
	await frames(1)
	var amount: float = player.roar_aura.wear_material.get_shader_parameter("glow_amount")
	check(abs(amount - 0.6 * 0.85) < 0.03, "se tiñe de rojo según el desgaste (%.2f)" % amount)

	print("== Melena evanescente (emisor)")
	F.reset()
	release_all()
	player._respawn_player()
	player.global_position = GROUND
	await frames(10)
	var mane: CPUParticles2D = player.mane_emitter
	check(mane != null and mane.emitting, "el emisor de la melena está activo")
	check(mane.get_index() < player.animated_sprite.get_index(), "se dibuja detrás del sprite")
	check(not mane.local_coords, "las motas se quedan en el mundo (estela al moverse)")
	for side in [1.0, -1.0]:
		player.facing = side
		await frames(2)
		check(mane.position.y < -30.0, "mirando %s: la melena está arriba (y %.0f)" % ["derecha" if side > 0 else "izquierda", mane.position.y])
		check(sign(mane.position.x) == -side or abs(mane.position.x) < 4.0, "mirando %s: hacia atrás de la cara (x %.0f)" % ["derecha" if side > 0 else "izquierda", mane.position.x])
		check(sign(mane.direction.x) == -side, "las motas salen hacia atrás")
	player.facing = 1.0
	for anim in ["sprint", "jump", "uppercut", "wall_slide", "roar", "backflip"]:
		player.animated_sprite.play(StringName(anim))
		player._align_character_animation(StringName(anim))
		mane.follow(player.animated_sprite, 1.0, true)
		var extents: Vector2 = mane.emission_rect_extents
		check(extents.x > 2.0 and extents.y > 2.0 and mane.position.length() < 120.0, "%s: zona de la melena razonable (pos %s, mitad %s)" % [anim, mane.position.round(), extents.round()])
	player.invulnerability_timer = 0.0
	player.take_damage(9999, player.global_position + Vector2(40, 0))
	await frames(2)
	check(player.dead and not mane.emitting, "al morir deja de echar motas")
	player._respawn_player()
	await frames(3)
	check(mane.emitting, "y vuelve al reaparecer")
	for rank in [0, 5]:
		F.points = rank * F.RANK_POINTS + 1.0
		F.rank = rank
		await frames(2)
		var mid: Color = mane.color_ramp.get_color(1)
		check(Color(mid, 1.0).is_equal_approx(Color(F.RANKS[rank]["color"], 1.0)), "con rango %s la melena es de su color (%s)" % [F.RANKS[rank]["letter"], mid.to_html(false)])
	F.reset()

	print("== Destello de imparable (color del rango de estilo)")
	player.riposte_timer = 0.0
	player.unstoppable_glow = true
	var seen_colors := {}
	for i in range(8):
		player._update_riposte_visual()
		var glow: Color = player.charge_glow_material.get_shader_parameter("glow_color")
		seen_colors[glow.to_html()] = true
		var rank_color: Color = F.style_color()
		check(glow.is_equal_approx(rank_color) or glow.is_equal_approx(F.style_light(rank_color)), "destello %d: color del rango o su versión clara (%s)" % [i, glow.to_html()])
		OS.delay_msec(30)
	check(seen_colors.size() == 2, "alterna entre los dos colores")
	var trail: Color = player.afterimage_unstoppable_material.get_shader_parameter("glow_color")
	check(trail.is_equal_approx(F.rank_info()["color"]), "las estelas siguen con el color del rango")
	player.unstoppable_glow = false
	player._update_riposte_visual()

	print("== Rugido: grito y guardia")
	release_all()
	player._respawn_player()
	player.global_position = GROUND
	await frames(10)
	Input.action_press("roar")
	await frames(3)
	check(player.animated_sprite.animation == &"roar", "al rugir: el grito")
	await frames(int(player.ROAR_SHOUT_TIME * 60.0) + 4)
	check(player.roar_active and player.animated_sprite.animation == &"roar_hold", "manteniendo el rugido: la guardia")
	Input.action_release("roar")
	await frames(30)

	print("== Frontflip y aerial stall")
	release_all()
	player._respawn_player()
	player.global_position = GROUND + Vector2(0, -400)
	await frames(2)
	player.velocity = Vector2.ZERO
	player.air_jumps_remaining = 1
	player._perform_frontflip()
	await frames(2)
	check(player.animated_sprite.animation == &"frontflip", "el frontflip usa la pose encogida")
	check(abs(player.animated_sprite.rotation) > 0.01, "y gira")
	var spin_frames: int = int(player.frontflip_rotation_duration * 60.0) + 3
	check(abs(player.frontflip_rotation_duration - player._get_flip_airtime(player.jump_velocity)) < 0.001, "el primer frontflip gira en todo el vuelo (velocidad de siempre)")
	await frames(spin_frames)
	check(player.frontflip_active and player.animated_sprite.animation == &"aerial_stall", "tras la vuelta: aerial stall (%s)" % player.animated_sprite.animation)
	check(abs(player.animated_sprite.rotation) < 0.01, "derecho")

	print("== Backflip y aerial stall")
	release_all()
	player._respawn_player()
	player.global_position = GROUND + Vector2(0, -500)
	await frames(2)
	player.flip_streak = 0
	player._start_backflip()
	await frames(2)
	check(player.animated_sprite.animation == &"backflip", "el backflip gira con su pose")
	await frames(int(player.backflip_rotation_duration * 60.0) + 3)
	check(player.backflip_active and player.animated_sprite.animation == &"aerial_stall", "al terminar el giro: aerial stall (%s)" % player.animated_sprite.animation)

	print("== Flips encadenados más rápidos")
	release_all()
	player._respawn_player()
	player.global_position = GROUND + Vector2(0, -600)
	await frames(2)
	player.flip_streak = 0
	player._start_backflip()
	var first_backflip: float = player.backflip_rotation_duration
	check(abs(first_backflip - player._get_backflip_airtime() * player.BACKFLIP_SPIN_FRACTION) < 0.001, "el backflip gira algo más rápido que el vuelo (%.2f s de %.2f)" % [first_backflip, player._get_backflip_airtime()])
	player._start_backflip()
	check(player.backflip_rotation_duration < first_backflip * 0.7, "el 2º backflip seguido gira más rápido (%.2f s)" % player.backflip_rotation_duration)
	player._perform_frontflip()
	check(player.frontflip_rotation_duration < player._get_flip_airtime(player.jump_velocity) * player.FRONTFLIP_SPIN_FRACTION * 0.7, "y un frontflip detrás, también")
	player.backflip_active = false
	player.frontflip_active = false
	player.velocity = Vector2.ZERO
	player.global_position = GROUND
	await frames(20)
	check(player.flip_streak == 0, "al quedarse en el suelo se reinicia la racha")

	print("== Frenado y vuelta al reposo")
	release_all()
	player._respawn_player()
	player.global_position = GROUND
	await frames(10)
	player.velocity.x = player.sprint_speed
	await frames(2)
	check(player.animated_sprite.animation == &"sprint_brake", "frenando la carrera: pose de frenar")
	var saw_recover := false
	for i in range(40):
		await frames(1)
		if player.animated_sprite.animation == &"brake_recover":
			saw_recover = true
			break
	check(saw_recover, "al acabar de frenar: el intermedio")
	await frames(int(player.BRAKE_RECOVER_TIME * 60.0) + 4)
	check(player.animated_sprite.animation == &"idle", "y luego quieto")

	print("RESULTADO: %d/%d OK" % [checks - fails, checks])
	quit()
