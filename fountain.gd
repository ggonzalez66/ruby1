extends "res://run_rest_area.gd"

# Fuente de curación de la run: un claro con una poza de agua clara al pie de un manantial. Al meterse
# en el agua Viridy recupera toda la vida (una sola vez: después la fuente queda en calma). La salida a
# la derecha vuelve al mapa.

const TERRAIN := preload("res://sanctuary_ground.gd")
const WATER := preload("res://shaders/sanctuary_water.gdshader")
const SURFACE_Y := 60.0
const POOL := [Vector2(1175, 60), Vector2(2825, 60), Vector2(2650, 210), Vector2(1350, 210)]
const HEAL_COLOR := Color(0.45, 1.0, 0.6)

var used := false
var water: Polygon2D
var pool_area: Area2D
var cross: Node2D
var sparkles: CPUParticles2D
var wade_left := 0.0

func _title() -> String:
	return "FUENTE DE CURACIÓN"

func _build_level() -> void:
	var ground := TERRAIN.new()
	ground.name = "FountainGround"
	ground.outline = PackedVector2Array([
		Vector2(0, 0), Vector2(1100, 0), Vector2(1350, 210), Vector2(2650, 210), Vector2(2900, 0),
		Vector2(width, 0), Vector2(width, 1200), Vector2(0, 1200),
	])
	ground.surface_count = 6
	add_child(ground)
	_build_spring()
	_build_water()

func _build_spring() -> void:
	# Roca del manantial detrás de la poza con su chorro de agua.
	var rock := Polygon2D.new()
	rock.z_index = -4
	rock.color = Color("4f5d4f")
	rock.polygon = PackedVector2Array([Vector2(1820, 70), Vector2(1860, -260), Vector2(1960, -380), Vector2(2080, -360),
		Vector2(2170, -240), Vector2(2200, 70)])
	add_child(rock)
	var moss := Polygon2D.new()
	moss.z_index = -4
	moss.color = Color("6f9550")
	moss.polygon = PackedVector2Array([Vector2(1860, -260), Vector2(1960, -380), Vector2(2080, -360), Vector2(2170, -240),
		Vector2(2120, -250), Vector2(2060, -330), Vector2(1970, -345), Vector2(1890, -250)])
	add_child(moss)
	var stream := Polygon2D.new()
	stream.z_index = -3
	stream.color = Color(0.75, 0.97, 0.9, 0.65)
	stream.polygon = PackedVector2Array([Vector2(1995, -330), Vector2(2035, -330), Vector2(2050, 60), Vector2(1980, 60)])
	add_child(stream)
	# Cruz de curación flotando sobre la fuente.
	cross = Node2D.new()
	cross.position = Vector2(2010, -520)
	cross.z_index = 2
	add_child(cross)
	for size in [Vector2(46, 130), Vector2(130, 46)]:
		var glow := Polygon2D.new()
		glow.color = Color(HEAL_COLOR, 0.25)
		glow.polygon = _rect_points(size + Vector2(26, 26))
		cross.add_child(glow)
	for size in [Vector2(40, 120), Vector2(120, 40)]:
		var arm := Polygon2D.new()
		arm.color = HEAL_COLOR
		arm.polygon = _rect_points(size)
		cross.add_child(arm)
	var bob := cross.create_tween().set_loops()
	bob.tween_property(cross, "position:y", -545.0, 1.4).set_trans(Tween.TRANS_SINE)
	bob.tween_property(cross, "position:y", -520.0, 1.4).set_trans(Tween.TRANS_SINE)

func _rect_points(size: Vector2) -> PackedVector2Array:
	var half := size * 0.5
	return PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)])

