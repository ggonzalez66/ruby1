extends Area2D

# Base común de los guardianes: hurtbox, barra de vida con nombre, aviso "!", inicio de combate,
# daño, bloqueo, derrota (con la pantalla de demo completada) y reinicio.
# Cada guardián implementa _build_body(), _boss_process(), is_warning() y lo que necesite.

@export var max_health := 100
@export var boss_name := "GUARDIÁN"
@export var boss_subtitle := ""
@export var min_x := 0.0
@export var max_x := 10000.0
@export var engage_distance := 750.0
@export var stagger_time := 1.4
@export var resist_chance := 0.3
@export var block_chance := 0.0
# Probabilidad de shinear de vuelta proyectiles devueltos y el cuchillo (0 = nunca).
@export var shine_chance := 0.0

signal boss_defeated

const WARNING_COLOR := Color(1.0, 0.25, 0.2)
const HIT_FLASH := Color(1.0, 0.5, 0.45)

var body_size := Vector2(70, 150)
var impact_offset := Vector2(0, -80)
var current_health := 0
var facing := -1
var flash_timer := 0.0
var spawn_position := Vector2.ZERO
var combat_started := false
var defeated := false

var visual: Node2D
var warning_label: Label
var health_fill: Polygon2D
var flash_polys: Array = []
var flash_colors: Array = []

func _ready() -> void:
	add_to_group(&"training_dummies")
	add_to_group(&"boss")
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	spawn_position = position
	current_health = max_health
	_configure()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = body_size
	shape.shape = rect
	shape.position = Vector2(0, -body_size.y * 0.5)
	add_child(shape)
	visual = Node2D.new()
	add_child(visual)
	_build_body()
	_build_ui()
	_update_health_bar()

func _build_ui() -> void:
	warning_label = Label.new()
	warning_label.text = "!"
	warning_label.add_theme_font_size_override("font_size", 40)
	warning_label.add_theme_color_override("font_color", WARNING_COLOR)
	warning_label.add_theme_color_override("font_outline_color", Color(0.1, 0.02, 0.02))
	warning_label.add_theme_constant_override("outline_size", 8)
	warning_label.position = Vector2(-8, -body_size.y - 80.0)
	warning_label.visible = false
	add_child(warning_label)

	var bar := Node2D.new()
	bar.position = Vector2(0, -body_size.y - 30.0)
	add_child(bar)
	bar.add_child(_poly([Vector2(-92, -7), Vector2(92, -7), Vector2(92, 7), Vector2(-92, 7)], Color(0.08, 0.04, 0.04, 0.9)))
	health_fill = _poly([], Color(0.9, 0.3, 0.22))
	bar.add_child(health_fill)
	var name_label := Label.new()
	name_label.text = boss_name
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.7))
	name_label.add_theme_color_override("font_outline_color", Color(0.1, 0.03, 0.02))
	name_label.add_theme_constant_override("outline_size", 5)
	name_label.position = Vector2(-82, -30)
	bar.add_child(name_label)

func _physics_process(delta: float) -> void:
	flash_timer = max(flash_timer - delta, 0.0)
	for index in range(flash_polys.size()):
		flash_polys[index].color = HIT_FLASH if flash_timer > 0.0 else flash_colors[index]
	if defeated:
		return
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if not combat_started and (_player_engaged(player) or _ally_in_combat()):
		combat_started = true
	_boss_process(delta, player)

# ---------- Para sobrescribir

func _configure() -> void:
	pass

func _build_body() -> void:
	pass

func _boss_process(_delta: float, _player: Node2D) -> void:
	pass

func is_warning() -> bool:
	return false

func _can_block() -> bool:
	return false

func _on_block() -> void:
	pass

func _on_hit(_damage: int) -> void:
	pass

func _on_defeat() -> void:
	pass

func _on_reset() -> void:
	pass

func _on_shine() -> void:
	pass

func _shine_color() -> Color:
	return Color(1.0, 0.45, 0.8)

func on_deflected(_by: Node) -> void:
	pass

# ---------- Común

func is_defeated() -> bool:
	return defeated

func take_hit(_source_position: Vector2, _direction: int = 1, damage: int = 1) -> void:
	if defeated:
		return
	current_health = max(current_health - max(damage, 0), 0)
	flash_timer = 0.08
	_update_health_bar()
	_on_hit(damage)
	if current_health == 0:
		_defeat()

func on_shine_hit(direction: int, strength: float) -> void:
	# El golpe del shine no interrumpe al guardián: solo lo empuja un poco hacia atrás.
	if defeated:
		return
	flash_timer = 0.08
	var target_x: float = clamp(position.x + direction * strength * 0.07, min_x, max_x)
	var tween := create_tween()
	tween.tween_property(self, "position:x", target_x, 0.15).set_ease(Tween.EASE_OUT)

