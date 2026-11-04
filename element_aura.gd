extends Node2D

# Marca de un enemigo con variante elemental: una coronita del color de su elemento sobre la cabeza, con
# chispas. La cabeza se busca en el dibujo del enemigo (la parte más alta de su sprite o de sus polígonos)
# y se sigue al voltearse o moverse, así sirve para cualquier tipo sin datos por enemigo.

const REFRESH := 0.15
const CROWN_LIFT := 3.0
# Filas de la parte alta del sprite que cuentan como "cabeza" (fracción de la altura opaca).
const HEAD_BAND := 0.12
const OUTLINE := Color(0.08, 0.05, 0.06)

static var _heads := {}

var color := Color.WHITE
var clock := 0.0
var refresh_left := 0.0
var head := Vector2.ZERO
var target_head := Vector2.ZERO
var sparks: CPUParticles2D

func _ready() -> void:
	z_index = 8
	var enemy := get_parent() as Node2D
	head = Vector2(enemy.get("impact_offset") if enemy.get("impact_offset") != null else Vector2.ZERO) + Vector2(0, -30)
	sparks = CPUParticles2D.new()
	sparks.amount = 5
	sparks.lifetime = 0.55
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sparks.emission_rect_extents = Vector2(9, 2)
	sparks.direction = Vector2.UP
	sparks.spread = 30.0
	sparks.gravity = Vector2(0, -30)
	sparks.initial_velocity_min = 8.0
	sparks.initial_velocity_max = 24.0
	sparks.scale_amount_min = 1.0
	sparks.scale_amount_max = 2.0
	sparks.color = color.lightened(0.25)
	sparks.position = Vector2(0, -8)
	add_child(sparks)
	_find_head()
	head = target_head
	position = head

func _process(delta: float) -> void:
	clock += delta
	refresh_left -= delta
	if refresh_left <= 0.0:
		refresh_left = REFRESH
		_find_head()
	head = head.lerp(target_head, minf(delta * 14.0, 1.0))
	position = head + Vector2(0, -CROWN_LIFT + sin(clock * 3.0) * 1.2)
	queue_redraw()

func _find_head() -> void:
	var enemy := get_parent() as Node2D
	var root: Node = enemy.get("visual") if enemy.get("visual") is Node2D else enemy
	var best := Vector2.INF
	for item in _drawables(root):
		var point := Vector2.INF
		if item is Sprite2D:
			point = _sprite_head(item)
		elif item is Polygon2D:
			point = _polygon_head(item)
		if point != Vector2.INF and point.y < best.y:
			best = point
	if best != Vector2.INF:
		target_head = enemy.to_local(best)

func _drawables(node: Node) -> Array:
	var found: Array = []
	for child in node.get_children():
		if child == self or child.name == "RubyCore" or not (child is CanvasItem) or not child.visible:
			continue
		if child is Label or child is Line2D:
			continue
		if (child is Sprite2D and child.texture != null) or (child is Polygon2D and child.polygon.size() >= 3):
			found.append(child)
		found.append_array(_drawables(child))
	return found

# Punto más alto (centro de la franja superior opaca) del sprite, en coordenadas globales.
func _sprite_head(sprite: Sprite2D) -> Vector2:
	var texture: Texture2D = sprite.texture
	var key := texture.get_rid()
	if not _heads.has(key):
		_heads[key] = _texture_head(texture)
	var local: Vector2 = _heads[key]
	if local == Vector2.INF:
		return Vector2.INF
	var size := texture.get_size()
	if sprite.region_enabled:
		return Vector2.INF
	if sprite.flip_h:
		local.x = size.x - local.x
	var origin := sprite.offset - (size * 0.5 if sprite.centered else Vector2.ZERO)
	return sprite.get_global_transform() * (origin + local)

static func _texture_head(texture: Texture2D) -> Vector2:
	var image := texture.get_image()
	if image == null:
		return Vector2.INF
	if image.is_compressed():
		image = image.duplicate()
		image.decompress()
	var used := image.get_used_rect()
	if used.size.y <= 0:
		return Vector2.INF
	var band := maxi(int(used.size.y * HEAD_BAND), 2)
	var total := 0.0
	var count := 0
	for y in range(used.position.y, used.position.y + band):
		for x in range(used.position.x, used.end.x, 2):
			if image.get_pixel(x, y).a > 0.5:
				total += x
				count += 1
	if count == 0:
		return Vector2.INF
	return Vector2(total / count, used.position.y)

func _polygon_head(poly: Polygon2D) -> Vector2:
	var top := INF
	for point in poly.polygon:
		top = minf(top, point.y)
	var total := 0.0
	var count := 0
	for point in poly.polygon:
		if point.y <= top + 4.0:
			total += point.x
			count += 1
	return poly.get_global_transform() * (poly.offset + Vector2(total / count, top))

func _draw() -> void:
	# Corona de tres puntas, con contorno oscuro y gemas que brillan por turnos.
	var base_y := 0.0
	var crown := PackedVector2Array([Vector2(-9, base_y), Vector2(-10, base_y - 9), Vector2(-5, base_y - 4), Vector2(0, base_y - 12),
		Vector2(5, base_y - 4), Vector2(10, base_y - 9), Vector2(9, base_y)])
	var outline := PackedVector2Array()
	for point in crown:
		outline.append(point)
	outline.append(crown[0])
	draw_colored_polygon(crown, color)
	draw_polyline(outline, OUTLINE, 2.0)
	draw_rect(Rect2(-9, base_y - 3, 18, 3), color.darkened(0.35))
	draw_line(Vector2(-9, base_y), Vector2(9, base_y), OUTLINE, 2.0)
	for index in range(3):
		var tip: Vector2 = [Vector2(-10, base_y - 9), Vector2(0, base_y - 12), Vector2(10, base_y - 9)][index]
		var glow := 0.5 + 0.5 * sin(clock * 5.0 - index * 1.4)
		draw_circle(tip, 1.8, color.lightened(0.4 + glow * 0.5))
	# Brillo del metal.
	draw_line(Vector2(-6, base_y - 2), Vector2(-2, base_y - 2), Color(1, 1, 1, 0.55), 1.0)
