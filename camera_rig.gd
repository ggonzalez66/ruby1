extends Camera2D

# Cámara de Rengar con efectos sutiles que crecen con la Ferocity:
# - Mira un poco hacia donde corre y hacia abajo al caer rápido.
# - Se aleja un poco con la velocidad (y algo más en rangos altos).
# - Temblor por "trauma" (golpes, daño) con un leve giro; más fuerte cuanto más estilo.
# - Golpe de zoom en los impactos fuertes y al subir de rango.
# - Viñeta del color del rango; late en estado imparable y destella en rojo al recibir daño.
# Los efectos usan el tiempo real para que el temblor se note también durante el hitstop.

@export var look_ahead := 0.2
@export var look_ahead_max := 150.0
@export var fall_look_down := 70.0
@export var speed_zoom_out := 0.06
@export var rank_zoom_out := 0.012
@export var shake_offset := 16.0
@export var shake_angle := 0.025

var base_zoom := Vector2.ONE
var smooth_zoom := Vector2.ONE
var trauma := 0.0
var punch_amount := 0.0
var look := Vector2.ZERO
var noise := FastNoiseLite.new()
var noise_time := 0.0
var hurt_flash := 0.0
var rank_flash := 0.0
var last_health := -1
var vignette: ColorRect
var vignette_material: ShaderMaterial

const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0, 0.6, 0.2, 1.0);
uniform float intensity = 0.0;
void fragment() {
	vec2 centered = (UV - 0.5) * vec2(1.0, 0.8);
	float edge = smoothstep(0.32, 0.78, length(centered));
	COLOR = vec4(tint.rgb, edge * intensity);
}
"""

func _ready() -> void:
	base_zoom = zoom
	smooth_zoom = zoom
	ignore_rotation = false
	noise.seed = randi()
	noise.frequency = 0.9
	_build_vignette()
	Ferocity.rank_changed.connect(_on_rank_changed)
	var player := get_parent()
	if player.has_signal("health_changed"):
		player.health_changed.connect(_on_health_changed)

func _build_vignette() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	vignette = ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = VIGNETTE_SHADER
	vignette_material = ShaderMaterial.new()
	vignette_material.shader = shader
	vignette.material = vignette_material
	layer.add_child(vignette)

func add_trauma(amount: float) -> void:
	trauma = clamp(trauma + amount, 0.0, 1.0)

func punch(amount: float) -> void:
	punch_amount = max(punch_amount, amount)

func _process(delta: float) -> void:
	var real_delta: float = delta / max(Engine.time_scale, 0.01)
	var player := get_parent() as CharacterBody2D
	var rank: int = Ferocity.rank
	var rank_ratio: float = rank / 6.0

	# Mirada adelantada.
	var target_look := Vector2.ZERO
	if player:
		target_look.x = clamp(player.velocity.x * look_ahead, -look_ahead_max, look_ahead_max)
		if player.velocity.y > 450.0:
			target_look.y = fall_look_down * clamp((player.velocity.y - 450.0) / 400.0, 0.0, 1.0)
	look = look.lerp(target_look, clamp(2.5 * real_delta, 0.0, 1.0))

	# Zoom: se aleja con la velocidad y el rango; el golpe de zoom acerca un instante.
	var speed_ratio: float = clamp(abs(player.velocity.x) / 560.0, 0.0, 1.2) if player else 0.0
	var breathe: float = 0.004 * sin(Time.get_ticks_msec() / 400.0) if Ferocity.is_unstoppable() else 0.0
	var zoom_factor: float = 1.0 - speed_zoom_out * speed_ratio - rank_zoom_out * rank + breathe
	punch_amount = move_toward(punch_amount, 0.0, real_delta * 0.35)
	smooth_zoom = smooth_zoom.lerp(base_zoom * zoom_factor, clamp(3.0 * real_delta, 0.0, 1.0))
	zoom = smooth_zoom * (1.0 + punch_amount)

	# Temblor (cuadrático con el trauma), más fuerte con más estilo.
	trauma = max(trauma - real_delta * 1.6, 0.0)
	noise_time += real_delta * 40.0
	var shake: float = trauma * trauma * (1.0 + 0.15 * rank)
	offset = look + Vector2(noise.get_noise_2d(noise_time, 0.0), noise.get_noise_2d(0.0, noise_time)) * shake_offset * shake
	rotation = shake_angle * shake * noise.get_noise_2d(noise_time, 77.0)

	# Viñeta.
	hurt_flash = max(hurt_flash - real_delta * 2.5, 0.0)
	rank_flash = max(rank_flash - real_delta * 2.0, 0.0)
	var pulse: float = 0.08 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 160.0)) if Ferocity.is_unstoppable() else 0.0
	var tint: Color = Ferocity.rank_info()["color"]
	var intensity: float = 0.08 + 0.3 * rank_ratio + pulse + 0.25 * rank_flash if Ferocity.points > 1.0 else 0.0
	if hurt_flash > 0.0:
		tint = tint.lerp(Color(0.9, 0.05, 0.05), clamp(hurt_flash * 1.5, 0.0, 1.0))
		intensity = max(intensity, 0.55 * hurt_flash)
	vignette_material.set_shader_parameter("tint", tint)
	vignette_material.set_shader_parameter("intensity", intensity)

func _on_rank_changed(rank: int, previous: int) -> void:
	if rank > previous:
		rank_flash = 1.0
		punch(0.025 + 0.006 * rank)

func _on_health_changed(current: int, _maximum: int) -> void:
	if last_health >= 0 and current < last_health:
		hurt_flash = 1.0
	last_health = current
