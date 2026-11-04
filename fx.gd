class_name Fx
extends RefCounted

# Efectos visuales breves que se crean en el nivel y se borran solos.

const SILVER: Array[Color] = [Color(0.2, 0.22, 0.3), Color(0.74, 0.79, 0.88), Color(1.0, 1.0, 1.0)]
const GOLD: Array[Color] = [Color(0.32, 0.16, 0.03), Color(1.0, 0.7, 0.14), Color(1.0, 0.97, 0.72)]
# Rugido: dorado brillante (más luminoso que el de los ataques pesados).
const ROAR: Array[Color] = [Color(0.4, 0.22, 0.02), Color(1.0, 0.8, 0.28), Color(1.0, 0.98, 0.82)]
const DUST := Color(0.86, 0.8, 0.66, 0.85)

# Llama residual visual: ni daño ni colisión, se borra al terminar su vida.
static func jade_splash(parent: Node, point: Vector2, normal: Vector2 = Vector2.UP, duration: float = 2.5, size: float = 1.0) -> void:
	var flame := Sprite2D.new()
	flame.name = "JadeFireResidue"
	flame.texture = preload("res://jade_fire_visual.gd").TEXTURE
	flame.hframes = 2
	flame.vframes = 2
	flame.frame = randi() % 4
	flame.scale = Vector2(0.065, 0.09) * size
	flame.rotation = normal.angle()
	flame.modulate.a = 0.65
	flame.z_index = 1
	parent.add_child(flame)
	flame.global_position = point
	var tween := flame.create_tween().set_parallel(true)
	tween.tween_property(flame, "modulate:a", 0.0, duration).set_delay(duration * 0.15)
	tween.tween_property(flame, "scale", flame.scale * 0.25, duration)
	tween.chain().tween_callback(flame.queue_free)

static func jade_burst(parent: Node, point: Vector2, size: float = 1.0) -> void:
	var burst := _spawn(parent, point)
	burst.name = "JadeFireBurst"
	burst.z_index = 6
	var tween := burst.create_tween().set_parallel(true)
	for index in range(12):
		var direction := Vector2.from_angle(TAU * index / 12.0)
		var flame := Sprite2D.new()
		flame.texture = preload("res://jade_fire_visual.gd").TEXTURE
		flame.hframes = 2
		flame.vframes = 2
		flame.frame = index % 4
		flame.scale = Vector2(0.07, 0.045) * size
		flame.rotation = direction.angle()
		burst.add_child(flame)
		tween.tween_property(flame, "position", direction * (60.0 + (index % 3) * 20.0) * size, 0.36).set_ease(Tween.EASE_OUT)
		tween.tween_property(flame, "scale", Vector2.ZERO, 0.36)
		tween.tween_property(flame, "modulate:a", 0.0, 0.30).set_delay(0.06)
	impact(parent, point, [Color(0.03, 0.15, 0.1), Color(0.22, 0.8, 0.45), Color(0.85, 1.0, 0.75)], size * 1.5)
	tween.chain().tween_callback(burst.queue_free)

# Impacto al conectar un golpe (PixelFX): chispa direccional; los fuertes suman el golpe contundente.
# La hoja es gris y se tiñe con la paleta [oscuro, medio, brillante] del golpe.
static func impact(parent: Node, point: Vector2, palette: Array[Color], size: float = 1.0) -> void:
	var options := {"rotation": randf_range(-0.6, 0.6), "flip": randf() < 0.5, "speed": 1.35, "z": 5}
	PixelFx.play(parent, "hit_spark", point, clampf(size * 1.3, 0.9, 3.0), palette, options)
	if size >= 1.5:
		PixelFx.play(parent, "hit_heavy", point + Vector2(0, 12), size * 0.75, palette, {"speed": 1.4, "z": 5})

