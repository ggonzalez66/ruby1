extends CanvasLayer

# Transición entre escenas (autoload SceneFade): la pantalla arde desde los bordes en fuego jade hasta
# quedar negra (hoja "burn_away" de PixelFX), se cambia la escena y el negro se abre desde el centro.
# Corre en tiempo real (ni la pausa, ni la cámara lenta, ni el hitstop la frenan) y deja el juego en
# pausa mientras cubre la pantalla. Sin pantalla (pruebas headless) cambia la escena al instante.

signal covered

const SHEET := "burn_away"
const FPS := 30.0
# Fotogramas de la hoja: hasta COVER_END arde hasta cubrirlo todo; desde REVEAL_START se abre.
const COVER_END := 18
const REVEAL_START := 23
const JADE: Array[Color] = [Color(0.0, 0.0, 0.0), Color(0.16, 0.72, 0.4), Color(0.9, 1.0, 0.82)]

var sprite: AnimatedSprite2D
var busy := false
var frame_time := 0.0
var target_frame := 0
var playing := false
var last_usec := 0

func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	sprite = PixelFx.play(self, SHEET, Vector2.ZERO, 1.0, JADE, {"loop": true, "z": 0})
	if sprite != null:
		sprite.stop()
		sprite.centered = false
		sprite.offset = Vector2.ZERO
		sprite.hide()

func available() -> bool:
	return sprite != null and DisplayServer.get_name() != "headless"

func go(path: String) -> void:
	if busy:
		return
	if not available():
		get_tree().paused = false
		Engine.time_scale = TimeControl.base_scale()
		get_tree().change_scene_to_file(path)
		return
	await cover()
	get_tree().paused = false
	Engine.time_scale = TimeControl.base_scale()
	get_tree().change_scene_to_file(path)
	reveal()

# Arde hasta cubrir la pantalla; el juego queda en pausa debajo.
func cover() -> void:
	busy = true
	get_tree().paused = true
	_fit()
	sprite.show()
	sprite.frame = 0
	await _play_to(COVER_END)
	covered.emit()

func reveal() -> void:
	sprite.frame = REVEAL_START
	await _play_to(sprite.sprite_frames.get_frame_count(&"default") - 1)
	sprite.hide()
	busy = false

func _play_to(last: int) -> void:
	target_frame = last
	frame_time = 0.0
	last_usec = Time.get_ticks_usec()
	playing = true
	while playing:
		await get_tree().process_frame

func _process(_delta: float) -> void:
	if not playing:
		return
	var now := Time.get_ticks_usec()
	frame_time += minf((now - last_usec) / 1000000.0, 0.05)
	last_usec = now
	_fit()
	while frame_time >= 1.0 / FPS:
		frame_time -= 1.0 / FPS
		if sprite.frame >= target_frame:
			playing = false
			return
		sprite.frame += 1

func _fit() -> void:
	# La hoja es de 320x180: se escala para cubrir toda la ventana, centrada.
	var view := get_viewport().get_visible_rect().size
	var frame: Vector2 = PixelFx.DATA.SHEETS[SHEET]["frame"]
	var factor := maxf(view.x / frame.x, view.y / frame.y)
	sprite.scale = Vector2.ONE * factor
	sprite.position = (view - frame * factor) * 0.5
