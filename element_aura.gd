extends Node2D

# Marca de un enemigo con variante elemental: un anillo que late y chispas de su color.

var color := Color.WHITE
var clock := 0.0

func _ready() -> void:
	position = get_parent().impact_offset
	z_index = 3
	var sparks := CPUParticles2D.new()
	sparks.amount = 8
	sparks.lifetime = 0.6
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 26.0
	sparks.direction = Vector2.UP
	sparks.gravity = Vector2(0, -40)
	sparks.initial_velocity_min = 10.0
	sparks.initial_velocity_max = 40.0
	sparks.scale_amount_min = 1.5
	sparks.scale_amount_max = 3.0
	sparks.color = color
	add_child(sparks)

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func _draw() -> void:
	var radius: float = 34.0 + 2.0 * sin(clock * 5.0)
	draw_circle(Vector2.ZERO, radius, Color(color, 0.1))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(color, 0.8), 2.5, true)
