extends Area2D

@export var base_color := Color(0.941176, 0.678431, 0.258824, 1.0)
@export var hit_color := Color(1.0, 0.341176, 0.341176, 1.0)
@export var recover_speed := 12.0
@export var push_distance := 14.0
@export var lift_distance := 8.0
@export var flash_duration := 0.12

@onready var body: Polygon2D = $Body

var anchor_position := Vector2.ZERO
var flash_timer := 0.0
var wobble := 0.0

func _ready() -> void:
	anchor_position = position
	body.color = base_color

func _process(delta: float) -> void:
	flash_timer = max(flash_timer - delta, 0.0)
	wobble = move_toward(wobble, 0.0, recover_speed * delta)
	position = anchor_position + Vector2(wobble * push_distance, -abs(wobble) * lift_distance)
	rotation = wobble * 0.08
	body.color = hit_color if flash_timer > 0.0 else base_color

func take_hit(_source_position: Vector2, direction: int = 1) -> void:
	flash_timer = flash_duration
	wobble = clamp(wobble + float(direction) * 1.0, -1.0, 1.0)
