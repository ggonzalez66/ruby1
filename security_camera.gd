extends Area2D

# Cámara de seguridad de las fábricas de la run: colgada de un soporte, barre de un lado a otro con un cono
# de visión. Si ve a Viridy (sin paredes en medio y sin estar invisible por un bush) la sigue con la lente y
# carga la alarma global en un instante (stealth_director.camera_spotted). Cuando su alarma salta llama
# refuerzos una vez, como el centinela.
# Se puede destruir (golpes, lanza o disparos; `hits` impactos): no da rubíes pero sí estilo, y una cámara
# rota ya no ve, así que romperlas ayuda a mantener el sigilo. Romperla no alerta a los guardias.

@export var aim_angle := 90.0
@export var sweep := 35.0
@export var period := 4.0
@export var view_range := 560.0
@export var cone_half := 17.0
@export var reinforcements := 4
@export var alert_duration := 8.0
@export var hits := 3

const HOUND_SCRIPT := preload("res://hound.gd")
const CHASER_SCRIPT := preload("res://chaser_dummy.gd")
const BODY := Color(0.28, 0.3, 0.34)
const BODY_LIGHT := Color(0.5, 0.53, 0.58)
const CONE_IDLE := Color(1.0, 0.9, 0.4, 0.1)
const CONE_SPOT := Color(1.0, 0.2, 0.15, 0.22)
const LED := Color(1.0, 0.15, 0.1)
const LOCK_TIME := 1.0
const TRACK_SPEED := 4.0

var time := 0.0
var angle := 0.0
var spotting := false
var lock_left := 0.0
var called_reinforcements := false
var stealth: Node
var player: Node2D
var impact_offset := Vector2.ZERO
var hits_left := 0
var destroyed := false
var flash_left := 0.0
var spark_left := 0.0

func _ready() -> void:
	add_to_group(&"security_cameras")
	z_index = 4
	angle = deg_to_rad(aim_angle)
	time = randf() * period
	hits_left = hits
	# Hurtbox en la capa de los enemigos: la encuentran los golpes, la lanza y las balas.
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 24.0
	shape.shape = circle
	add_child(shape)

func take_hit(_source_position: Vector2, _direction: int = 1, _damage: int = 1, _play_sound: bool = true) -> void:
	if destroyed:
		return
	hits_left -= 1
	flash_left = 0.1
	Fx.zap(get_parent(), global_position, Color(0.5, 0.8, 1.0), 0.5)
	if hits_left <= 0:
		_destroy()
	queue_redraw()

func _destroy() -> void:
	destroyed = true
	spotting = false
	lock_left = 0.0
	set_deferred("monitorable", false)
	# Sin rubíes: solo estilo.
	Ferocity.add("camera_destroyed", 30.0, "CÁMARA DESTRUIDA", Ferocity.BONUS_COLOR)
	Stats.add("cameras_destroyed")
	Sfx.play("grenade_blast", -8.0, 1.5)
	Fx.explosion(get_parent(), global_position, 0.35)
	Fx.zap(get_parent(), global_position, Color(0.5, 0.8, 1.0), 0.9)
	# Queda colgando del soporte, apagada.
	var drop := deg_to_rad(aim_angle) + 0.9 * (1.0 if cos(deg_to_rad(aim_angle)) >= 0.0 else -1.0)
	create_tween().tween_property(self, "angle", drop, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	spark_left = 1.0
	queue_redraw()

func _physics_process(delta: float) -> void:
	time += delta
	flash_left = maxf(flash_left - delta, 0.0)
	if destroyed:
		# Chispazos de vez en cuando.
		spark_left -= delta
		if spark_left <= 0.0:
			spark_left = randf_range(1.5, 3.0)
			if is_visible_in_tree():
				Fx.zap(get_parent(), global_position + Vector2.from_angle(angle) * 16.0, Color(0.5, 0.8, 1.0), 0.3)
		queue_redraw()
		return
	if stealth == null or not is_instance_valid(stealth):
		stealth = get_tree().get_first_node_in_group(&"stealth_director")
	player = get_tree().get_first_node_in_group(&"player") as Node2D
	var was_spotting := spotting
	spotting = stealth != null and stealth.running and _sees_player()
	if spotting:
		lock_left = LOCK_TIME
		if not was_spotting:
			Sfx.play("enemy_alert", 0.0, 1.5)
		# La lente sigue a Viridy.
		angle = lerp_angle(angle, (_target_point() - global_position).angle(), minf(TRACK_SPEED * 2.0 * delta, 1.0))
		if stealth.camera_spotted(delta) and not called_reinforcements:
			called_reinforcements = true
			_call_reinforcements()
	else:
		lock_left = maxf(lock_left - delta, 0.0)
		if lock_left <= 0.0:
			var sweep_angle := deg_to_rad(aim_angle + sweep * sin(time * TAU / period))
			angle = lerp_angle(angle, sweep_angle, minf(TRACK_SPEED * delta, 1.0))
	queue_redraw()

func _target_point() -> Vector2:
	return player.global_position + Vector2(0, -40)

func _sees_player() -> bool:
	if player == null or player.dead or stealth.player_cloaked():
		return false
	var space := get_world_2d().direct_space_state
	for offset in [Vector2(0, -40), Vector2(0, -8), Vector2(0, -80)]:
		var point: Vector2 = player.global_position + offset
		var to_point := point - global_position
		if to_point.length() > view_range:
			continue
		if absf(wrapf(to_point.angle() - angle, -PI, PI)) > deg_to_rad(cone_half):
			continue
		if space.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, point, 2)).is_empty():
			return true
	return false