# Ondas del rugido durante la apertura del parry; son visuales, sin hitbox adicional.
static func parry_wave(parent: Node, point: Vector2, radius: float, duration: float) -> void:
	var burst := _spawn(parent, point)
	burst.name = "RoarShockwaves"
	burst.z_index = 5
	var tween := burst.create_tween().set_parallel(true)
	for index in range(3):
		var ring := Line2D.new()
		ring.points = _circle(radius, 48, true)
		ring.width = 3.5 - index * 0.7
		ring.default_color = ROAR[2 if index == 0 else 1]
		ring.scale = Vector2.ONE * (0.05 + index * 0.03)
		ring.modulate.a = 0.0
		burst.add_child(ring)
		var delay := 0.04 + index * 0.015
		var life := maxf(duration, 0.08)
		tween.tween_property(ring, "scale", Vector2.ONE * (1.3 + index * 0.16), life).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(ring, "modulate:a", 0.65, 0.025).set_delay(delay)
		tween.tween_property(ring, "modulate:a", 0.0, life - 0.025).set_delay(delay + 0.025)
	tween.chain().tween_callback(burst.queue_free)

# Destello grande del deflect: anillo doble y rayos.
static func deflect(parent: Node, point: Vector2) -> void:
	PixelFx.play(parent, "parry", point + Vector2(0, 50), 1.3, [], {"speed": 1.3, "z": 6})
	impact(parent, point, ROAR, 1.4)
	text(parent, point + Vector2(0, -40), "¡DEFLECT!", Color(1.0, 0.95, 0.7))

# Polvo (PixelFX): nube baja que se abre hacia "direction" desde los pies.
static func dust(parent: Node, point: Vector2, direction: Vector2, count: int = 4, size: float = 1.0, _spread: float = 0.9) -> void:
	var scale: float = size * clampf(0.3 + count * 0.05, 0.35, 1.0)
	var palette: Array[Color] = [DUST.darkened(0.3), DUST.lightened(0.15), Color(1.0, 0.98, 0.92)]
	PixelFx.play(parent, "dust", point, scale, palette, {"flip": direction.x < 0.0, "speed": 1.5, "z": 3, "modulate": Color(1, 1, 1, 0.9)})

