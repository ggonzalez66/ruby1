extends Node

# Muerte dramática de Viridy (la crea movimiento._start_death). Solo presentación: la muerte, el `died` y
# la pantalla de fin siguen igual.
#   1. El golpe letal congela el juego: pose de dolor (2.º fotograma de viridy_hurt_arcade), zoom de cámara,
#      toda la pantalla en negativo y un golpe crítico con eco.
#   2. Sale volando y girando con el 1.er fotograma de la hoja de dolor.
#   3. Al rato estalla en fuego verde y desaparece.
# Corre en tiempo real durante el congelado (Engine.time_scale queda casi a cero).

const FREEZE_TIME := 0.62
const FLIGHT_TIME := 1.05
const ZOOM_IN := 1.55
const ZOOM_BACK_TIME := 0.5
const LETHAL_FRAME := 1
const FLYING_FRAME := 0

var player: CharacterBody2D
var camera: Camera2D
var overlay: ColorRect
var layer: CanvasLayer
var stage := 0
var real_left := 0.0
var flight_left := 0.0
var last_usec := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = get_parent()
	camera = get_viewport().get_camera_2d()
	layer = CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/screen_negative.gdshader")
	overlay.material = material
	layer.add_child(overlay)
	Sfx.play("death_crit")
	_pose(LETHAL_FRAME)
	player._apply_hitstop(FREEZE_TIME)
	player._camera_kick(0.7)
	real_left = FREEZE_TIME
	last_usec = Time.get_ticks_usec()

func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real_delta: float = minf((now - last_usec) / 1000000.0, 0.1)
	last_usec = now
	match stage:
		0:
			# Congelado: la cámara se acerca de golpe y el negativo late.
			real_left -= real_delta
			var progress := 1.0 - real_left / FREEZE_TIME
			_zoom(lerpf(1.0, ZOOM_IN, minf(progress * 5.0, 1.0)))
			overlay.material.set_shader_parameter("amount", 1.0 if progress < 0.7 else lerpf(1.0, 0.0, (progress - 0.7) / 0.3))
			_pose(LETHAL_FRAME)
			player.animated_sprite.rotation = 0.0
			if real_left <= 0.0:
				stage = 1
				flight_left = FLIGHT_TIME
				overlay.hide()
				_pose(FLYING_FRAME)
		1:
			# Vuela girando (la física es la de _update_death); la cámara vuelve poco a poco.
			flight_left -= delta
			_zoom(lerpf(ZOOM_IN, 1.0, clampf((FLIGHT_TIME - flight_left) / ZOOM_BACK_TIME, 0.0, 1.0)))
			_pose(FLYING_FRAME)
			if flight_left <= 0.0:
				_explode()
		_:
			pass

func _pose(index: int) -> void:
	var sprite: AnimatedSprite2D = player.animated_sprite
	if sprite.animation != player.ANIMATION_HURT:
		sprite.play(player.ANIMATION_HURT)
	sprite.pause()
	sprite.frame = index
	player._align_character_animation(player.ANIMATION_HURT)

func _zoom(value: float) -> void:
	if is_instance_valid(camera) and camera.get("cinematic_zoom") != null:
		camera.cinematic_zoom = value

func _explode() -> void:
	stage = 2
	_zoom(1.0)
	var level := player.get_parent()
	var center := player.global_position + Vector2(0, -26)
	Fx.jade_blast(level, player.global_position + Vector2(0, 20), 0.75)
	Fx.embers(level, player.global_position, Color(0.3, 0.95, 0.55), 1.6)
	Fx.jade_burst(level, center, 1.2)
	Sfx.play("grenade_blast", 2.0, 0.75)
	player._camera_kick(0.6)
	player.animated_sprite.hide()
	player.mane_emitter.emitting = false

# Si Viridy reaparece (checkpoint) antes de terminar, todo vuelve a la normalidad.
func cancel() -> void:
	_zoom(1.0)
	if is_instance_valid(player):
		player.animated_sprite.show()
	queue_free()

func _exit_tree() -> void:
	_zoom(1.0)