func try_shine(_thing: Node) -> bool:
	if defeated or shine_chance <= 0.0 or randf() >= shine_chance:
		return false
	Fx.shine(get_parent(), global_position + impact_offset, _shine_color(), 48.0)
	Shine.enemy_feedback(get_tree(), global_position + impact_offset)
	_on_shine()
	return true

func try_block(_source_position: Vector2) -> bool:
	# Bloquea algunos golpes ligeros sin cargar cuando no está atacando.
	if defeated or block_chance <= 0.0 or not _can_block() or randf() >= block_chance:
		return false
	_on_block()
	return true

func _defeat() -> void:
	defeated = true
	Ferocity.add("boss_kill", 200.0, "GUARDIÁN CAÍDO", Ferocity.BONUS_COLOR)
	warning_label.visible = false
	set_deferred("monitorable", false)
	_on_defeat()
	boss_defeated.emit()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(visual, "rotation", 1.4 * -facing, 0.6)
	tween.tween_property(visual, "modulate:a", 0.25, 0.8)
	Fx.text(get_parent(), global_position + Vector2(0, -body_size.y - 70.0), "¡VICTORIA!", Color(1.0, 0.92, 0.5))
	# Tras un momento, pantalla de demo completada.
	get_tree().create_timer(1.6).timeout.connect(_show_demo_complete)

func _show_demo_complete() -> void:
	if not defeated:
		return
	# En el trío, la torre se completa al caer el último.
	for other in get_tree().get_nodes_in_group(&"boss"):
		if not other.is_defeated():
			return
	# En el Gauntlet decide el director de oleadas (portales para seguir o terminar).
	var director := get_tree().get_first_node_in_group(&"gauntlet_director")
	if director:
		director.on_bosses_defeated()
		return
	var screen := get_tree().get_first_node_in_group(&"demo_complete")
	if screen:
		screen.show_results()

func reset_dummy() -> void:
	position = spawn_position
	current_health = max_health
	defeated = false
	combat_started = false
	flash_timer = 0.0
	visual.rotation = 0.0
	visual.modulate.a = 1.0
	visible = true
	warning_label.visible = false
	set_deferred("monitorable", true)
	_update_health_bar()
	_on_reset()

func _update_health_bar() -> void:
	var ratio: float = float(current_health) / float(max(max_health, 1))
	var right: float = -90.0 + 180.0 * ratio
	health_fill.polygon = PackedVector2Array([Vector2(-90, -5), Vector2(right, -5), Vector2(right, 5), Vector2(-90, 5)])

# ---------- Utilidades

func _distance_to(player: Node2D) -> float:
	return abs(player.global_position.x - global_position.x)

func _player_engaged(player: Node2D) -> bool:
	if player == null:
		return false
	var offset := player.global_position - global_position
	return abs(offset.x) < engage_distance and abs(offset.y) < 300.0

func _ally_in_combat() -> bool:
	# En el trío, en cuanto uno entra en combate entran todos.
	for other in get_tree().get_nodes_in_group(&"boss"):
		if other != self and other.combat_started and not other.is_defeated():
			return true
	return false

func _face(player: Node2D) -> void:
	if player == null:
		return
	facing = 1 if player.global_position.x >= global_position.x else -1
	visual.scale.x = facing

func _hit_player(player: Node, damage: int) -> void:
	player.take_damage(damage, global_position + Vector2(0, -60), self)

func _segment_hits_player(player: Node2D, from: Vector2, to: Vector2, radius: float) -> bool:
	# ¿Algún punto del cuerpo de Rengar está a menos de "radius" del segmento (coordenadas globales)?
	if player == null:
		return false
	# Con el rugido activo, tocar su aura ya cuenta (el golpe se parrea).
	if player.has_method("parry_reaches") and player.parry_reaches(from, to):
		return true
	for offset in [Vector2(0, -4), Vector2(0, -14), Vector2(0, -26)]:
		var point: Vector2 = player.global_position + offset
		var closest := Geometry2D.get_closest_point_to_segment(point, from, to)
		if closest.distance_to(point) <= radius:
			return true
	return false

func _make_trail() -> Line2D:
	# Estela de los ataques: gruesa en la punta reciente y transparente en la cola.
	var trail := Line2D.new()
	trail.width = 18.0
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.35, 0.25, 0.0))
	gradient.set_color(1, Color(1.0, 0.92, 0.85, 0.8))
	trail.gradient = gradient
	var width := Curve.new()
	width.add_point(Vector2(0.0, 0.1))
	width.add_point(Vector2(1.0, 1.0))
	trail.width_curve = width
	trail.top_level = true
	add_child(trail)
	return trail

func _add_flash_poly(poly: Polygon2D) -> Polygon2D:
	flash_polys.append(poly)
	flash_colors.append(poly.color)
	return poly

func _poly(points: Array, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array(points)
	poly.color = color
	return poly
