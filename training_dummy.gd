extends Area2D

const RUBY_CORE_SCRIPT := preload("res://ruby_core.gd")
const LAUNCH_MOTION := preload("res://enemy_launch_motion.gd")
var ruby_core: Node2D

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
# Probabilidad (baja) de que un tirador shinee de vuelta lo que le llega: sus proyectiles devueltos y el cuchillo.
@export var shine_chance := 0.2

const PROJECTILE_SCRIPT := preload("res://projectile.gd")
const FALL_GRAVITY := 1500.0
const FALL_MAX_SPEED := 900.0
# Caer más que esto (unos 2,5 saltos) hace que el dummy explote al tocar el suelo.
const FALL_DEATH_HEIGHT := 260.0
const SHOOT_WARNING_COLOR := Color(1.0, 0.85, 0.95)
const SHINE_COLOR := Color(1.0, 0.45, 0.8)
# Los tiradores voladores disparan el doble de rápido y más seguido que los de suelo.
const AERIAL_PROJECTILE_SPEED_SCALE := 2.0
const AERIAL_SHOOT_INTERVAL_SCALE := 0.7

@onready var body: Polygon2D = $Body
@onready var health_fill: Polygon2D = $HealthBarPivot/HealthBarFill
@onready var health_back: Polygon2D = $HealthBarPivot/HealthBarBack
@onready var stand: Polygon2D = $Stand
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var anchor_position := Vector2.ZERO
# Donde empieza (al reaparecer Viridy vuelve aquí aunque un uppercut lo haya movido).
var spawn_anchor := Vector2.ZERO
var flash_timer := 0.0
var wobble := 0.0
var current_health := 0
var health_bar_full_width := 32.0
var path_time := 0.0
var pull_offset := Vector2.ZERO
# Lanzado por un uppercut: sube a un punto delante de Viridy y flota; luego se queda ahí (volador) o cae
# en vertical (de suelo).
var juggle_offset := Vector2.ZERO
var launched := false
var launch_elapsed := 0.0
var launch_from := Vector2.ZERO
var launch_target := Vector2.ZERO
var launch_rise := 0.0
var launch_hang := 0.0
var juggle_fall := false
var fall_offset := 0.0
var fall_velocity := 0.0
var fall_distance := 0.0
var pull_tween: Tween
var shoot_timer := 0.0
var impact_offset := Vector2(0, -28)

func _ready() -> void:
	add_to_group(&"training_dummies")
	anchor_position = position
	spawn_anchor = position
	stand.visible = not aerial
	if shoot_interval > 0.0:
		if aerial:
			projectile_speed *= AERIAL_PROJECTILE_SPEED_SCALE
			shoot_interval *= AERIAL_SHOOT_INTERVAL_SCALE
		_add_cannon()
	reset_dummy()
	ruby_core = RUBY_CORE_SCRIPT.new()
	ruby_core.name = "RubyCore"
	add_child(ruby_core)

func reset_dummy() -> void:
	if is_instance_valid(ruby_core):
		ruby_core.reset_core()
	launched = false
	juggle_fall = false
	juggle_offset = Vector2.ZERO
	anchor_position = spawn_anchor
	current_health = max_health
	flash_timer = 0.0
	wobble = 0.0
	path_time = 0.0
	shoot_timer = shoot_interval
	if pull_tween:
		pull_tween.kill()
	pull_offset = Vector2.ZERO
	fall_offset = 0.0
	fall_velocity = 0.0
	fall_distance = 0.0
	rotation = 0.0
	visible = true
	set_deferred("monitorable", true)
	collision_shape.set_deferred("disabled", false)
	body.color = base_color
	position = anchor_position + _get_path_offset()
	_update_health_bar()

func _physics_process(delta: float) -> void:
	if ruby_core.holds_actor():
		return
	if current_health <= 0:
		return

	path_time += delta
	flash_timer = max(flash_timer - delta, 0.0)
	wobble = move_toward(wobble, 0.0, recover_speed * delta)
	if launched:
		_update_launch(delta)
		return
	if not aerial:
		_update_gravity(delta)
		if current_health <= 0:
			return
	position = anchor_position + pull_offset + Vector2(0.0, fall_offset) + _get_path_offset() + juggle_offset + Vector2(wobble * push_distance, -abs(wobble) * lift_distance)
	rotation = wobble * 0.08
	body.color = hit_color if flash_timer > 0.0 else base_color
	if shoot_interval > 0.0:
		_update_shooting(delta)

func take_hit(_source_position: Vector2, direction: int = 1, damage: int = 1) -> void:
	if ruby_core != null and ruby_core.locked:
		return
	if current_health <= 0:
		return

	current_health = max(current_health - max(damage, 0), 0)
	flash_timer = flash_duration
	wobble = clamp(wobble + float(direction) * 1.0, -1.0, 1.0)
	_update_health_bar()

	if current_health == 0:
		_die()

