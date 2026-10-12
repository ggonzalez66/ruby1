extends Area2D

@export var max_health := 6
@export var base_color := Color(0.941176, 0.678431, 0.258824, 1.0)
@export var hit_color := Color(1.0, 0.341176, 0.341176, 1.0)
@export var recover_speed := 12.0
@export var push_distance := 14.0
@export var lift_distance := 8.0
@export var flash_duration := 0.12
@export var health_bar_green := Color(0.313726, 0.862745, 0.431373, 1.0)
@export var health_bar_yellow := Color(0.980392, 0.807843, 0.262745, 1.0)
@export var health_bar_red := Color(0.94902, 0.313726, 0.313726, 1.0)
@export var aerial := false
@export var move_offset := Vector2.ZERO
@export var orbit_radius := 0.0
@export var move_period := 3.0
@export_range(0.0, 1.0) var move_phase := 0.0
@export var hover_amplitude := 5.0
@export var hover_period := 1.6

@onready var body: Polygon2D = $Body
@onready var health_fill: Polygon2D = $HealthBarPivot/HealthBarFill
@onready var health_back: Polygon2D = $HealthBarPivot/HealthBarBack
@onready var stand: Polygon2D = $Stand
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var anchor_position := Vector2.ZERO
var flash_timer := 0.0
var wobble := 0.0
var current_health := 0
var health_bar_full_width := 32.0
var path_time := 0.0

func _ready() -> void:
	add_to_group(&"training_dummies")
	anchor_position = position
	stand.visible = not aerial
	reset_dummy()

func reset_dummy() -> void:
	current_health = max_health
	flash_timer = 0.0
	wobble = 0.0
	path_time = 0.0
	rotation = 0.0
	visible = true
	set_deferred("monitorable", true)
	collision_shape.set_deferred("disabled", false)
	body.color = base_color
	position = anchor_position + _get_path_offset()
	_update_health_bar()

func _process(delta: float) -> void:
	if current_health <= 0:
		return

	path_time += delta
	flash_timer = max(flash_timer - delta, 0.0)
	wobble = move_toward(wobble, 0.0, recover_speed * delta)
	position = anchor_position + _get_path_offset() + Vector2(wobble * push_distance, -abs(wobble) * lift_distance)
	rotation = wobble * 0.08
	body.color = hit_color if flash_timer > 0.0 else base_color

func take_hit(_source_position: Vector2, direction: int = 1, damage: int = 1) -> void:
	if current_health <= 0:
		return

	current_health = max(current_health - max(damage, 1), 0)
	flash_timer = flash_duration
	wobble = clamp(wobble + float(direction) * 1.0, -1.0, 1.0)
	_update_health_bar()

	if current_health == 0:
		_die()

func _die() -> void:
	# Se oculta en vez de liberarse para poder regenerarlo con reset_dummy().
	visible = false
	set_deferred("monitorable", false)
	collision_shape.set_deferred("disabled", true)

func _get_path_offset() -> Vector2:
	var offset := Vector2.ZERO
	if move_period > 0.0:
		var angle: float = (path_time / move_period + move_phase) * TAU
		# Va y vuelve entre el ancla y ancla + move_offset.
		offset += move_offset * (0.5 - 0.5 * cos(angle))
		if orbit_radius > 0.0:
			offset += Vector2(cos(angle), sin(angle)) * orbit_radius
	if aerial and hover_period > 0.0:
		offset.y += sin(path_time / hover_period * TAU) * hover_amplitude
	return offset

func _update_health_bar() -> void:
	var health_ratio: float = float(current_health) / float(max(max_health, 1))
	var bar_width: float = max(health_bar_full_width * health_ratio, 0.0)
	var left_x: float = -health_bar_full_width * 0.5
	var right_x: float = left_x + bar_width

	health_fill.polygon = PackedVector2Array([
		Vector2(left_x, -3.0),
		Vector2(right_x, -3.0),
		Vector2(right_x, 3.0),
		Vector2(left_x, 3.0)
	])

	if health_ratio > 0.6:
		health_fill.color = health_bar_green
	elif health_ratio > 0.3:
		health_fill.color = health_bar_yellow
	else:
		health_fill.color = health_bar_red

	health_fill.visible = current_health > 0
	health_back.visible = current_health < max_health
