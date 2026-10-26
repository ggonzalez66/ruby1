@tool
extends StaticBody2D

# Contorno compartido por dibujo y colisión; surface_count identifica la superficie con musgo.
@export var outline := PackedVector2Array()
@export var surface_count := 2
@export var root_surface := false

func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	var collision := CollisionPolygon2D.new()
	collision.polygon = outline
	add_child(collision)
	queue_redraw()

func _draw() -> void:
	if outline.size() < 3:
		return
	var colors := PackedColorArray()
	for point in outline:
		var depth := clampf((point.y - outline[0].y) / 520.0, 0.0, 1.0)
		colors.append(Color("4b6850").lerp(Color("122b2a"), depth) if not root_surface else Color("594f37").lerp(Color("253e31"), depth))
	draw_polygon(outline, colors)
	var edge := PackedVector2Array()
	for index in range(mini(surface_count, outline.size())):
		edge.append(outline[index])
	if edge.size() < 2:
		return
	draw_polyline(edge, Color("233d2d"), 14.0, true)
	draw_polyline(edge, Color("729453"), 7.0, true)
	draw_polyline(edge, Color("bfd28a"), 2.0, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	for index in range(edge.size() - 1):
		var length := edge[index].distance_to(edge[index + 1])
		for step in range(int(length / 15.0)):
			var point := edge[index].lerp(edge[index + 1], (step + 0.4) * 15.0 / maxf(length, 1.0))
			var height := rng.randf_range(4.0, 13.0)
			draw_line(point, point + Vector2(rng.randf_range(-6, 6), -height), Color("94b66a"), 2.0, true)
			if rng.randf() < 0.09:
				draw_circle(point + Vector2(0, -height), 2.4, Color("f5e4b0"))
