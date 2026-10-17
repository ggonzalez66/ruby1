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
	var expected := {"idle": [6, "rengar_standing"], "proud": [4, "reng_standingProud"], "walk": [8, "reng_walkingNew"], "sprint": [3, "reng_sprintingNEW"], "wallride": [5, "reng_wallrun"], "mantle": [1, "reng_mantling"], "wall_slide": [1, "reng_cling_wallNEW"], "charge": [1, "reng_dashattackNEW"], "jump": [3, "reng_jumpingNEW3"], "jump_squat": [1, "reng_jumpingNEW1"], "fall": [1, "reng_jumpingNEW3"], "roar": [1, "reng_aerialStallNEW"], "backflip": [1, "reng_backflipNEW"], "uppercut": [1, "reng_uppercutNEW"], "wall_jump": [1, "reng_jump_off_wall"], "long_jump": [1, "reng_jump_off_wall"], "heavy_aerial": [1, "reng_heavy_aerialNEW1"]}
	for anim in expected:
		var texture := sprite_frames.get_frame_texture(anim, 0)
		var path: String = texture.atlas.resource_path if texture is AtlasTexture else texture.resource_path
		check(sprite_frames.get_frame_count(anim) == expected[anim][0] and path.contains(expected[anim][1]), "%s: %d frames de %s" % [anim, sprite_frames.get_frame_count(anim), path.get_file()])
	var mantle: AtlasTexture = sprite_frames.get_frame_texture("mantle", 0)
	check(mantle.region.position.x > 543.0 * 2.0 and mantle.region.end.x < 543.0 * 3.0, "mantle: solo el tercer frame")
	# Los pies quedan en el origen: el borde de abajo del frame en y = 0.
	for anim in ["idle", "proud", "walk", "sprint", "mantle", "charge", "jump", "jump_squat", "roar", "backflip", "uppercut", "wall_jump", "heavy_aerial"]:
		player.animated_sprite.play(StringName(anim))
		player._align_character_animation(StringName(anim))
		var height: float = sprite_frames.get_frame_texture(anim, 0).get_height() * player.animated_sprite.scale.y
		check(abs(player.animated_sprite.position.y + height * 0.5) < 0.5 and height > 45.0 and height < 140.0, "%s: alineado a los pies (alto %.0f px)" % [anim, height])

	var proud_cells := {}
	for i in range(sprite_frames.get_frame_count("proud")):
		proud_cells[sprite_frames.get_frame_texture("proud", i).region] = true
	check(proud_cells.size() <= 3, "orgulloso: como mucho 3 frames distintos (%d)" % proud_cells.size())

	# Ningún frame se mete en la celda del vecino: los bordes laterales de cada región (salvo el borde de la
	# hoja) tienen que estar vacíos; si no, se ve un pedazo del frame de al lado (pasó con el sprint).
	# Las hojas viejas de golpes ligeros y pesado tocan el borde sin cruzarlo, se dejan fuera.
	var touching_ok := ["reng-heavy.png", "reng_light_hits-sheet.png"]
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
	await frames(10)
	check(player.attack_mode != player.ATTACK_UPPERCUT and player.animated_sprite.animation == &"uppercut", "la pose del uppercut se mantiene mientras sube")
	await frames(60)

	print("== Pose orgullosa")
	release_all()
	F.reset()
	player._respawn_player()
	player.global_position = GROUND
	await frames(30)
	check(not player.proud_active, "recién quieto: de pie")
	await frames(int(player.proud_delay * 60.0) + 10)
	check(player.proud_active and player.animated_sprite.animation == &"proud", "tras %.0f s quieto: pose orgullosa" % player.proud_delay)
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
	check(knife.sprite.texture.resource_path.ends_with("reng_knifeNEW.png"), "usa el sprite nuevo")
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

	print("RESULTADO: %d/%d OK" % [checks - fails, checks])
	quit()
