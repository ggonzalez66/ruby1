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
# Disparo: 0 = no dispara. La componente x de la dirección se orienta hacia el lado de Rengar.
@export var shoot_interval := 0.0
@export var shoot_direction := Vector2(-1, 0)
@export var shoot_range := 800.0
@export var projectile_speed := 460.0
@export var projectile_damage := 10
@export var shoot_warning_time := 0.35

const PROJECTILE_SCRIPT := preload("res://projectile.gd")
const SHOOT_WARNING_COLOR := Color(1.0, 0.85, 0.95)

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
var pull_offset := Vector2.ZERO
var pull_tween: Tween
var shoot_timer := 0.0
var impact_offset := Vector2(0, -28)

func _ready() -> void:
	add_to_group(&"training_dummies")
	anchor_position = position
	stand.visible = not aerial
	if shoot_interval > 0.0:
		_add_cannon()
	reset_dummy()

func reset_dummy() -> void:
	current_health = max_health
	flash_timer = 0.0
	wobble = 0.0
	path_time = 0.0
	shoot_timer = shoot_interval
	if pull_tween:
		pull_tween.kill()
	pull_offset = Vector2.ZERO
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
	position = anchor_position + pull_offset + _get_path_offset() + Vector2(wobble * push_distance, -abs(wobble) * lift_distance)
	rotation = wobble * 0.08
	body.color = hit_color if flash_timer > 0.0 else base_color
	if shoot_interval > 0.0:
		_update_shooting(delta)

func take_hit(_source_position: Vector2, direction: int = 1, damage: int = 1) -> void:
	if current_health <= 0:
		return

	current_health = max(current_health - max(damage, 1), 0)
	flash_timer = flash_duration
	wobble = clamp(wobble + float(direction) * 1.0, -1.0, 1.0)
	_update_health_bar()

	if current_health == 0:
		_die()

func pull_towards(point: Vector2, strength: float) -> void:
	# El recall del cuchillo arrastra al dummy hacia Rengar; los de suelo solo en horizontal.
	var center := global_position + impact_offset
	var direction := (point - center).normalized()
	if not aerial:
		direction = Vector2(sign(point.x - center.x), 0.0)
	var distance: float = min(strength, center.distance_to(point) * 0.6)
	if pull_tween:
		pull_tween.kill()
	pull_tween = create_tween()
	pull_tween.tween_property(self, "pull_offset", pull_offset + direction * distance, 0.18).set_ease(Tween.EASE_OUT)

func _update_shooting(delta: float) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null or player.global_position.distance_to(global_position) > shoot_range:
		shoot_timer = max(shoot_timer, shoot_warning_time + 0.2)
		return
	shoot_timer -= delta
	# Aviso: el cuerpo parpadea en claro justo antes de disparar.
	if shoot_timer <= shoot_warning_time and flash_timer <= 0.0:
		var blink: bool = int(shoot_timer * 20.0) % 2 == 0
		body.color = SHOOT_WARNING_COLOR if blink else base_color
	if shoot_timer > 0.0:
		return
	shoot_timer = shoot_interval
	var direction := shoot_direction.normalized()
	direction.x = abs(direction.x) * (1.0 if player.global_position.x >= global_position.x else -1.0)
	var projectile := PROJECTILE_SCRIPT.new()
	projectile.velocity = direction * projectile_speed
	projectile.damage = projectile_damage
	projectile.shooter = self
	get_parent().add_child(projectile)
	projectile.global_position = global_position + impact_offset + direction * 20.0

func _add_cannon() -> void:
	var cannon := Polygon2D.new()
	cannon.polygon = PackedVector2Array([Vector2(-6, -38), Vector2(6, -38), Vector2(6, -22), Vector2(-6, -22)])
	cannon.color = Color(0.18, 0.08, 0.2)
	add_child(cannon)
	var eye := Polygon2D.new()
	eye.polygon = PackedVector2Array([Vector2(-3, -33), Vector2(3, -33), Vector2(3, -27), Vector2(-3, -27)])
	eye.color = Color(1.0, 0.4, 0.75)
	add_child(eye)

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
