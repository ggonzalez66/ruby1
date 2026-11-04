extends Area2D

# Géiser de lava del mundo del sol: burbujea avisando y lanza una columna de fuego (PixelFX flame-pillar)
# que devuelve al checkpoint a quien la toque. Se repite cada `period` segundos.
# La zona de daño sigue a la animación: solo está activa mientras la columna de fuego se ve en pie
# (los primeros HIT_FRAMES fotogramas de la hoja; después es humo y brasas, que ya no tocan) y mide lo
# que mide la llama dibujada.

@export var period := 3.2
@export var phase := 0.0
@export var warn_time := 0.8
@export var height := 300.0

const WARN := Color(1.0, 0.75, 0.25)
const SHEET := "flame_pillar"
const SPEED := 1.8
# Fotogramas de la hoja con la columna en pie (de 24 con llama; los dos últimos ya se deshacen).
const HIT_FRAMES := 22
# Altura de la hoja a la que se dibuja: 230 px de llama a escala 1.
const SHEET_HEIGHT := 230.0
# Punta de la llama dentro del fotograma y ancho de la columna (píxeles de la hoja).
const FLAME_TOP := 34.0
const FLAME_WIDTH := 28.0

var time := 0.0
var erupting := false
var burst_left := 0.0
var pillar: AnimatedSprite2D
var shape: CollisionShape2D

func _ready() -> void:
	add_to_group(&"lava")
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	z_index = 5
	time = phase
	var scale_factor := height / SHEET_HEIGHT
	var pivot_y: float = PixelFx.DATA.SHEETS[SHEET]["pivot"].y
	var flame_height := (pivot_y - FLAME_TOP) * scale_factor
	shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(FLAME_WIDTH * scale_factor, flame_height)
	shape.shape = rect
	shape.position = Vector2(0, -flame_height * 0.5)
	shape.disabled = true
	add_child(shape)

# Lo que dura la columna en pie, en segundos (igual que la animación).
func burst_time() -> float:
	return HIT_FRAMES / (float(PixelFx.DATA.SHEETS[SHEET]["fps"]) * SPEED)

func _physics_process(delta: float) -> void:
	var before := fposmod(time, period)
	time += delta
	var now := fposmod(time, period)
	if before < warn_time and now >= warn_time:
		erupting = true
		burst_left = burst_time()
		shape.disabled = false
		if is_visible_in_tree() and get_viewport_rect().grow(400.0).has_point(get_global_transform_with_canvas().origin):
			pillar = PixelFx.play(get_parent(), SHEET, global_position, height / SHEET_HEIGHT, [], {"speed": SPEED, "z": 5})
			Sfx.play("fire_breath", -6.0, 0.8)
	if erupting:
		burst_left -= delta
		# Con la animación a la vista manda su fotograma; fuera de pantalla, el mismo tiempo.
		var standing: bool = pillar.frame < HIT_FRAMES if is_instance_valid(pillar) else burst_left > 0.0
		if not standing or now < before:
			erupting = false
			shape.disabled = true
			pillar = null
	if erupting:
		for body in get_overlapping_bodies():
			if body.has_method("return_to_checkpoint"):
				body.return_to_checkpoint(0)
	queue_redraw()

func is_warning() -> bool:
	return fposmod(time, period) < warn_time

func _draw() -> void:
	# Boca del géiser y burbujeo de aviso.
	draw_rect(Rect2(-30, -6, 60, 8), Color(0.5, 0.12, 0.04))
	draw_rect(Rect2(-22, -10, 44, 6), Color(1.0, 0.45, 0.1))
	if is_warning():
		var t := fposmod(time, period) / warn_time
		for index in range(4):
			var y := -10.0 - fposmod(t * 60.0 + index * 15.0, 60.0)
			draw_rect(Rect2(-14 + index * 9, y, 4, 4), Color(WARN, 1.0 - t * 0.5))
