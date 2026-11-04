extends Node

# Autoload "RunState": la run al estilo Slay the Spire que empieza al salir del Árbol Madre por la derecha.
# Guarda el mapa de hexágonos (tipo de cada territorio, visitados y posición), la vida de Viridy entre
# escenas y lleva las transiciones: mapa → territorio → mapa … → Torre (los tres guardianes) → el sol →
# parkour final → el Ruby. Las mejoras y los rubíes siguen en Upgrades (activo durante toda la run).
#
# Territorios: "fight" (campamento de enfrentamiento: fábrica en tres fases), "fountain" (fuente de
# curación) y "shop" (el zorro comerciante). "start" es la casilla de salida y la Torre está encima de la
# última fila, unida a sus casillas centrales.

signal map_changed

const HUB_SCENE := "res://mother_tree.tscn"
const MAP_SCENE := "res://run_map.tscn"
const MAIN_MENU := "res://main_menu.tscn"
const FIGHT_SCENES := ["res://factory_outdoor.tscn", "res://factory_indoor.tscn", "res://factory_boss.tscn"]
const FOUNTAIN_SCENE := "res://fountain.tscn"
const SHOP_SCENE := "res://fox_shop.tscn"
const TOWER_SCENE := "res://tower_finale.tscn"
const PARKOUR_SCENE := "res://sun_world.tscn"
# Variantes de nivel: cada enfrentamiento elige una versión de las afueras y otra de dentro de la fábrica
# (la A original, el canal / sótano inundado y el patio de carga / línea de montaje).
const FIGHT_VARIANTS := [
	["res://factory_outdoor.tscn", "res://factory_outdoor_b.tscn", "res://factory_outdoor_c.tscn"],
	["res://factory_indoor.tscn", "res://factory_indoor_b.tscn", "res://factory_indoor_c.tscn"],
	["res://factory_boss.tscn"],
]
const RUN_SCENES := ["res://factory_outdoor.tscn", "res://factory_indoor.tscn", "res://factory_boss.tscn",
	"res://factory_outdoor_b.tscn", "res://factory_outdoor_c.tscn", "res://factory_indoor_b.tscn", "res://factory_indoor_c.tscn",
	FOUNTAIN_SCENE, SHOP_SCENE, TOWER_SCENE, PARKOUR_SCENE]

const START := "start"
const FIGHT := "fight"
const FOUNTAIN := "fountain"
const SHOP := "shop"
const TOWER := "tower"
const TYPE_NAMES := {
	START: "Inicio", FIGHT: "Campamento · Enfrentamiento", FOUNTAIN: "Fuente de curación",
	SHOP: "Zorro comerciante", TOWER: "La Torre",
}
# Filas del panal de abajo (inicio) hacia arriba: [primera columna, última columna] en coordenadas
# "odd-r" (las filas impares van media casilla a la derecha).
const ROWS := [[3, 3], [2, 4], [1, 5], [0, 6], [0, 6], [1, 5]]
# La Torre se alcanza desde estas columnas de la última fila.
const TOWER_COLUMNS := [2, 3, 4]
const TOWER_CELL := Vector2i(3, 6)
const FADE_TIME := 0.22

var active := false
var map_seed := 0
# Vector2i(columna, fila) -> tipo.
var cells := {}
var visited := {}
var current := Vector2i(3, 0)
var fights_cleared := 0
# Vida guardada entre escenas (-1 = llena).
var health := -1
var max_health := 100
var finished := false
var fade_layer: CanvasLayer
var fade_rect: ColorRect
var changing := false
# Variante elegida para cada fase del enfrentamiento actual; las pruebas la fijan apagando layout_variants.
var layout_variants := true
var fight_layout: Array = [0, 0, 0]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	fade_layer = CanvasLayer.new()
	fade_layer.layer = 90
	add_child(fade_layer)
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(fade_rect)

# ---------- Ciclo de la run

func start_run(seed_value: int = -1) -> void:
	# Al salir del Árbol Madre: estadísticas, estilo y mejoras desde cero y un mapa nuevo.
	Stats.reset()
	Ferocity.reset()
	Stats.set_meta(&"defeated_bosses", [])
	Stats.set_meta(&"last_boss", -1)
	Upgrades.begin_run()
	active = true
	finished = false
	fights_cleared = 0
	health = -1
	map_seed = seed_value if seed_value >= 0 else randi()
	generate_map(map_seed)
	map_changed.emit()

