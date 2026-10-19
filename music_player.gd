extends AudioStreamPlayer

# Nodo de música de cada nivel: ya no suena por sí mismo. La música la lleva el autoload Music (music.gd)
# para que siga sin cortes entre el menú y la partida; este nodo solo le pide que haya música.

func _ready() -> void:
	Music.play_game_music()
	queue_free()
