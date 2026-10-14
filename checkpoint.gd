extends Area2D

# Farol de checkpoint: al tocarlo, Rengar reaparecerá aquí (morir o pulsar R).

# Al encender un checkpoint por primera vez cura esta fracción de la vida máxima (solo una vez cada uno).
@export var heal_fraction := 0.35

const POLE_COLOR := Color(0.2, 0.13, 0.08)
const OFF_COLOR := Color(0.3, 0.42, 0.32)
const ON_COLOR := Color(0.75, 1.0, 0.55)

var lamp: Polygon2D
var glow: Polygon2D
var active := false
var heal_used := false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(50, 90)
	shape.shape = rect
	shape.position = Vector2(0, -45)
	add_child(shape)

	var pole := Polygon2D.new()
	pole.polygon = PackedVector2Array([Vector2(-3, 0), Vector2(3, 0), Vector2(3, -56), Vector2(-3, -56)])
	pole.color = POLE_COLOR
	add_child(pole)
	glow = _diamond(Vector2(0, -64), 20.0, Color(ON_COLOR, 0.0))
	add_child(glow)
	lamp = _diamond(Vector2(0, -64), 9.0, OFF_COLOR)
	add_child(lamp)
	body_entered.connect(_on_body_entered)

func _process(_delta: float) -> void:
	if active:
		glow.color.a = 0.25 + 0.12 * sin(Time.get_ticks_msec() / 250.0)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group(&"player"):
		return
	body.spawn_position = global_position
	if active:
		return
	for other in get_tree().get_nodes_in_group(&"checkpoints"):
		other.set_active(false)
	set_active(true)
	Fx.text(get_parent(), global_position + Vector2(0, -90), "Checkpoint", ON_COLOR)
	if not heal_used and body.has_method("heal"):
		heal_used = true
		body.heal(int(round(body.max_health * heal_fraction)))

func set_active(value: bool) -> void:
	active = value
	lamp.color = ON_COLOR if value else OFF_COLOR
	glow.color.a = 0.3 if value else 0.0

func _enter_tree() -> void:
	add_to_group(&"checkpoints")

func _diamond(center: Vector2, radius: float, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius * 0.7, 0), center + Vector2(0, radius), center + Vector2(-radius * 0.7, 0)])
	poly.color = color
	return poly
