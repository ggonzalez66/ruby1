extends Node2D

# Puesto del zorro comerciante (decorado, sin colisión): techo inclinado con el cartel "SHOP" y un rubí,
# postes de madera, la mesa con las mercancías (poción, arco, espada, bota, escudo…) y el zorro detrás,
# que mueve la cola y parpadea. Cuando Viridy está cerca, el zorro habla.

const WOOD := Color(0.45, 0.29, 0.16)
const WOOD_DARK := Color(0.28, 0.17, 0.09)
const ROOF := Color(0.62, 0.2, 0.16)
const ROOF_DARK := Color(0.4, 0.11, 0.09)
const CLOTH := Color(0.9, 0.84, 0.66)
const FUR := Color(0.95, 0.5, 0.15)
const FUR_DARK := Color(0.7, 0.3, 0.08)
const FUR_LIGHT := Color(1.0, 0.95, 0.88)
const EYE := Color(0.1, 0.08, 0.06)
const RUBY := Color(1.0, 0.22, 0.3)

var time := 0.0
var talking := false:
	set(value):
		if value != talking:
			talking = value
			bubble.visible = value
var bubble: Label
var blink := 0.0

func _ready() -> void:
	z_index = -2
	bubble = Label.new()
	bubble.text = "¡Rubíes por mejoras, felino!"
	bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble.size = Vector2(360, 30)
	bubble.position = Vector2(-180, -470)
	bubble.add_theme_font_size_override("font_size", 20)
	bubble.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	bubble.add_theme_color_override("font_outline_color", Color(0.15, 0.06, 0.02))
	bubble.add_theme_constant_override("outline_size", 6)
	bubble.visible = false
	add_child(bubble)

func _process(delta: float) -> void:
	time += delta
	blink -= delta
	if blink < -0.12:
		blink = randf_range(2.0, 4.0)
	queue_redraw()

func _draw() -> void:
	# Postes traseros.
	for x in [-230.0, 230.0]:
		draw_rect(Rect2(x - 12, -330, 24, 330), WOOD_DARK)
	_draw_fox(Vector2(0, -150))
	# Mesa con mantel.
	draw_rect(Rect2(-250, -150, 500, 22), WOOD)
	draw_colored_polygon(PackedVector2Array([Vector2(-255, -150), Vector2(255, -150), Vector2(240, -80), Vector2(-240, -80)]), CLOTH)
	for x in range(-230, 240, 46):
		draw_line(Vector2(x, -148), Vector2(x - 4, -82), CLOTH.darkened(0.15), 2.0)
	for x in [-220.0, 220.0]:
		draw_rect(Rect2(x - 9, -80, 18, 80), WOOD)
	_draw_goods()
	# Postes delanteros y techo inclinado con el cartel.
	for x in [-300.0, 300.0]:
		draw_rect(Rect2(x - 14, -380, 28, 380), WOOD)
		draw_rect(Rect2(x - 14, -380, 6, 380), WOOD.lightened(0.15))
	draw_colored_polygon(PackedVector2Array([Vector2(-360, -360), Vector2(360, -360), Vector2(330, -430), Vector2(-330, -430)]), ROOF)
	for x in range(-340, 360, 60):
		draw_colored_polygon(PackedVector2Array([Vector2(x, -360), Vector2(x + 30, -360), Vector2(x + 15, -340)]), ROOF_DARK)
	draw_rect(Rect2(-130, -425, 260, 52), WOOD_DARK)
	draw_rect(Rect2(-130, -425, 260, 52), Color(1.0, 0.85, 0.5), false, 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(-120, -386), "SHOP", HORIZONTAL_ALIGNMENT_CENTER, 200, 36, Color(1.0, 0.88, 0.55))
	_draw_ruby(Vector2(100, -400), 14.0)

