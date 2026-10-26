extends Node2D

# Paisaje nativo de Godot: el decorado es estático; agua y partículas se animan aparte.
# Semilla fija para conservar la composición entre visitas y capturas.
const TREE := Vector2(3050, -55)

func _ready() -> void:
	z_index = -8

func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8716
	# Bosque lejano en capas, con el claro cálido detrás del Árbol Madre.
	for layer in range(3):
		var color: Color = [Color("729d83"), Color("4b806d"), Color("2c6556")][layer]
		for index in range(25):
			var x := index * 310.0 - 600.0 + rng.randf_range(-90, 90)
			var height := rng.randf_range(380, 900) + layer * 140
			var base := Vector2(x, 240 - layer * 25)
			var top := base - Vector2(0, height)
			_branch(PackedVector2Array([base, top + Vector2(30, height * 0.3), top]), 24 + layer * 8, color)
			for leaf in range(5):
				_ellipse(top + Vector2(rng.randf_range(-125, 125), rng.randf_range(-75, 45)), Vector2(160, 95), color)
	# Agua del claro al fondo: una superficie amplia detrás de las orillas transitables.
	_ellipse(Vector2(3100, 130), Vector2(1500, 200), Color("3e9d8b"))
	_ellipse(Vector2(3100, 98), Vector2(1400, 145), Color("65bba0"))
	for index in range(32):
		var x := rng.randf_range(1800, 4400)
		var y := rng.randf_range(38, 165)
		draw_line(Vector2(x, y), Vector2(x + rng.randf_range(25, 110), y), Color(0.8, 0.95, 0.72, 0.18), 2.0, true)
	_draw_mother_tree(rng)
	# Árboles secundarios de los extremos: enmarcan el claro y las rutas de movilidad.
	for x in [250.0, 850.0, 5400.0, 6050.0]:
		var base := Vector2(x, -10)
		_branch(PackedVector2Array([base, base + Vector2(20, -270), base + Vector2(-30, -630)]), 70, Color("385645"))
		for index in range(8):
			_ellipse(base + Vector2(rng.randf_range(-220, 220), rng.randf_range(-800, -560)), Vector2(180, 85), Color("457b51"))
	# Helechos, flores y piedras de las dos orillas.
	for x in [120.0, 420.0, 780.0, 1140.0, 1510.0, 1740.0, 4690.0, 4940.0, 5180.0, 5700.0, 6220.0]:
		var ground_y := _bank_height(x)
		_fern(Vector2(x, ground_y - 5), rng.randf_range(0.7, 1.3))
		for index in range(4):
			var p := Vector2(x + index * 12, ground_y - 8)
			draw_line(p, p + Vector2(2, -25 - index * 4), Color("759c58"), 2.0, true)
			_ellipse(p + Vector2(2, -25 - index * 4), Vector2(5, 3), Color("f4dcb2"))
	# Haces cálidos bajo la copa; su transparencia deja legible el personaje.
	for index in range(6):
		var x := 1820.0 + index * 370.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, -1550), Vector2(x + 50, -1550), Vector2(x + 570, 250), Vector2(x + 360, 250)]), Color(1.0, 0.95, 0.67, 0.035))

func _bank_height(x: float) -> float:
	if x < 850:
		return -50
	if x < 1150:
		return lerpf(-50, 0, (x - 850) / 300)
	if x > 5600:
		return lerpf(0, -80, clampf((x - 5600) / 500, 0, 1))
	return 0

