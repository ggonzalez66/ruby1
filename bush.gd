extends Node2D

# Bush del Gauntlet: Viridy se esconde dentro (stealth_director.gd). Se dibuja solo y se mece; al entrar o
# salir se agita y suelta hojas.

const WIDTH := 170.0
const HEIGHT := 92.0
const LEAF_DARK := Color(0.1, 0.27, 0.14)
const LEAF_MID := Color(0.17, 0.42, 0.18)
const LEAF_LIGHT := Color(0.33, 0.6, 0.24)
const SWAY_SPEED := 1.6
const SWAY := 0.03
const RUSTLE_TIME := 0.7

var clock := 0.0
var rustle_left := 0.0
var leaves: Array = []

func _ready() -> void:
	add_to_group(&"bushes")
	# Por delante de Viridy, para que quede tapada de verdad.
	z_index = 8
	var rng := RandomNumberGenerator.new()
	rng.seed = int(position.x)
	for layer in [[LEAF_DARK, 46, 24.0], [LEAF_MID, 54, 17.0], [LEAF_LIGHT, 26, 10.0]]:
		for index in range(layer[1]):
			var x := rng.randf_range(-0.5, 0.5)
			# Forma de cúpula: más baja hacia los lados.
			var top := HEIGHT * sqrt(maxf(1.0 - 4.0 * x * x, 0.0))
			leaves.append([Vector2(x * WIDTH, -rng.randf_range(0.1, 0.95) * top), layer[2] * rng.randf_range(0.7, 1.15), layer[0], rng.randf() * TAU])

func contains(point: Vector2) -> bool:
	var local := point - global_position
	return absf(local.x) <= WIDTH * 0.5 and local.y <= 8.0 and local.y >= -HEIGHT

func rustle() -> void:
	rustle_left = RUSTLE_TIME
	Fx.dust(get_parent(), global_position + Vector2(0, -HEIGHT * 0.6), Vector2.UP, 6, 0.9, 1.6)

func _process(delta: float) -> void:
	clock += delta
	rustle_left = maxf(rustle_left - delta, 0.0)
	var strength: float = SWAY + 0.09 * rustle_left / RUSTLE_TIME
	skew = sin(clock * (SWAY_SPEED + 16.0 * rustle_left)) * strength

func _draw() -> void:
	# Cúpula oscura de fondo: sin huecos por los que se vea a Viridy.
	var dome := PackedVector2Array()
	for index in range(17):
		var angle: float = PI + PI * index / 16.0
		dome.append(Vector2(cos(angle) * WIDTH * 0.5, sin(angle) * HEIGHT * 0.92))
	draw_colored_polygon(dome, LEAF_DARK.darkened(0.25))
	for leaf in leaves:
		var center: Vector2 = leaf[0]
		var size: float = leaf[1]
		var side := Vector2.from_angle(leaf[3]) * size
		var across := side.orthogonal() * 0.6
		draw_colored_polygon(PackedVector2Array([center + side, center + across, center - side, center - across]), leaf[2])