func _draw_goods() -> void:
	var y := -150.0
	# Poción, manzana, flecha, espada, bota, escudo y una cruz de curación como en el boceto.
	draw_circle(Vector2(-190, y - 18), 16.0, Color(0.35, 0.75, 1.0))
	draw_rect(Rect2(-196, y - 44, 12, 14), Color(0.8, 0.85, 0.9))
	draw_circle(Vector2(-140, y - 14), 13.0, Color(0.85, 0.18, 0.15))
	draw_line(Vector2(-140, y - 27), Vector2(-136, y - 36), WOOD_DARK, 3.0)
	draw_line(Vector2(-110, y - 6), Vector2(-60, y - 50), Color(0.75, 0.7, 0.6), 3.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-60, y - 50), Vector2(-70, y - 36), Vector2(-56, y - 40)]), Color(0.8, 0.82, 0.85))
	draw_line(Vector2(60, y - 8), Vector2(130, y - 26), Color(0.82, 0.85, 0.9), 6.0)
	draw_line(Vector2(56, y - 18), Vector2(64, y + 2), Color(0.7, 0.55, 0.2), 5.0)
	draw_colored_polygon(PackedVector2Array([Vector2(150, y), Vector2(150, y - 30), Vector2(166, y - 30), Vector2(166, y - 12), Vector2(184, y - 12), Vector2(184, y)]), Color(0.42, 0.28, 0.18))
	draw_circle(Vector2(208, y - 16), 16.0, Color(0.55, 0.6, 0.68))
	draw_circle(Vector2(208, y - 16), 8.0, Color(0.85, 0.7, 0.3))

func _draw_ruby(at: Vector2, size: float) -> void:
	draw_colored_polygon(PackedVector2Array([at + Vector2(-size, -size * 0.3), at + Vector2(-size * 0.5, -size), at + Vector2(size * 0.5, -size),
		at + Vector2(size, -size * 0.3), at + Vector2(0, size)]), RUBY)
	draw_line(at + Vector2(-size * 0.5, -size), at + Vector2(-size * 0.2, -size * 0.3), Color(1, 0.8, 0.85, 0.8), 2.0)

func _draw_fox(base: Vector2) -> void:
	# Cola que se mece detrás.
	var sway := sin(time * 2.2) * 14.0
	draw_colored_polygon(PackedVector2Array([base + Vector2(40, 10), base + Vector2(120 + sway, -40), base + Vector2(150 + sway, -110),
		base + Vector2(110 + sway, -90), base + Vector2(60, -20)]), FUR)
	draw_colored_polygon(PackedVector2Array([base + Vector2(150 + sway, -110), base + Vector2(110 + sway, -90), base + Vector2(130 + sway, -78)]), FUR_LIGHT)
	# Cuerpo sentado.
	draw_colored_polygon(PackedVector2Array([base + Vector2(-50, 0), base + Vector2(50, 0), base + Vector2(36, -90), base + Vector2(-36, -90)]), FUR)
	draw_colored_polygon(PackedVector2Array([base + Vector2(-20, 0), base + Vector2(20, 0), base + Vector2(14, -80), base + Vector2(-14, -80)]), FUR_LIGHT)
	# Patas sobre la mesa.
	for x in [-26.0, 26.0]:
		draw_circle(base + Vector2(x, -2), 11.0, FUR_DARK)
	# Cabeza: triángulo con orejas y hocico blanco.
	var head := base + Vector2(0, -130)
	draw_colored_polygon(PackedVector2Array([head + Vector2(-52, -20), head + Vector2(52, -20), head + Vector2(0, 46)]), FUR)
	for side in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([head + Vector2(side * 50, -18), head + Vector2(side * 18, -22), head + Vector2(side * 44, -78)]), FUR)
		draw_colored_polygon(PackedVector2Array([head + Vector2(side * 42, -24), head + Vector2(side * 24, -24), head + Vector2(side * 40, -60)]), FUR_DARK)
	draw_colored_polygon(PackedVector2Array([head + Vector2(-26, 4), head + Vector2(26, 4), head + Vector2(0, 46)]), FUR_LIGHT)
	draw_circle(head + Vector2(0, 42), 6.0, EYE)
	# Ojos entrecerrados de comerciante (parpadean).
	for side in [-1.0, 1.0]:
		var eye := head + Vector2(side * 20, -4)
		if blink > 0.0:
			draw_circle(eye, 6.0, EYE)
			draw_circle(eye + Vector2(-2, -2), 2.0, Color(1, 1, 1, 0.9))
			draw_line(eye + Vector2(-10, -10 + 3 * side), eye + Vector2(10, -10 - 3 * side), FUR_DARK, 3.0)
		else:
			draw_line(eye + Vector2(-8, 0), eye + Vector2(8, 0), EYE, 3.0)
	if talking:
		var mouth := head + Vector2(0, 30)
		draw_arc(mouth, 7.0, 0.2, PI - 0.2, 8, EYE, 2.0)