func _build_water() -> void:
	var pixel := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	pixel.fill(Color.WHITE)
	water = Polygon2D.new()
	water.name = "FountainWater"
	water.texture = ImageTexture.create_from_image(pixel)
	water.z_index = 1
	water.polygon = PackedVector2Array(POOL)
	water.uv = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(0.9, 1), Vector2(0.1, 1)])
	var material := ShaderMaterial.new()
	material.shader = WATER
	water.material = material
	add_child(water)
	pool_area = Area2D.new()
	pool_area.name = "HealingPool"
	pool_area.collision_layer = 0
	pool_area.collision_mask = 1
	var shape := CollisionPolygon2D.new()
	shape.polygon = water.polygon
	pool_area.add_child(shape)
	add_child(pool_area)
	# Física de agua (water_zone.gd): dentro de la poza Viridy se mueve lenta y pesada. La poza ya se dibuja.
	var zone: Node2D = preload("res://water_zone.gd").new()
	zone.name = "PoolWater"
	zone.draw_body = false
	zone.position = Vector2(2000, SURFACE_Y)
	zone.size = Vector2(1500, 150)
	add_child(zone)
	sparkles = CPUParticles2D.new()
	sparkles.position = Vector2(2000, SURFACE_Y)
	sparkles.z_index = 2
	sparkles.amount = 40
	sparkles.lifetime = 2.2
	sparkles.preprocess = 2.0
	sparkles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sparkles.emission_rect_extents = Vector2(780, 4)
	sparkles.direction = Vector2.UP
	sparkles.spread = 15
	sparkles.gravity = Vector2(0, -12)
	sparkles.initial_velocity_min = 20
	sparkles.initial_velocity_max = 60
	sparkles.scale_amount_min = 2
	sparkles.scale_amount_max = 4
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(HEAL_COLOR, 0.0), Color(HEAL_COLOR, 0.8), Color(HEAL_COLOR, 0.0)])
	fade.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	sparkles.color_ramp = fade
	add_child(sparkles)
	# Ondas de PixelFX que laten sobre la superficie de la poza, desfasadas.
	for index in range(6):
		var ripple: AnimatedSprite2D = PixelFx.play(self, "ripples", Vector2(1380 + index * 250 + randf_range(-40, 40), SURFACE_Y + 26 + (index % 2) * 34), randf_range(0.9, 1.3), [], {"loop": true, "z": 2, "modulate": Color(1, 1, 1, 0.55)})
		if ripple != null:
			ripple.name = "PoolRipple%d" % index
			ripple.frame = randi() % ripple.sprite_frames.get_frame_count(&"default")

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or player.dead:
		return
	var inside: bool = pool_area.overlaps_body(player) and player.global_position.y > SURFACE_Y + 10.0
	# Al vadear, la poza se ondula donde está Viridy.
	wade_left -= delta
	if inside and wade_left <= 0.0:
		wade_left = 0.45 if absf(player.velocity.x) > 40.0 else 0.9
		PixelFx.play(self, "ripples", Vector2(player.global_position.x, SURFACE_Y + 4.0), 0.7, [], {"speed": 1.6, "z": 3, "modulate": Color(1, 1, 1, 0.8)})
	if used:
		return
	if not inside:
		hint_label.text = "Métete en el agua de la fuente para curarte"
		return
	if player.current_health >= player.max_health:
		hint_label.text = "Ya tienes la vida al máximo: la fuente te espera"
		return
	heal_player()

func heal_player() -> int:
	# Toda la vida de vuelta; la fuente se calma y deja de brillar.
	used = true
	var healed: int = player.heal(player.max_health - player.current_health)
	Sfx.play("ruby_gain", 0.0, 0.8)
	Fx.text(self, player.global_position + Vector2(0, -110), "¡CURACIÓN!", HEAL_COLOR)
	Fx.puff(self, player.global_position + Vector2(0, -30), Color(HEAL_COLOR, 0.9))
	# Una flor de luz se abre junto a Viridy al curarse.
	Fx.bloom(self, player.global_position + Vector2(-player.facing * 34.0, 0.0), 1.3)
	sparkles.emitting = false
	cross.create_tween().tween_property(cross, "modulate:a", 0.15, 1.0)
	hint_label.text = "La fuente te devolvió %d de vida" % healed
	return healed
