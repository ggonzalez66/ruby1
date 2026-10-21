# Ruby1

Juego de acción y plataformas 2D para Godot 4.2.2. Abrir `project.godot` o ejecutar `godot --path .`.

## Modos

- **Subir Torre:** cuatro etapas; la última termina en la cámara elevada del Ruby, accesible por una chimenea con espinas alternadas.
- **Gauntlet:** oleadas de enemigos y guardianes.
- **Escalera al Cielo:** recorrido de plataformas y rebotes.

Cada escenario empieza con **Ready 3.00**, dos avisos de segundos y **GO!**. El mundo permanece detenido durante la cuenta atrás; el cronómetro empieza con GO y excluye las pausas. Los tiempos de etapa usan segundos reales de juego activo, también con cámara lenta o hitstop.

## Movimiento y estilo

Los bunnyhops encadenados suman **60 px/s por salto**, ajustable con `bunnyhop_speed_gain` en `movimiento.gd`. El extra se pierde al terminar la ventana de encadenamiento en el suelo o al reaparecer. Tras un backflip, mantener correr y la dirección contraria enlaza el freno con la carrera hacia ese lado.

El medidor de Ferocity muestra el tiempo aéreo y suma **10 puntos de estilo por segundo** mientras aumenta. El contacto con paredes, enganches y agarres lo pausa; aterrizar cierra la cuenta y el siguiente despegue inicia otra. La ganancia mantiene el límite de rango de las acrobacias: S; por encima sigue llenando el rango actual.

## Mejores tiempos y fantasma

**Mejores tiempos**, en el menú principal, muestra diez marcas por etapa. También está disponible desde los resultados de la torre. Cada etapa guarda su propio ranking en `user://records_v1/`.

Al vencer al último guardián o tocar el Ruby se detiene el cronómetro. Si es una mejor marca, se guarda una trayectoria con animación a 30 muestras por segundo. Ese fantasma aparece automáticamente en el siguiente intento de la misma etapa; no tiene colisiones. Las marcas peores actualizan el Top 10 sin reemplazarlo.

## Herramientas y pruebas

- `python3 tools/generate_stage4.py`: regenera la etapa final desde su fuente.
- `python3 tools/generate_sfx.py ready countdown_tick go`: regenera los sonidos de salida.
- `bash tests/run_tests.sh`: integración y herramientas Python (requiere Pillow). Usa datos de usuario temporales para conservar los récords y ajustes reales. La suite `test_speedrun.gd` comprueba también la cuenta atrás y el recorrido físico de la chimenea.
