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

@onready var body: Polygon2D = $Body
@onready var health_fill: Polygon2D = $HealthBarPivot/HealthBarFill
@onready var health_back: Polygon2D = $HealthBarPivot/HealthBarBack

var anchor_position := Vector2.ZERO
var flash_timer := 0.0
var wobble := 0.0
var current_health := 0
var health_bar_full_width := 32.0

func _ready() -> void:
	anchor_position = position
	current_health = max_health
	body.color = base_color
	_update_health_bar()

func _process(delta: float) -> void:
	flash_timer = max(flash_timer - delta, 0.0)
	wobble = move_toward(wobble, 0.0, recover_speed * delta)
	position = anchor_position + Vector2(wobble * push_distance, -abs(wobble) * lift_distance)
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
		queue_free()

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