# Anillo de aire del doble salto.
static func air_ring(parent: Node, point: Vector2) -> void:
	var burst := _spawn(parent, point)
	var ring := Line2D.new()
	var points := PackedVector2Array()
	for index in range(17):
		var angle: float = TAU * index / 16.0
		points.append(Vector2(cos(angle) * 14.0, sin(angle) * 4.0))
	ring.points = points
	ring.width = 2.0
	ring.default_color = Color(0.95, 1.0, 0.92, 0.8)
	burst.add_child(ring)
	var tween := burst.create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(2.2, 2.2), 0.25)
	tween.tween_property(ring, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(burst.queue_free)

# Rugido de la pose orgullosa: dos ondas que se abren desde el pecho y polvo a los lados de los pies.
static func roar_wave(parent: Node, point: Vector2, feet: Vector2, color: Color) -> void:
	var burst := _spawn(parent, point)
	burst.z_index = 4
	var tween := burst.create_tween().set_parallel(true)
	for index in range(2):
		var ring := Line2D.new()
		ring.points = _circle(18.0, 32, true)
		ring.width = 3.0 - index
		ring.default_color = Color(color, 0.85) if index == 0 else Color(color.lightened(0.5), 0.7)
		burst.add_child(ring)
		var delay: float = index * 0.1
		tween.tween_property(ring, "scale", Vector2(5.5, 3.6), 0.45).set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(ring, "modulate:a", 0.0, 0.45).set_delay(delay)
	tween.chain().tween_callback(burst.queue_free)
	dust(parent, feet, Vector2.LEFT, 5, 1.5, 0.4)
	dust(parent, feet, Vector2.RIGHT, 5, 1.5, 0.4)

# Shine de un enemigo: un Cubo de Metatrón de su color que aparece de golpe y se desvanece girando.
static func shine(parent: Node, point: Vector2, color: Color, radius: float = 36.0) -> void:
	var burst := _spawn(parent, point)
	burst.z_index = 5
	var cube: Node2D = load("res://metatron_cube.gd").new()
	cube.outer_radius = radius
	cube.line_color = Color(color, 0.95)
	cube.glow_color = Color(color.darkened(0.3), 0.25)
	cube.line_width = 1.5
	burst.add_child(cube)
	cube.modulate = Color(1.4, 1.4, 1.4)
	var tween := burst.create_tween().set_parallel(true)
	tween.tween_property(cube, "rotation", 0.9, 0.35)
	tween.tween_property(cube, "scale", Vector2.ONE * 1.15, 0.35)
	tween.tween_property(cube, "modulate:a", 0.0, 0.35).set_delay(0.1)
	tween.chain().tween_callback(burst.queue_free)
	impact(parent, point, [color.darkened(0.6), color, Color(1.0, 0.97, 0.95)], 1.2)

# Rotura (PixelFX): estallido de energía del color de lo que se rompe, del tamaño de su radio.
static func shatter(parent: Node, point: Vector2, color: Color, radius: float = 46.0) -> void:
	var sprite: AnimatedSprite2D = PixelFx.play(parent, "burst", point + Vector2(0, 8), clampf(radius / 80.0, 0.5, 2.0), _palette(color), {"speed": 1.4, "z": 6})
	if sprite != null:
		sprite.name = "ShatterBurst"
	impact(parent, point, [color.darkened(0.6), color, Color(1.0, 0.9, 0.85)], 1.8)

# Crítico al núcleo (PixelFX): destello, anillo partido y chispas; el cristal sigue entero.
static func ruby_critical(parent: Node, point: Vector2, color: Color) -> void:
	PixelFx.play(parent, "crit", point + Vector2(0, 30), 1.0, _palette(color), {"speed": 1.2, "z": 14})

# Nubecilla para cosas que desaparecen (proyectiles contra la pared, refuerzos que llegan).
static func puff(parent: Node, point: Vector2, color: Color) -> void:
	PixelFx.play(parent, "poof", point + Vector2(0, 14), 0.45, _palette(color), {"speed": 1.8, "z": 5})

# Explosión de fuego (PixelFX): misiles, enemigos que caen al vacío, cámaras destruidas.
static func explosion(parent: Node, point: Vector2, size: float = 1.0) -> void:
	PixelFx.play(parent, "explosion", point + Vector2(0, 28) * size, size, [], {"speed": 1.6, "z": 7})

# Explosión enorme con hongo de humo (la caída de la araña).
static func big_explosion(parent: Node, point: Vector2, size: float = 1.0) -> void:
	PixelFx.play(parent, "big_explosion", point, size, [], {"speed": 1.15, "z": 7})

# Curación: anillo de luz con destellos a los pies de quien se cura; lo sigue mientras dura.
static func heal(target: Node2D, color: Color = Color(0.45, 1.0, 0.6)) -> void:
	if target == null or not target.is_inside_tree():
		return
	PixelFx.play(target, "heal", Vector2.ZERO, 0.55, _palette(color), {"follow": target, "speed": 1.3, "z": 2})

# Portal de aparición en el suelo (refuerzos que llegan).
static func warp_in(parent: Node, point: Vector2, color: Color) -> void:
	PixelFx.play(parent, "warp_in", point + Vector2(0, 6), 0.75, _palette(color), {"speed": 1.6, "z": 3})

# Carga de energía (railgun, embestidas): devuelve el sprite para poder quitarlo si se interrumpe.
static func charge(parent: Node, point: Vector2, color: Color, size: float = 1.0, speed: float = 1.0) -> AnimatedSprite2D:
	return PixelFx.play(parent, "charge", point + Vector2(0, 26) * size, size, _palette(color), {"speed": speed, "z": 7})

# Descarga eléctrica (cámaras destruidas, impactos del railgun).
static func zap(parent: Node, point: Vector2, color: Color, size: float = 1.0) -> void:
	PixelFx.play(parent, "zap", point, size, _palette(color), {"flip": randf() < 0.5, "speed": 1.3, "z": 7})

# Estallido de partículas que se recogen (rubíes absorbidos).
static func collect(parent: Node, point: Vector2, color: Color, size: float = 1.0) -> void:
	PixelFx.play(parent, "collect", point + Vector2(0, 16) * size, size, _palette(color), {"speed": 1.5, "z": 8})

# Golpe contra un escudo (lo que está protegido).
static func shield_hit(parent: Node, point: Vector2, color: Color, flip: bool = false) -> void:
	PixelFx.play(parent, "shield", point + Vector2(0, 30), 1.0, _palette(color), {"flip": flip, "speed": 1.4, "z": 7})

# Impacto de bala contra el suelo o una pared.
static func bullet_impact(parent: Node, point: Vector2, color: Color, rotation: float = 0.0) -> void:
	PixelFx.play(parent, "bullet_impact", point, 1.0, _palette(color), {"rotation": rotation, "speed": 1.3, "z": 6})

# Onda expansiva en el suelo (PixelFX propio): anillo que corre por el suelo con dos crestas de aire.
static func shockwave(parent: Node, point: Vector2, color: Color, size: float = 1.0) -> void:
	PixelFx.play(parent, "shockwave", point, size, _palette(color), {"speed": 1.2, "z": 4})

# Brasas que se levantan del suelo y quedan suspendidas un momento (PixelFX propio).
static func embers(parent: Node, point: Vector2, color: Color, size: float = 1.0) -> void:
	PixelFx.play(parent, "embers", point, size, _palette(color), {"flip": randf() < 0.5, "z": 6})

# Estallido del ruby (PixelFX propio): nube con forma de rombo, como la gema.
static func ruby_burst(parent: Node, point: Vector2, color: Color, radius: float = 46.0) -> AnimatedSprite2D:
	var sprite: AnimatedSprite2D = PixelFx.play(parent, "ruby_burst", point, clampf(radius / 54.0, 0.5, 2.2), _palette(color), {"speed": 1.15, "z": 6})
	if sprite != null:
		sprite.name = "RubyBurst"
	return sprite

# Orbes de energía del ruby roto que salen despedidos y se curvan hasta "target" (lo siguen si se mueve).
static func absorb_orbs(parent: Node, point: Vector2, target: Node2D, color: Color, count: int = 8, offset := Vector2(0, -26)) -> void:
	if target == null or not is_instance_valid(target):
		return
	for index in range(count):
		var orb: AnimatedSprite2D = PixelFx.play(parent, "energy_orb", point, randf_range(1.4, 1.9), _palette(color), {"loop": true, "z": 9})
		if orb == null:
			continue
		orb.name = "RubyOrb"
		var angle := TAU * index / count + randf_range(-0.3, 0.3)
		var start := point + Vector2.from_angle(angle) * randf_range(6.0, 16.0)
		var control := point + Vector2.from_angle(angle) * randf_range(55.0, 95.0) + Vector2(0, -30)
		var life := randf_range(0.42, 0.62) + index * 0.03
		var tween := orb.create_tween()
		tween.tween_method(func(q: float) -> void:
			if not is_instance_valid(target):
				return
			var goal: Vector2 = target.global_position + offset
			var a := start.lerp(control, q)
			var b := control.lerp(goal, q)
			orb.global_position = a.lerp(b, q)
			orb.scale = Vector2.ONE * lerpf(1.8, 0.8, q), 0.0, 1.0, life).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_callback(func() -> void:
			if is_instance_valid(target) and index % 3 == 0:
				PixelFx.play(target, "hit_spark", offset, 0.6, _palette(color), {"follow": target, "speed": 1.6, "z": 9})
			orb.queue_free())

# Corte que el uppercut deja en el aire: se queda flotando y se deshace (PixelFX propio).
static func air_cut(parent: Node, point: Vector2, color: Color, flip: bool, size: float = 1.0) -> void:
	PixelFx.play(parent, "air_cut", point, size, _palette(color), {"flip": flip, "z": 4})

# Barrido de patada o rodillazo que ocupa la zona de golpe "rect" (en coordenadas de quien patea).
static func kick_arc(parent: Node2D, rect: Rect2, facing: int, color: Color) -> void:
	var info: Dictionary = PixelFx.DATA.SHEETS["kick_arc"]
	var frame: Vector2 = info["frame"]
	var sprite: AnimatedSprite2D = PixelFx.play(parent, "kick_arc", Vector2.ZERO, 1.0, _palette(color), {"follow": parent, "flip": facing < 0, "speed": 1.2, "z": 6})
	if sprite == null:
		return
	# El arco llena el rectángulo de golpe: su pivote (la cadera) va al borde trasero del rectángulo.
	sprite.scale = Vector2(rect.size.x / (frame.x - info["pivot"].x), rect.size.y / frame.y) * 1.05
	sprite.position = Vector2(rect.position.x if facing > 0 else rect.end.x, rect.get_center().y)

# Burbujas que suben bajo el agua (estela de Viridy al moverse sumergida).
static func bubbles(parent: Node, point: Vector2, size: float = 1.0) -> void:
	PixelFx.play(parent, "bubbles", point, size, [], {"flip": randf() < 0.5, "z": 8})

# Fogonazo del cañón al disparar.
static func muzzle(parent: Node, point: Vector2, rotation: float, color: Color, size: float = 1.0) -> void:
	PixelFx.play(parent, "muzzle", point, size, _palette(color), {"rotation": rotation, "speed": 1.4, "z": 7})

# Signo de exclamación de aviso sobre quien va a atacar (lo sigue).
static func exclamation(target: Node2D, offset: Vector2, color: Color, size: float = 1.0) -> AnimatedSprite2D:
	if target == null or not target.is_inside_tree():
		return null
	return PixelFx.play(target, "exclamation", offset, size, [color.darkened(0.7), color, Color(1.0, 0.98, 0.9)], {"follow": target, "speed": 1.5, "z": 12})

# Estados en bucle que siguen a quien los sufre (burning, ice_block, stunned): devuelve el sprite.
static func status(target: Node2D, sheet: String, offset: Vector2, size: float = 1.0, modulate := Color.WHITE) -> AnimatedSprite2D:
	if target == null or not target.is_inside_tree():
		return null
	return PixelFx.play(target, sheet, offset, size, [], {"follow": target, "loop": true, "z": 7, "modulate": modulate})

# Hielo que estalla en esquirlas.
static func ice_shatter(parent: Node, point: Vector2, size: float = 1.0) -> void:
	PixelFx.play(parent, "ice_shatter", point, size, [], {"speed": 1.4, "z": 7})

# Reloj del Enfoque al activarse.
static func time_stop(parent: Node, point: Vector2, color: Color) -> void:
	PixelFx.play(parent, "time_stop", point, 1.2, _palette(color), {"speed": 1.6, "z": 9})

# Flor que se abre al curarse en la fuente.
static func bloom(parent: Node, point: Vector2, size: float = 1.0) -> void:
	PixelFx.play(parent, "bloom", point, size, [], {"speed": 1.3, "z": 4})

# Explosión de fuego jade (la muerte de Viridy).
static func jade_blast(parent: Node, point: Vector2, size: float = 1.0) -> AnimatedSprite2D:
	var jade: Array[Color] = [Color(0.01, 0.08, 0.05), Color(0.2, 0.85, 0.45), Color(0.88, 1.0, 0.8)]
	return PixelFx.play(parent, "jade_blast", point, size, jade, {"speed": 1.1, "z": 12})

static func _palette(color: Color) -> Array[Color]:
	return [color.darkened(0.65), color, color.lightened(0.7)]

# Texto flotante que sube y se desvanece.
static func text(parent: Node, point: Vector2, message: String, color: Color) -> void:
	var label := Label.new()
	label.text = message
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.06, 0.05))
	label.add_theme_constant_override("outline_size", 6)
	label.z_index = 10
	parent.add_child(label)
	label.global_position = point - Vector2(48, 12)
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "global_position:y", point.y - 50.0, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)

static func _spawn(parent: Node, point: Vector2) -> Node2D:
	var node := Node2D.new()
	parent.add_child(node)
	node.global_position = point
	return node

static func _circle(radius: float, segments: int, closed: bool) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle: float = TAU * index / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	if closed:
		points.append(points[0])
	return points
