extends Sprite2D

# Sprite de cuerpo (tools/art/enemy_art.py) sobre un enemigo hecho de polígonos: oculta las piezas que
# reemplaza y copia el tinte del polígono del cuerpo (golpe, aviso), sin tocar hitboxes ni animaciones.
const ART_SCALE := 1.0 / 3.0
const HIT_GLOW := 1.9

var body: Polygon2D
var base_color: Color
var pulse_source: Node2D
var pulse_rest := 0.0

func dress(visual: Node2D, body_poly: Polygon2D, art: String, replaced: Array, pulse_with: Node2D = null, feet_y := 0.0) -> Sprite2D:
	texture = load("res://assets/sprites/enemies/%s.png" % art)
	body = body_poly
	base_color = body_poly.color
	pulse_source = pulse_with
	scale = Vector2.ONE * ART_SCALE
	# Apoyado en los pies del enemigo, centrado en horizontal.
	offset = Vector2(0, -texture.get_height() * 0.5)
	position.y = feet_y
	for piece in replaced:
		piece.visible = false
	visual.add_child(self)
	visual.move_child(self, body_poly.get_index() + 1)
	return self

func _process(_delta: float) -> void:
	var tint: Color = body.color
	if tint.is_equal_approx(base_color):
		modulate = Color.WHITE
	else:
		modulate = Color(tint.r * HIT_GLOW, tint.g * HIT_GLOW, tint.b * HIT_GLOW)
	if pulse_source != null:
		# Sin alas articuladas: el cuerpo late con el aleteo.
		scale.y = ART_SCALE * (1.0 + 0.06 * sin(pulse_source.rotation * 4.0))
