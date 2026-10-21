extends Area2D

# Meta de fusión: el Ruby1 (un rubí gigante al final de la etapa final) o el sol (al final de la
# Escalera al Cielo). Al tocarlo, Rengar flota lentamente hacia su centro, se encoge y se funde con él
# mientras la pantalla se va a blanco; al terminar aparece la pantalla de logros (con volver al menú
# principal).

@export_enum("ruby", "sun") var goal_style := "ruby"

const GEM_CENTER := Vector2(0, -170)
const GEM_HEIGHT := 210.0
const GEM_WIDTH := 130.0
const MERGE_TIME := 2.8
const FADE_DELAY := 1.0
const FADE_TIME := 2.4
const RUBY_DARK := Color(0.42, 0.02, 0.08)
const RUBY_MID := Color(0.82, 0.06, 0.16)
const RUBY_LIGHT := Color(1.0, 0.35, 0.42)
const RUBY_SHINE := Color(1.0, 0.85, 0.88)
const GLOW := Color(1.0, 0.18, 0.28)
const SUN_GLOW := Color(1.0, 0.72, 0.18)
const SUN_CORE := Color(1.0, 0.95, 0.7)
const SUN_MID := Color(1.0, 0.8, 0.3)
const SUN_EDGE := Color(1.0, 0.55, 0.12)

var time := 0.0
# 0..1: cuánto brilla de más durante la fusión.
var intensity := 0.0
var merging := false
var sparkles: Array = []

func _ready() -> void:
	z_index = 3
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	# Del suelo (pedestal) hasta la punta de la gema: se toca llegando caminando o saltando.
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(170, 300)
	shape.shape = rect
	shape.position = Vector2(0, -150)
	add_child(shape)
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	time += delta
	# Destellos que aparecen alrededor del rubí y se apagan.
	if randf() < delta * (4.0 + 12.0 * intensity):
		var angle: float = randf() * TAU
		sparkles.append({"position": GEM_CENTER + Vector2(cos(angle), sin(angle)) * randf_range(40.0, 120.0), "age": 0.0, "size": randf_range(6.0, 13.0)})
	for sparkle in sparkles.duplicate():
		sparkle["age"] += delta
		if sparkle["age"] > 0.7:
			sparkles.erase(sparkle)
	queue_redraw()

func _draw() -> void:
	var bob := Vector2(0, sin(time * 1.6) * 8.0)
	var center: Vector2 = GEM_CENTER + bob
	var pulse: float = 0.5 + 0.5 * sin(time * 2.4)
	# Rayos de luz girando detrás.
	for index in range(10):
		var angle: float = time * 0.35 + TAU * index / 10.0
		var length: float = 230.0 + 40.0 * sin(time * 1.3 + index)
		var spread: float = 0.09
		var ray := PackedVector2Array([center, center + Vector2(cos(angle - spread), sin(angle - spread)) * length, center + Vector2(cos(angle + spread), sin(angle + spread)) * length])
		draw_colored_polygon(ray, Color(_glow(), 0.07 + 0.08 * intensity))
	# Halo en capas que late.
	for layer in range(5):
		var radius: float = 70.0 + layer * 26.0 + 10.0 * pulse + 60.0 * intensity
		draw_circle(center, radius, Color(_glow(), (0.09 - layer * 0.014) * (1.0 + 2.0 * intensity)))
	if goal_style == "sun":
		_draw_sun(center, pulse)
	else:
		_draw_gem(center)
	for sparkle in sparkles:
		var life: float = sin(sparkle["age"] / 0.7 * PI)
		_draw_star(sparkle["position"] + bob, sparkle["size"] * life, Color(RUBY_SHINE if goal_style == "ruby" else SUN_CORE, life))
	if goal_style == "sun":
		return
	# Pedestal de piedra con musgo.
	draw_rect(Rect2(-70, -24, 140, 24), Color(0.3, 0.27, 0.22))
	draw_rect(Rect2(-56, -36, 112, 12), Color(0.38, 0.34, 0.28))
	draw_rect(Rect2(-70, -24, 140, 4), Color(0.35, 0.5, 0.25))

