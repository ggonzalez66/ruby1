extends CharacterBody2D

@export var speed := 420.0
@export var jump_velocity := -1220.0
@export var gravity := 1200.0

@onready var pivot: Node2D = $Pivot

var facing := 1

func _ready() -> void:
	print("PLAYER READY")

func _physics_process(delta: float) -> void:
	print("on_floor:", is_on_floor(), " vel:", velocity)

	# Gravedad
	if not is_on_floor():
		velocity.y += gravity * delta

	# Movimiento horizontal (input directo)
	var dir := 0
	if Input.is_action_pressed("move_left"):
		dir -= 1
	if Input.is_action_pressed("move_right"):
		dir += 1

	velocity.x = dir * speed

	# Girar personaje
	if dir != 0:
		facing = sign(dir)
		pivot.scale.x = facing

	# Salto
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	move_and_slide()

