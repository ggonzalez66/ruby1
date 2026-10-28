extends Node

# Velocidad base del juego. Con la cámara lenta activada (sin botón de mando por defecto, acción slow_motion) todo va a
# SLOW_SCALE; el hitstop y lo que antes devolvía la velocidad a 1.0 vuelven a esta base, así un golpe
# no apaga la cámara lenta.

signal changed(slow: bool)

const SLOW_SCALE := 0.3

var slow_motion := false

func base_scale() -> float:
	return SLOW_SCALE if slow_motion else 1.0

func set_slow_motion(on: bool) -> void:
	slow_motion = on
	Engine.time_scale = base_scale()
	changed.emit(slow_motion)

func toggle() -> void:
	set_slow_motion(not slow_motion)
