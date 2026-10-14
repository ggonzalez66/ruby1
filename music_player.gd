extends AudioStreamPlayer

# Música de la partida: al empezar (abrir el juego o "Reiniciar todo") suena una canción al azar
# de assets/sounds/music y, al terminar, pasa a otra distinta. Reaparecer con R no la toca.
# Para añadir canciones basta con dejar el .mp3/.ogg en la carpeta.

const MUSIC_DIR := "res://assets/sounds/music"

var tracks: Array[String] = []
var current := ""

func _ready() -> void:
	tracks = _find_tracks()
	finished.connect(_play_next)
	# La última canción se recuerda en el autoload para que "Reiniciar todo" no repita la misma.
	_play_next()

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

func _play_next() -> void:
	if tracks.is_empty():
		return
	var previous: String = current if current != "" else str(Stats.get_meta(&"last_track", ""))
	var options := tracks.filter(func(track): return track != previous)
	if options.is_empty():
		options = tracks
	current = options[randi() % options.size()]
	Stats.set_meta(&"last_track", current)
	var music := load(MUSIC_DIR.path_join(current)) as AudioStream
	if music == null:
		return
	# Sin bucle: al terminar salta "finished" y suena otra.
	if "loop" in music:
		music.loop = false
	stream = music
	play()