func _draw_mother_tree(rng: RandomNumberGenerator) -> void:
	var bark := Color("41563c")
	var shadow := Color("233f36")
	# Raíces abiertas que abrazan la isla, con ramificaciones hacia la laguna.
	for side in [-1.0, 1.0]:
		for index in range(4):
			var points := PackedVector2Array([
				TREE + Vector2(side * 65, -145), TREE + Vector2(side * (160 + index * 60), -35),
				TREE + Vector2(side * (310 + index * 85), 45 + index * 16), TREE + Vector2(side * (460 + index * 105), 110),
			])
			_branch(points, 100 - index * 17, shadow)
			_branch(points, 66 - index * 10, bark)
			_branch(points, 7, Color("849160"))
	var trunk := PackedVector2Array([
		TREE + Vector2(-210, 20), TREE + Vector2(-140, -280), TREE + Vector2(-165, -590),
		TREE + Vector2(-120, -850), TREE + Vector2(-260, -1180), TREE + Vector2(-80, -1250),
		TREE + Vector2(60, -920), TREE + Vector2(160, -1210), TREE + Vector2(310, -1160),
		TREE + Vector2(135, -780), TREE + Vector2(170, -500), TREE + Vector2(140, -250), TREE + Vector2(230, 20),
	])
	draw_colored_polygon(trunk, shadow)
	# Fibras verticales del tronco, en tonos de musgo, bronce y madera viva.
	for index in range(17):
		var points := PackedVector2Array()
		var x := -130.0 + index * 16
		for step in range(12):
			var y := -step * 84.0
			points.append(TREE + Vector2(x + sin(step * 0.62 + index * 0.7) * 14.0, y))
		_branch(points, rng.randf_range(8, 16), [bark, Color("596344"), Color("344d38"), Color("74805a")][index % 4])
	# Ramas de la copa. Las plataformas sólidas se dibujan sobre ellas en sanctuary.gd.
	for side in [-1.0, 1.0]:
		for index in range(5):
			var height := -420.0 - index * 160
			var reach := 350.0 + index * 120
			_branch(PackedVector2Array([TREE + Vector2(side * 75, height + 120), TREE + Vector2(side * reach * 0.5, height), TREE + Vector2(side * reach, height - 110)]), 92 - index * 11, shadow)
			_branch(PackedVector2Array([TREE + Vector2(side * 75, height + 110), TREE + Vector2(side * reach * 0.5, height - 5), TREE + Vector2(side * reach, height - 115)]), 44 - index * 5, bark)
	for layer in range(3):
		for index in range(25):
			var x := rng.randf_range(-1000, 1000)
			var arch := absf(x) * 0.22
			var p := TREE + Vector2(x, -1320 + arch + layer * 65 + rng.randf_range(-95, 45))
			var color: Color = [Color("2b6848"), Color("4e8650"), Color("82a85e")][layer]
			_ellipse(p, Vector2(rng.randf_range(130, 245), rng.randf_range(75, 140)), color)
	# Enredaderas colgantes que dan una escala enorme al árbol.
	for index in range(18):
		var x := rng.randf_range(-860, 860)
		var start := TREE + Vector2(x, -1170 + absf(x) * 0.2)
		var points := PackedVector2Array()
		var length := rng.randf_range(100, 420)
		for step in range(12):
			points.append(start + Vector2(sin(step * 0.6 + index) * 10, length * step / 11.0))
		draw_polyline(points, Color("547d4c"), 3.0, true)
		for step in [3, 6, 9]:
			_ellipse(points[step] + Vector2(7, 0), Vector2(11, 4), Color("9cbb6b"))
	# El corazón cálido del árbol: una cavidad viva, sin un objeto recogible.
	var heart := TREE + Vector2(0, -235)
	for index in range(7, 0, -1):
		_ellipse(heart, Vector2(22 + index * 13, 46 + index * 15), Color(0.77, 0.9, 0.43, 0.015))
	_ellipse(heart, Vector2(39, 81), Color("1c3b30"))
	_ellipse(heart + Vector2(0, 5), Vector2(22, 60), Color("c1d88a"))
	_ellipse(heart + Vector2(-3, -5), Vector2(10, 40), Color("f5efb1"))
	for side in [-1.0, 1.0]:
		_branch(PackedVector2Array([heart + Vector2(side * 45, 90), heart + Vector2(side * 65, 0), heart + Vector2(side * 30, -105)]), 9, Color("a4b576"))

func _fern(base: Vector2, size: float) -> void:
	for side in [-1.0, 1.0]:
		for index in range(5):
			var tip := base + Vector2(side * (18 + index * 9), -55 + index * 7) * size
			draw_line(base, tip, Color("507d47"), 2.0, true)
			for leaf in range(4):
				var p := base.lerp(tip, (leaf + 1) / 5.0)
				draw_colored_polygon(PackedVector2Array([p, p + Vector2(side * 15, -9) * size, p + Vector2(side * 4, 3) * size]), Color("96b76c"))

func _branch(points: PackedVector2Array, width: float, color: Color) -> void:
	draw_polyline(points, color, width, true)
	for point in points:
		draw_circle(point, width * 0.5, color)

func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(28):
		var angle := index * TAU / 28.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, color)
