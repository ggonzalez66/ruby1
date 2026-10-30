extends Node2D

# Cuerpo serpentino de la bestia: una cadena que sigue a la cabeza (follow-the-leader), dibujada como una
# lengua de fuego jade que se afina hacia la cola. Solo sale en las ejecuciones: las cabezas de los pesados y la
# bestia de Wrath ya traen su propia llama dibujada. La cabeza manda y el cuerpo recorre su camino.
const SEGMENTS := 34
const SEGMENT_LENGTH := 4.5
const HEAD_WIDTH := 30.0
const PALETTE := [Color(0.04, 0.22, 0.13), Color(0.12, 0.62, 0.36), Color(0.62, 1.0, 0.62)]

var player: CharacterBody2D
var points := PackedVector2Array()
var clock := 0.0
var length_ratio := 0.0
var embers: CPUParticles2D

func _ready() -> void:
	player = get_parent()
	top_level = true
	z_index = -1
	embers = CPUParticles2D.new()
	embers.amount = 36
	embers.lifetime = 0.55
	embers.local_coords = false
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	embers.emission_sphere_radius = 10.0
	embers.gravity = Vector2(0, -60)
	embers.spread = 50.0
	embers.initial_velocity_min = 20.0
	embers.initial_velocity_max = 60.0
	embers.scale_amount_min = 1.5
	embers.scale_amount_max = 3.5
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	ramp.colors = PackedColorArray([Color(PALETTE[2], 0.95), Color(PALETTE[1], 0.75), Color(PALETTE[0], 0.0)])
	embers.color_ramp = ramp
	embers.emitting = false
	add_child(embers)

func head_anchor() -> Vector2:
	# Detrás de la nuca: la cabeza tapa el arranque de la llama.
	var sprite: AnimatedSprite2D = player.animated_sprite
	var back := Vector2(-player.facing * 22.0, 4.0).rotated(sprite.rotation)
	return sprite.global_position + back

func _physics_process(delta: float) -> void:
	clock += delta
	var active: bool = not player.dead and player.visible and player.execution_core != null and not player.wrath.uses_beast()
	visible = active
	embers.emitting = active
	if not active:
		points.clear()
		return
	var head := head_anchor()
	if points.size() != SEGMENTS:
		points.resize(SEGMENTS)
		for i in SEGMENTS:
			points[i] = head
	points[0] = head
	for i in range(1, SEGMENTS):
		var offset := points[i] - points[i - 1]
		if offset.length() > SEGMENT_LENGTH:
			points[i] = points[i - 1] + offset.normalized() * SEGMENT_LENGTH
		# Sin velocidad la llama se recoge hacia la cabeza.
		points[i] = points[i].lerp(points[i - 1], 0.04)
	var speed: float = player.velocity.length()
	length_ratio = lerpf(length_ratio, clampf(0.35 + speed / player.sprint_speed, 0.35, 1.0), 0.15)
	embers.global_position = head
	embers.direction = -player.velocity.normalized() if speed > 30.0 else Vector2.UP
	queue_redraw()

func _draw() -> void:
	if points.size() < 2:
		return
	var count := maxi(3, roundi(SEGMENTS * length_ratio))
	for layer in range(3):
		for i in range(count - 1, -1, -1):
			var t := float(i) / float(count - 1)
			var a: Vector2 = points[maxi(i - 1, 0)]
			var b: Vector2 = points[mini(i + 1, count - 1)]
			var tangent := (b - a).normalized() if a != b else Vector2(-player.facing, 0)
			# Ondulación de llama que avanza hacia la cola.
			var sway := sin(clock * 14.0 - t * 7.0) * 4.0 * t
			var flicker := sin(clock * 31.0 + i * 2.3) * 0.5 + 0.5
			var radius := HEAD_WIDTH * 0.5 * pow(1.0 - t, 0.8) * (0.8 + 0.3 * flicker) * (1.0 - layer * 0.3)
			if radius < 0.8:
				continue
			# Las llamas suben: cada segmento se desplaza un poco hacia arriba según su edad.
			var rise := Vector2(0, -6.0 * t * flicker)
			var color: Color = PALETTE[layer]
			color.a = (0.42 + layer * 0.18) * (1.0 - t * 0.7)
			draw_circle(points[i] - global_position + tangent.orthogonal() * sway + rise, radius, color)
	# Lenguas sueltas que se desprenden de la melena.
	for k in range(4):
		var index := clampi(int(count * (0.25 + 0.18 * k)), 1, count - 1)
		var base: Vector2 = points[index] - global_position
		var flick := Vector2(-player.facing * 10.0, -8.0 - 6.0 * sin(clock * 17.0 + k * 1.9))
		draw_colored_polygon(PackedVector2Array([base + Vector2(0, -4), base + Vector2(0, 4), base + flick]), Color(PALETTE[2], 0.5))
