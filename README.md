# Ruby1

Juego de acción y plataformas 2D para Godot 4.2.2. Abrir `project.godot` o ejecutar `godot --path .`.

## Modos

- **Subir Torre:** cuatro etapas; la última termina en la cámara elevada del Ruby, accesible por una chimenea con espinas alternadas.
- **Gauntlet:** oleadas de enemigos y guardianes, con 2 segundos de preparación al aparecer. El portal de terminar pide confirmación; «Seguir jugando» tiene el foco por defecto y el reloj se pausa mientras decides.
- **Escalera al Cielo:** recorrido de plataformas y rebotes.

Cada escenario empieza con **Ready 3.00**, dos avisos de segundos y **GO!**. El mundo permanece detenido durante la cuenta atrás; el cronómetro empieza con GO y excluye las pausas. Los tiempos de etapa usan segundos reales de juego activo, también con cámara lenta o hitstop.

## Movimiento y estilo

Los bunnyhops encadenados suman **60 px/s por salto**, ajustable con `bunnyhop_speed_gain` en `movimiento.gd`. El extra se pierde al terminar la ventana de encadenamiento en el suelo o al reaparecer. Tras un backflip, mantener correr y la dirección contraria enlaza el freno con la carrera hacia ese lado.

El medidor de Ferocity muestra el tiempo aéreo y suma **10 puntos de estilo por segundo** mientras aumenta. El contacto con paredes, enganches y agarres lo pausa; aterrizar cierra la cuenta y el siguiente despegue inicia otra. La ganancia mantiene el límite de rango de las acrobacias: S; por encima sigue llenando el rango actual.

## Ejecuciones Ruby

Todos los enemigos mecánicos llevan un rombo Ruby rojo dentro del cuerpo. El borde y el halo destellan cuando está **open**. El heavy de suelo, el heavy aéreo y el uppercut ejecutan, y el enemigo debe estar open antes del impacto: el golpe que lo deja con poca vida no ejecuta automáticamente. Los golpes ordinarios pueden seguir matando a los enemigos normales.

- **Normales:** un parry los inmoviliza y abre durante 2 segundos; al 30 % de vida o menos permanecen open, pero siguen atacando. Los voladores también pueden ejecutarse y dan un último rebote. El sol no lleva este sistema.
- **Guardianes:** la postura empieza en 100 y cada parry de un ataque distinto le quita un tercio, sin RNG. Las devoluciones perfectas cuentan para el tirador original; una ráfaga o un giro no se contabilizan varias veces. Romper postura abre una ventana de 2,5 segundos. Aprovecharla o perderla reinicia la postura.
- **Crítico:** contra un guardián open, el heavy daña el 22 % de su vida máxima y agrieta el Ruby sin romperlo. Un destello, una onda partida y chorros de esencia roja marcan el impacto, con un sonido más agudo que la rotura final. Si llega a cero, queda inmóvil y open hasta recibir otro heavy. La derrota, los portales y el cronómetro esperan a esa ejecución final.
- **Mordida pesada:** Viridy se transforma en una cabeza leonina líquida verde con las fauces abiertas. En aire se orienta según la caída; el uppercut es la mordida ascendente y también puede capturar un Ruby open, incluso sin cuchillo. Conserva los daños, tiempos y trayectorias ordinarios. Al aterrizar el heavy cierra la mordida y conserva el deslizamiento con su estela de energía.
- **Captura:** dura 0,38 segundos; Viridy es invulnerable, pero el mundo sigue activo. En suelo la bestia alargada cierra las fauces y masca el Ruby alternando dos frames, con la boca alineada al núcleo. Al liberarlo avanza un poco manteniendo la forma durante 0,16 s. En aire se enrolla como un ouroboros que casi se muerde la cola, compartido con el screw attack, y gira sobre su propio centro en el Ruby. Sin carrera sale con el flip normal. En carrera sale hacia delante como bestia alargada, hace un flip normal en el punto más alto (con una pausa vertical de 0,22 s) y cae en aerial stall, recuperando el salto aéreo y conservando la carrera y el impulso acumulado. Se puede anticipar el siguiente ataque o salto durante la captura y encadenar acciones al salir.
- **Energía:** una ejecución normal cura 12, un crítico cura 8 y el remate de un guardián cura 25. Sustituye la curación del riposte; los ataques normales conservan los beneficios de rango SS. Romper un Ruby causa una explosión de radio 125 que daña 1 y empuja a los enemigos cercanos, respetando las paredes.

Los tiempos, impulso de salida y curaciones se ajustan con las propiedades `execution_*`, `critical_heal` y `boss_execution_heal` en `movimiento.gd`; las reglas del núcleo están en `ruby_core.gd`. Las hojas anteriores se conservan. `viridy_liquid_beast_v2.png` incluye las poses abiertas y cerradas; `viridy_liquid_ouroboros.png` contiene las cuatro fases del giro actual. Su procedencia y prompts están en `docs/liquid_beast_art.md`, `docs/liquid_beast_v2_art.md` y `docs/liquid_ouroboros_art.md`.

## Mejores tiempos y fantasma

**Mejores tiempos**, en el menú principal, muestra diez marcas por etapa. También está disponible desde los resultados de la torre. Cada etapa guarda su propio ranking en `user://records_v1/`.

Al vencer al último guardián o tocar el Ruby se detiene el cronómetro. Si es una mejor marca, se guarda una trayectoria con animación a 30 muestras por segundo. Ese fantasma aparece automáticamente en el siguiente intento de la misma etapa; no tiene colisiones. Las marcas peores actualizan el Top 10 sin reemplazarlo.

## Herramientas y pruebas

- `python3 tools/generate_stage4.py`: regenera la etapa final desde su fuente.
- `python3 tools/generate_sfx.py ready countdown_tick go`: regenera los sonidos de salida.
- `bash tests/run_tests.sh`: integración y herramientas Python (requiere Pillow). Usa datos de usuario temporales para conservar los récords y ajustes reales. La suite `test_speedrun.gd` comprueba también la cuenta atrás y el recorrido físico de la chimenea.

### Movimiento y Escalera al cielo

El HUD muestra velocidad horizontal y bonus gradual de estilo por alta velocidad. El screw attack lanza con impulso y, manteniendo correr, permite iniciar bunnyhops acelerados. El uppercut enlaza subida líquida, flip normal en el ápice y aerial stall. Dash y aterrizaje pesado tienen formas líquidas propias; caminar y correr usan ciclos ampliados.

Escalera al cielo tiene 18 fosos progresivos de 3600 a 6150 px, cadenas largas de voladores y checkpoints. Su Top 10 y fantasma del mejor tiempo se consultan en Mejores tiempos. El reloj se detiene al llegar al sol; caer conserva el tiempo transcurrido.

Arte, prompts y afinación del audio: [documentación de movimiento](docs/movement_polish_art.md).