func _call_reinforcements() -> void:
	# Llegan por los dos lados de Viridy, sobre el suelo que tengan debajo.
	var director := get_tree().get_first_node_in_group(&"gauntlet_director")
	var space := get_world_2d().direct_space_state
	for index in range(reinforcements):
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var x: float = player.global_position.x + side * (420.0 + (index / 2) * 110.0)
		var from := Vector2(x, player.global_position.y - 120.0)
		var floor_hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 900), 2))
		if floor_hit.is_empty():
			continue
		var enemy: Area2D = HOUND_SCRIPT.new() if index % 2 == 0 else CHASER_SCRIPT.new()
		enemy.position = floor_hit.position
		enemy.alert(alert_duration)
		if director != null and director.has_method("add_reinforcement"):
			director.add_reinforcement(enemy)
		else:
			get_parent().add_child.call_deferred(enemy)
		Fx.warp_in(get_parent(), enemy.position, Color(1.0, 0.3, 0.25))

func _draw() -> void:
	# Cono de visión (guía visual: no se recorta con las paredes) y la cámara sobre su soporte.
	var direction := Vector2.from_angle(angle)
	var cone := PackedVector2Array([Vector2.ZERO])
	for index in range(9):
		var a := angle - deg_to_rad(cone_half) + deg_to_rad(cone_half * 2.0) * index / 8.0
		cone.append(Vector2.from_angle(a) * view_range)
	var active: bool = not destroyed and stealth != null and is_instance_valid(stealth) and stealth.running
	if active:
		draw_colored_polygon(cone, CONE_SPOT if spotting else CONE_IDLE)
	# Soporte hacia la pared o el techo (el lado opuesto al que mira por defecto).
	var mount := -Vector2.from_angle(deg_to_rad(aim_angle)) * 26.0
	draw_line(mount, Vector2.ZERO, BODY.darkened(0.3), 6.0)
	draw_circle(mount, 7.0, BODY.darkened(0.2))
	var side := direction.orthogonal()
	var body := PackedVector2Array([-direction * 14.0 + side * 10.0, direction * 18.0 + side * 8.0, direction * 18.0 - side * 8.0, -direction * 14.0 - side * 10.0])
	draw_colored_polygon(body, Color(1.0, 0.8, 0.75) if flash_left > 0.0 else (BODY.darkened(0.35) if destroyed else BODY))
	draw_line(-direction * 14.0 + side * 10.0, direction * 18.0 + side * 8.0, BODY_LIGHT, 2.0)
	draw_circle(direction * 20.0, 6.0, Color(0.08, 0.1, 0.14))
	if destroyed:
		# Lente rota.
		draw_line(direction * 20.0 + side * 4.0, direction * 20.0 - side * 4.0, Color(0.5, 0.55, 0.6), 1.5)
		return
	draw_circle(direction * 20.0, 3.0, Color(0.4, 0.75, 1.0) if not spotting else LED)
	var blink: bool = spotting or int(time * 2.0) % 2 == 0
	if active and blink:
		draw_circle(-direction * 8.0 - side * 12.0, 3.0, LED)