func launch_to(point: Vector2, rise_time: float, hang_time: float) -> void:
	if ruby_core != null and ruby_core.locked:
		return
	if current_health <= 0:
		return
	launched = true
	launch_elapsed = 0.0
	launch_from = global_position
	launch_target = point
	launch_rise = maxf(rise_time, 0.01)
	launch_hang = hang_time

func _update_launch(delta: float) -> void:
	launch_elapsed += delta
	var t := clampf(launch_elapsed / launch_rise, 0.0, 1.0)
	if LAUNCH_MOTION.move_to(self, collision_shape, launch_from.lerp(launch_target, ease(t, 0.4))):
		launch_target = global_position
		launch_from = global_position
		launch_elapsed = maxf(launch_elapsed, launch_rise)
	body.color = hit_color if flash_timer > 0.0 else base_color
	if launch_elapsed >= launch_rise + launch_hang:
		juggle_offset = global_position - (anchor_position + pull_offset + Vector2(0, fall_offset) + _get_path_offset())
		_settle_after_launch()

func _settle_after_launch() -> void:
	launched = false
	# Se queda donde lo dejó el uppercut: el volador flota ahí (y sigue su vaivén desde ese punto); el de
	# suelo conserva la x y luego cae.
	if aerial:
		anchor_position += juggle_offset
		juggle_offset = Vector2.ZERO
	else:
		anchor_position.x += juggle_offset.x
		fall_offset += juggle_offset.y
		juggle_offset = Vector2.ZERO
		fall_velocity = 0.0
		fall_distance = 0.0
		juggle_fall = true

func on_deflected(_by: Node) -> void:
	ruby_core.register_parry()

func try_shine(_thing: Node) -> bool:
	# Solo los tiradores, y no siempre: lo que les llega vuelve hacia Rengar.
	if ruby_core.holds_actor() or shoot_interval <= 0.0 or current_health <= 0 or randf() >= shine_chance:
		return false
	Fx.shine(get_parent(), global_position + impact_offset, SHINE_COLOR, 30.0)
	Shine.enemy_feedback(get_tree(), global_position + impact_offset)
	Sfx.play("shine", 0.0, 0.8)
	flash_timer = 0.0
	wobble = 0.0
	# Recarga un poco el disparo para que no dispare justo encima del shine.
	shoot_timer = max(shoot_timer, shoot_warning_time + 0.4)
	return true

func _update_gravity(delta: float) -> void:
	# Los dummies de suelo caen si se quedan sin suelo (por ejemplo, arrastrados por el cuchillo).
	var base: Vector2 = get_parent().global_transform * (anchor_position + pull_offset + Vector2(0.0, fall_offset) + _get_path_offset())
	var reach: float = max(fall_velocity * delta, 0.0) + 2.0
	var query := PhysicsRayQueryParameters2D.create(base + Vector2(0, -4), base + Vector2(0, reach), 2)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		if fall_distance > FALL_DEATH_HEIGHT and not juggle_fall:
			_explode()
			return
		fall_offset += hit.position.y - base.y
		fall_velocity = 0.0
		fall_distance = 0.0
		juggle_fall = false
		return
	fall_velocity = min(fall_velocity + FALL_GRAVITY * delta, FALL_MAX_SPEED)
	var step: float = fall_velocity * delta
	fall_offset += step
	fall_distance += step
	if fall_distance > 3000.0:
		_die()

func _explode() -> void:
	Ferocity.add("void_kill", 40.0, "AL VACÍO", Ferocity.BONUS_COLOR)
	var center := global_position + impact_offset
	Fx.impact(get_parent(), center, Fx.GOLD, 2.4)
	Fx.puff(get_parent(), center, Color(1.0, 0.6, 0.2, 0.9))
	Fx.text(get_parent(), center + Vector2(0, -30), "¡BOOM!", Color(1.0, 0.75, 0.4))
	current_health = 0
	_update_health_bar()
	_die()

func on_shine_hit(direction: int, _strength: float) -> void:
	if ruby_core != null and ruby_core.locked:
		return
	# El golpe del shine no lo daña: lo empuja (el triple de lo que se mueve al recibir un golpe).
	if current_health <= 0:
		return
	flash_timer = flash_duration
	wobble = clamp(wobble + float(direction), -1.0, 1.0)
	if pull_tween:
		pull_tween.kill()
	pull_tween = create_tween()
	pull_tween.tween_property(self, "pull_offset", pull_offset + Vector2(direction * push_distance * 3.0, 0.0), 0.15).set_ease(Tween.EASE_OUT)

func pull_towards(point: Vector2, strength: float) -> void:
	if ruby_core != null and ruby_core.locked:
		return
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
	var was_waiting: bool = shoot_timer > shoot_warning_time
	shoot_timer -= delta
	if was_waiting and shoot_timer <= shoot_warning_time:
		Sfx.play("enemy_charge")
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
	Sfx.play("enemy_shoot")
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
	Stats.add("dummies_killed")
	Sfx.play("enemy_die")
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
