extends AudioStreamPlayer

# Autoload "Music": la música sigue sonando aunque cambie la escena. En el menú principal empieza
# INFUSE (si no suena nada) y continúa al empezar la partida; al terminar cada canción suena otra al
# azar entre todas las de assets/sounds/music (INFUSE incluida), sin repetir la que acaba de sonar.
# Para añadir canciones basta con dejar el .mp3/.ogg en la carpeta.

const MUSIC_DIR := "res://assets/sounds/music"
const MENU_TRACK := "INFUSE.mp3"

var tracks: Array[String] = []
var current := ""

func _ready() -> void:
	bus = &"Music"
	volume_db = -6.0
	process_mode = Node.PROCESS_MODE_ALWAYS
	tracks = _find_tracks()
	finished.connect(_play_next)

# Menú principal: INFUSE, salvo que ya suene algo (al volver al menú la música sigue).
func play_menu_music() -> void:
	if playing:
		return
	_play(MENU_TRACK if MENU_TRACK in tracks else _random_track())

# Partida: sigue lo que suene; si no suena nada (p. ej. se abrió el nivel directamente), una al azar.
func play_game_music() -> void:
	if playing:
		return
	_play(_random_track())

func _play_next() -> void:
	_play(_random_track())

func _random_track() -> String:
	if tracks.is_empty():
		return ""
	var options := tracks.filter(func(track): return track != current)
	if options.is_empty():
		options = tracks
	return options[randi() % options.size()]

func _play(track: String) -> void:
	if track == "":
		return
	var music := load(MUSIC_DIR.path_join(track)) as AudioStream
	if music == null:
		return
	# Sin bucle: al terminar salta "finished" y suena otra.
	if "loop" in music:
		music.loop = false
	current = track
	stream = music
	play()

func _find_tracks() -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(MUSIC_DIR)
	if dir == null:
		return found
	for file in dir.get_files():
		# En el juego exportado solo quedan los .import; el recurso se carga igual por la ruta original.
		var name := file.trim_suffix(".import").trim_suffix(".remap")
		if name.get_extension() in ["mp3", "ogg", "wav"] and not name in found:
			found.append(name)
	found.sort()
	return found