func _draw_gem(center: Vector2) -> void:
	# Rubí tallado: corona arriba (tabla y facetas) y pabellón en punta abajo.
	var h: float = GEM_HEIGHT
	var w: float = GEM_WIDTH * 0.5
	var crown_l := center + Vector2(-w, -h * 0.18)
	var crown_r := center + Vector2(w, -h * 0.18)
	var table_l := center + Vector2(-w * 0.5, -h * 0.42)
	var table_r := center + Vector2(w * 0.5, -h * 0.42)
	var girdle_l := center + Vector2(-w, -h * 0.1)
	var girdle_r := center + Vector2(w, -h * 0.1)
	var tip := center + Vector2(0, h * 0.5)
	var mid := center + Vector2(0, -h * 0.1)
	var shine: float = 0.15 + 0.25 * intensity
	# Pabellón: tres facetas (izquierda oscura, centro, derecha clara).
	draw_colored_polygon(PackedVector2Array([girdle_l, mid, tip]), RUBY_DARK.lerp(RUBY_SHINE, shine * 0.5))
	draw_colored_polygon(PackedVector2Array([mid, girdle_r, tip]), RUBY_MID.lerp(RUBY_SHINE, shine))
	draw_colored_polygon(PackedVector2Array([center + Vector2(-w * 0.35, -h * 0.1), center + Vector2(w * 0.35, -h * 0.1), tip]), RUBY_MID.lerp(RUBY_LIGHT, 0.4 + shine))
	# Corona: tabla y facetas laterales.
	draw_colored_polygon(PackedVector2Array([table_l, table_r, crown_r, girdle_r, girdle_l, crown_l]), RUBY_MID.lerp(RUBY_SHINE, shine))
	draw_colored_polygon(PackedVector2Array([table_l, table_r, center + Vector2(w * 0.35, -h * 0.18), center + Vector2(-w * 0.35, -h * 0.18)]), RUBY_LIGHT.lerp(RUBY_SHINE, shine + 0.2))
	draw_colored_polygon(PackedVector2Array([table_l, crown_l, girdle_l, center + Vector2(-w * 0.35, -h * 0.18)]), RUBY_DARK.lerp(RUBY_MID, 0.5))
	# Contorno y aristas.
	var outline := PackedVector2Array([table_l, table_r, crown_r, girdle_r, tip, girdle_l, crown_l, table_l])
	draw_polyline(outline, Color(0.2, 0.0, 0.04), 4.0, true)
	draw_polyline(PackedVector2Array([girdle_l, girdle_r]), Color(RUBY_SHINE, 0.5), 1.5, true)
	draw_polyline(PackedVector2Array([mid, tip]), Color(RUBY_SHINE, 0.35), 1.5, true)
	# Destello que recorre la tabla de vez en cuando.
	var glint: float = fmod(time, 3.2) / 0.6
	if glint < 1.0:
		var x: float = lerp(-w, w, glint)
		draw_line(center + Vector2(x - 10, -h * 0.42), center + Vector2(x + 18, -h * 0.1), Color(1, 1, 1, 0.55 * sin(glint * PI)), 6.0, true)

func _glow() -> Color:
	return SUN_GLOW if goal_style == "sun" else GLOW

func _draw_sun(center: Vector2, pulse: float) -> void:
	# Sol gigante y sereno: corona de puntas que gira, discos en capas y un brillo que late.
	var corona := PackedVector2Array()
	for index in range(32):
		var angle: float = -time * 0.25 + TAU * index / 32.0
		var radius: float = (118.0 if index % 2 == 0 else 96.0) + 6.0 * pulse
		corona.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(corona, SUN_EDGE.lerp(SUN_CORE, 0.3 * intensity))
	draw_circle(center, 94.0, SUN_EDGE)
	draw_circle(center, 84.0, SUN_MID.lerp(SUN_CORE, 0.4 * intensity))
	draw_circle(center, 60.0 + 4.0 * pulse, SUN_CORE)
	draw_circle(center + Vector2(-26, -28), 18.0, Color(1, 1, 1, 0.35 + 0.2 * intensity))

func _draw_star(at: Vector2, size: float, color: Color) -> void:
	if size <= 0.5:
		return
	var points := PackedVector2Array()
	for index in range(8):
		var radius: float = size if index % 2 == 0 else size * 0.25
		var angle: float = -PI * 0.5 + PI * index / 4.0
		points.append(at + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, color)

# ---------- Fusión

func _on_body_entered(body: Node) -> void:
	if merging or not body.is_in_group(&"player") or body.dead:
		return
	_merge(body)

func _merge(player: Node2D) -> void:
	merging = true
	RunSession.finish_stage()
	Stats.add("sun_reached" if goal_style == "sun" else "ruby_reached")
	player.begin_merge()
	var sprite: Node2D = player.animated_sprite
	var tween := create_tween().set_parallel(true)
	tween.tween_property(player, "global_position", global_position + GEM_CENTER + Vector2(0, 14), MERGE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "scale", sprite.scale * 0.12, MERGE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var merge_tint := Color(2.2, 1.9, 0.9, 0.0) if goal_style == "sun" else Color(2.2, 0.55, 0.6, 0.0)
	tween.tween_property(sprite, "modulate", merge_tint, MERGE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "intensity", 1.0, MERGE_TIME)
	# La pantalla se funde a blanco rosado.
	var layer := CanvasLayer.new()
	layer.layer = 25
	add_child(layer)
	var fade := ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.color = Color(1.0, 0.97, 0.85, 0.0) if goal_style == "sun" else Color(1.0, 0.9, 0.92, 0.0)
	layer.add_child(fade)
	tween.tween_property(fade, "color:a", 1.0, FADE_TIME).set_delay(FADE_DELAY)
	tween.chain().tween_callback(_finish.bind(layer))

func _finish(layer: CanvasLayer) -> void:
	var screen := get_tree().get_first_node_in_group(&"demo_complete")
	if screen:
		screen.show_results()
	# El blanco se desvanece por detrás de la pantalla de logros.
	var tween := layer.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(layer.get_child(0), "color:a", 0.0, 0.8)