func abort_run() -> void:
	# Menú principal, abandonar o morir: se pierde todo lo de la run.
	active = false
	finished = false
	Upgrades.end_run()

func generate_map(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	cells.clear()
	visited.clear()
	for row in range(ROWS.size()):
		for column in range(ROWS[row][0], ROWS[row][1] + 1):
			cells[Vector2i(column, row)] = FIGHT
	current = Vector2i(ROWS[0][0], 0)
	cells[current] = START
	visited[current] = true
	# Primera fila: siempre enfrentamientos (hacen falta rubíes antes del primer zorro).
	for row in range(2, ROWS.size()):
		var row_cells: Array = cells.keys().filter(func(cell): return cell.y == row)
		for cell in row_cells:
			var roll := rng.randf()
			cells[cell] = FOUNTAIN if roll < 0.2 else (SHOP if roll < 0.4 else FIGHT)
		# Cada fila trae al menos una fuente, un zorro y dos enfrentamientos.
		for kind in [FOUNTAIN, SHOP]:
			if not row_cells.any(func(cell): return cells[cell] == kind):
				var fights: Array = row_cells.filter(func(cell): return cells[cell] == FIGHT)
				cells[fights[rng.randi() % fights.size()]] = kind
		while row_cells.filter(func(cell): return cells[cell] == FIGHT).size() < 2:
			var others: Array = row_cells.filter(func(cell): return cells[cell] != FIGHT)
			cells[others[rng.randi() % others.size()]] = FIGHT
	# Dos zorros juntos no aportan nada: el segundo pasa a ser un enfrentamiento.
	for cell in cells.keys():
		if cells[cell] == SHOP:
			for other in neighbors(cell):
				if cells.get(other, "") == SHOP:
					cells[other] = FIGHT

func neighbors(cell: Vector2i) -> Array:
	# Vecinos en un panal "odd-r" (columna, fila con la fila 0 abajo).
	var odd := cell.y % 2 == 1
	var deltas := [Vector2i(1, 0), Vector2i(-1, 0)]
	if odd:
		deltas += [Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, -1), Vector2i(1, -1)]
	else:
		deltas += [Vector2i(-1, 1), Vector2i(0, 1), Vector2i(-1, -1), Vector2i(0, -1)]
	var result := []
	for delta in deltas:
		var other: Vector2i = cell + delta
		if cells.has(other):
			result.append(other)
	if cell.y == ROWS.size() - 1 and cell.x in TOWER_COLUMNS:
		result.append(TOWER_CELL)
	return result

func cell_type(cell: Vector2i) -> String:
	return TOWER if cell == TOWER_CELL else String(cells.get(cell, ""))

func available_moves() -> Array:
	# Se avanza a un hexágono vecino sin visitar, hacia arriba o de lado (nunca hacia abajo), y solo si
	# desde él la Torre sigue alcanzable: nunca hay callejones sin salida.
	var moves := []
	if not active or current == TOWER_CELL:
		return moves
	for cell in neighbors(current):
		if cell == TOWER_CELL:
			moves.append(cell)
		elif not visited.has(cell) and cell.y >= current.y and _tower_reachable(cell):
			moves.append(cell)
	return moves

func _tower_reachable(from: Vector2i) -> bool:
	var seen := {from: true}
	var queue := [from]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for other in neighbors(cell):
			if other == TOWER_CELL:
				return true
			if not seen.has(other) and not visited.has(other) and other.y >= cell.y:
				seen[other] = true
				queue.append(other)
	return false

func enter(cell: Vector2i) -> bool:
	if not cell in available_moves():
		return false
	current = cell
	visited[cell] = true
	map_changed.emit()
	match cell_type(cell):
		FIGHT:
			_pick_fight_layout()
			change_scene(fight_scene(0))
		FOUNTAIN:
			change_scene(FOUNTAIN_SCENE)
		SHOP:
			change_scene(SHOP_SCENE)
		TOWER:
			change_scene(TOWER_SCENE)
	return true

func depth() -> int:
	# Dificultad de los enfrentamientos: 1 en el primero y sube con cada uno superado.
	return fights_cleared + 1

