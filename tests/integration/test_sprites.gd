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
	var expected := {"idle": [6, "rengar_standing"], "proud": [14, "reng_standingProud"], "walk": [8, "reng_walkingNew"], "sprint": [3, "reng_sprintingNEW"], "wallride": [5, "reng_wallrun"], "mantle": [1, "reng_mantling"], "wall_slide": [1, "reng_cling_wallNEW"], "charge": [1, "reng_dashattackNEW"]}
	for anim in expected:
		var texture := sprite_frames.get_frame_texture(anim, 0)
		var path: String = texture.atlas.resource_path if texture is AtlasTexture else texture.resource_path
		check(sprite_frames.get_frame_count(anim) == expected[anim][0] and path.contains(expected[anim][1]), "%s: %d frames de %s" % [anim, sprite_frames.get_frame_count(anim), path.get_file()])
	var mantle: AtlasTexture = sprite_frames.get_frame_texture("mantle", 0)
	check(mantle.region.position.x == 543.0 * 2.0, "mantle: solo el tercer frame")
	# Los pies quedan en el origen: el borde de abajo del frame en y = 0.
	for anim in ["idle", "proud", "walk", "sprint", "mantle", "charge"]:
		player.animated_sprite.play(StringName(anim))
		player._align_character_animation(StringName(anim))
		var height: float = sprite_frames.get_frame_texture(anim, 0).get_height() * player.animated_sprite.scale.y
		check(abs(player.animated_sprite.position.y + height * 0.5) < 0.5 and height > 45.0 and height < 140.0, "%s: alineado a los pies (alto %.0f px)" % [anim, height])

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

	print("RESULTADO: %d/%d OK" % [checks - fails, checks])
	quit()