func _pick_fight_layout() -> void:
	for phase in range(FIGHT_VARIANTS.size()):
		fight_layout[phase] = randi() % FIGHT_VARIANTS[phase].size() if layout_variants else 0

func fight_scene(phase: int) -> String:
	var options: Array = FIGHT_VARIANTS[phase]
	return options[clampi(int(fight_layout[phase]), 0, options.size() - 1)]

func fight_phase_of(scene_path: String) -> int:
	for phase in range(FIGHT_VARIANTS.size()):
		if scene_path in FIGHT_VARIANTS[phase]:
			return phase
	return -1

func next_fight_phase(scene_path: String) -> void:
	# Afueras → dentro de la fábrica → el guardián (en la variante elegida para este enfrentamiento).
	var index := fight_phase_of(scene_path)
	if index >= 0 and index + 1 < FIGHT_VARIANTS.size():
		change_scene(fight_scene(index + 1))

func complete_fight() -> void:
	fights_cleared += 1
	return_to_map()

func return_to_map() -> void:
	change_scene(MAP_SCENE)

func go_to_parkour() -> void:
	# Tras los tres guardianes, el sol absorbe a Viridy y, desde el blanco, aparece el camino al Ruby.
	fade_rect.color = Color(1.0, 0.97, 0.85, 1.0)
	change_scene(PARKOUR_SCENE, false)

func finish_victory(screen: Node) -> void:
	# Al fundirse con el Ruby: pantalla de run completada y fin de la run.
	finished = true
	screen.title_text = "¡RUN COMPLETADA!"
	screen.title_label.text = screen.title_text
	screen.message_text = "Llegaste al Ruby1 · Enfrentamientos superados: %d" % fights_cleared
	screen.show_custom_buttons([["Volver al Árbol Madre", return_to_hub], ["Menú principal", go_to_main_menu]])
	abort_run()

func show_defeat(screen: Node) -> void:
	screen.title_text = "FIN DE LA RUN"
	screen.title_label.text = screen.title_text
	screen.message_text = "Enfrentamientos superados: %d · Hexágonos recorridos: %d" % [fights_cleared, visited.size() - 1]
	screen.show_custom_buttons([["Volver al Árbol Madre", return_to_hub], ["Menú principal", go_to_main_menu]])
	abort_run()
	screen.show_results()

func return_to_hub() -> void:
	abort_run()
	change_scene(HUB_SCENE)

func go_to_main_menu() -> void:
	abort_run()
	change_scene(MAIN_MENU)

# ---------- Viridy entre escenas

func in_run_scene(node: Node) -> bool:
	return active and node != null and node.scene_file_path in RUN_SCENES

func attach_player(player: Node) -> void:
	# Lo llama cada Viridy al entrar al árbol: en una escena de la run recupera la vida guardada.
	if not is_instance_valid(player) or not in_run_scene(player.get_parent()):
		return
	max_health = player.max_health
	if health > 0:
		player.current_health = mini(health, player.max_health)
		player.health_changed.emit(player.current_health, player.max_health)
	if not player.health_changed.is_connected(_on_health_changed):
		player.health_changed.connect(_on_health_changed)

func _on_health_changed(value: int, maximum: int) -> void:
	if active:
		health = value
		max_health = maximum

func stored_health() -> int:
	return max_health if health < 0 else health

# ---------- Transiciones

func change_scene(path: String, fade := true) -> void:
	if changing:
		return
	changing = true
	var tree := get_tree()
	# Con pantalla, la transición de fuego jade (SceneFade); sin ella (pruebas), el fundido a negro.
	if fade and SceneFade.available() and fade_rect.color.a <= 0.0:
		await SceneFade.cover()
		tree.paused = false
		Engine.time_scale = TimeControl.base_scale()
		tree.change_scene_to_file(path)
		changing = false
		SceneFade.reveal()
		return
	if fade:
		fade_rect.color = Color(0.0, 0.0, 0.0, fade_rect.color.a)
		var tween := create_tween()
		tween.tween_property(fade_rect, "color:a", 1.0, FADE_TIME)
		await tween.finished
	tree.paused = false
	Engine.time_scale = TimeControl.base_scale()
	tree.change_scene_to_file(path)
	changing = false
	if fade_rect.color.a > 0.0:
		var back := create_tween()
		back.tween_interval(0.05)
		back.tween_property(fade_rect, "color:a", 0.0, FADE_TIME)
