# Ruby1

Juego de acción y plataformas 2D para Godot 4.2.2. Abrir `project.godot` o ejecutar `godot --path .`.

## Visión del juego e historia

Ruby1 se desarrollará como un **roguelike de acción y plataformas 2D**, con combate frenético, movilidad, medidor de estilo y expediciones desde el santuario del Árbol Madre hasta la Ciudad Negra. Cada run ofrece rutas por un mapa hexagonal, armas, mejoras, encuentros y territorios variables. Su desenlace permite conservar el poder del León Rojo o arriesgar el regreso al origen para devolverle la vida a la naturaleza.

La [visión del juego, historia completa, estructura de una run y dos finales](docs/vision_del_juego.md) recoge las decisiones narrativas y de diseño. Describe el juego objetivo; los modos y sistemas documentados a continuación corresponden al prototipo actual.

## Modos

- **Subir Torre:** cuatro etapas; la última termina en la cámara elevada del Ruby, accesible por una chimenea con espinas alternadas.
- **Gauntlet:** oleadas de enemigos y guardianes, con 2 segundos de preparación al aparecer. El portal de terminar pide confirmación; «Seguir jugando» tiene el foco por defecto y el reloj se pausa mientras decides.
- **Escalera al Cielo:** recorrido de plataformas y rebotes.
- **Level Testing:** selector de las etapas en desarrollo para el roguelike. Su primera escena es el **Santuario**, con el Árbol Madre, una laguna y rutas entre raíces, rocas y ramas para explorar la movilidad. Desde Pausa se puede reiniciar o volver al selector. [Diseño, capturas y validación](docs/sanctuary/README.md).

Cada escenario empieza con **Ready 0.00**, avanza hasta **1.00** en un segundo y muestra **GO!**, con sonidos de preparación, pulso intermedio y salida. El mundo permanece detenido durante esa preparación; el cronómetro empieza con GO y excluye las pausas. Los tiempos de etapa usan segundos reales de juego activo, también con cámara lenta o hitstop.

## Movimiento y estilo

Los bunnyhops encadenados suman **60 px/s por salto**, ajustable con `bunnyhop_speed_gain` en `movimiento.gd`. El extra se pierde al terminar la ventana de encadenamiento en el suelo o al reaparecer. Tras un backflip, mantener correr y la dirección contraria enlaza el freno con la carrera hacia ese lado.

El medidor de Ferocity muestra el tiempo aéreo y suma **10 puntos de estilo por segundo** mientras aumenta. El contacto con paredes, enganches y agarres lo pausa; aterrizar cierra la cuenta y el siguiente despegue inicia otra. La ganancia mantiene el límite de rango de las acrobacias: S; por encima sigue llenando el rango actual.

Select en el mando (R en teclado) activa el taunt de la pose orgullosa estando quieto en el suelo. También aparece automáticamente tras 4 segundos de reposo. Moverse o actuar lo interrumpe. Los reinicios se eligen en Pausa: **Reiniciar desde Checkpoint** restaura el punto guardado y **Reiniciar Etapa** recarga el mapa desde el comienzo con un cronómetro nuevo. Gauntlet ofrece solo reiniciar etapa.

## Ejecuciones Ruby

Todos los enemigos mecánicos llevan un rombo Ruby rojo dentro del cuerpo. El rojo claro dentro del Ruby indica la vida restante sobre un fondo oscuro; el contorno amarillo de los guardianes indica la postura restante. Se conserva el borde negro. Un halo exterior destella cuando está **open**. El heavy de suelo, el heavy aéreo y el uppercut ejecutan, y el enemigo debe estar open antes del impacto: el golpe que lo deja con poca vida no ejecuta automáticamente. Los golpes ordinarios pueden seguir matando a los enemigos normales.

- **Normales:** un parry los inmoviliza y abre durante 2 segundos; al 30 % de vida o menos permanecen open, pero siguen atacando. Los voladores también pueden ejecutarse y dan un último rebote. El sol no lleva este sistema.
- **Guardianes:** la postura empieza en 100 y cada parry de un ataque distinto le quita un tercio, sin RNG. Las devoluciones perfectas cuentan para el tirador original; una ráfaga o un giro no se contabilizan varias veces. Romper postura abre una ventana de 2,5 segundos. Aprovecharla o perderla reinicia la postura.
- **Crítico:** contra un guardián open, el heavy daña el 22 % de su vida máxima y agrieta el Ruby sin romperlo. Un destello, una onda partida y chorros de esencia roja marcan el impacto, con un sonido más agudo que la rotura final. Si llega a cero, queda inmóvil y open hasta recibir otro heavy. La derrota, los portales y el cronómetro esperan a esa ejecución final.
- **Mordida pesada:** Viridy se transforma en una cabeza leonina líquida verde con las fauces abiertas. En aire se orienta según la caída; el uppercut recupera su pose original de puñetazo ascendente y también puede capturar un Ruby open, incluso sin el proyectil disponible. Conserva los daños, tiempos y trayectorias ordinarios. Al aterrizar el heavy cierra la mordida y conserva el deslizamiento con su estela de energía.
- **Captura:** dura 0,38 segundos; Viridy es invulnerable, pero el mundo sigue activo. En suelo la bestia alargada cierra las fauces y masca el Ruby alternando dos frames, con la boca alineada al núcleo. Al liberarlo avanza con las fauces abiertas durante 0,16 s y se funde con la corrida durante 0,10 s, sin bloquear acciones. En aire se enrolla como un ouroboros que casi se muerde la cola, independiente del screw attack, y gira sobre su propio centro en el Ruby. Sin carrera sale con el flip normal. En carrera sale hacia delante como bestia alargada, hace un flip normal en el punto más alto (con una pausa vertical de 0,22 s) y cae en aerial stall, recuperando el salto aéreo y conservando la carrera con un impulso intermedio de 740 unidades/s (560 de carrera + 180 extra), sin añadir la velocidad extrema del heavy. Se puede anticipar el siguiente ataque o salto durante la captura. Desde que explota el Ruby, los ataques, el salto disponible, el dash, el rugido y el lanzamiento del fuego pueden interrumpir la salida y el flip; no hace falta esperar a que termine la animación.
- **Energía:** una ejecución normal cura 12, un crítico cura 8 y el remate de un guardián cura 25. Es la fuente de curación del combate: ni el riposte ni los ataques fuertes SS curan por conectar. Romper un Ruby causa una explosión de radio 125 que daña 1 y empuja a los enemigos cercanos, respetando las paredes.

Los tiempos, impulso de salida y curaciones se ajustan con las propiedades `execution_*`, `critical_heal` y `boss_execution_heal` en `movimiento.gd`; las reglas del núcleo están en `ruby_core.gd`. Las hojas anteriores se conservan. `viridy_liquid_beast_v2.png` incluye las poses abiertas y cerradas; `viridy_liquid_ouroboros.png` contiene las cuatro fases del giro actual. Su procedencia y prompts están en `docs/liquid_beast_art.md`, `docs/liquid_beast_v2_art.md` y `docs/liquid_ouroboros_art.md`.

## Lanza espiritual jade y paleta

Viridy lanza una jabalina de fuego espiritual jade con cuatro poses nuevas. Conserva las velocidades, gravedad, tiempo de vuelo y cooldown del proyectil anterior. Al impactar queda clavada y enciende el cuerpo: aplica 1 de daño cada 0,5 s, sin bajar de 1 de vida ni interrumpir ataques. Una segunda pulsación consume la lanza y hace Soul pull con el tether eléctrico habitual, sin daño adicional. Si ese enemigo ya está open, Viridy se teletransporta a un destino libre junto al núcleo y hace una ejecución aérea con el rebote habitual. El terreno disipa el proyectil y deja una llama visual que desaparece sola. El cooldown de lanzamiento es 1 s y el HUD muestra su disponibilidad. Tener el fuego fuera ya no impide los ataques fuertes.

Las hojas recientes reciben una corrección selectiva al jade original, conservando ojos blancos, dientes y armadura. El uppercut sigue respetando plataformas y paredes. [Arte histórico del fuego jade](docs/jade_fire_art.md) y [mecánica actual](docs/wrath_nature/README.md).

## Wrath of Nature

En SSS, mantener abajo en el suelo durante **1 s** carga Wrath of Nature. Agacharse solo cambia la pose y conserva la caja de colisión y los inputs. Soltar, atacar, hacer dash o rugir antes de completar la carga la cancela sin gastar el rango. Durante la carga se reserva SSS frente al desgaste pasivo; recibir daño mantiene sus consecuencias normales.

Al completar la carga se consume toda la ferocidad. El indicador muestra **Wrath of Nature**, aparece el aura roja y hay **4 s** para usar heavy más una dirección. La preparación es imparable y destruye proyectiles, pero permite recibir daño. Si caduca, no devuelve ferocidad.

El heavy con dirección lanza una bestia de fuego jade mayor en una de **8 direcciones**, sin steering, a 1850 unidades/s. Atraviesa enemigos y guardianes incluso con vida, les roba el Ruby y los deja en stasis. Se detiene en paredes, techo o suelo, con límites adicionales de 4800 unidades y 3 s. Retrocede unos 11 px al chocar, cierra las fauces, rompe los Rubies en su boca y absorbe su energía: las víctimas mueren en ese momento. El sol queda fuera de este sistema.

El avance deja fuego jade y afterimages SSS. Toda la secuencia desde el lanzamiento hasta terminar su recuperación de 0,18 s es invulnerable. Después vuelve a Viridy con ferocidad cero. [Galería, parámetros, arte OpenAI + SDXL y pruebas](docs/wrath_nature/README.md).

## Mejores tiempos y fantasma

**Mejores tiempos**, en el menú principal, muestra diez marcas por etapa. También está disponible desde los resultados de la torre. Cada etapa guarda su propio ranking en `user://records_v1/`.

Al vencer al último guardián o tocar el Ruby se detiene el cronómetro. Si es una mejor marca, se guarda una trayectoria con animación a 30 muestras por segundo. Ese fantasma aparece automáticamente en el siguiente intento de la misma etapa; no tiene colisiones. Las marcas peores actualizan el Top 10 sin reemplazarlo.

## Herramientas y pruebas

- `python3 tools/generate_stage4.py`: regenera la etapa final desde su fuente.
- `python3 tools/generate_sfx.py ready countdown_tick go`: regenera los sonidos de salida.
- `bash tests/run_tests.sh`: integración y herramientas Python (requiere Pillow). Usa datos de usuario temporales para conservar los récords y ajustes reales. La suite `test_speedrun.gd` comprueba también la cuenta atrás y el recorrido físico de la chimenea.

### Movimiento y Escalera al cielo

El HUD muestra un velocímetro discreto en km/h y conserva el bonus gradual de estilo por alta velocidad. El screw attack lanza con impulso y, manteniendo correr, permite iniciar bunnyhops acelerados. El uppercut enlaza su pose original, flip normal antes del ápice y aerial stall en caída; el heavy aéreo puede encadenarse desde los 0,35 s sin esperar al flip. El dash attack de suelo y aéreo usa una pose de Viridy extendiendo el brazo y la mano en un garrazo jade ([arte y prompt](docs/dash_claw_art.md)). El dash de movimiento y el aterrizaje pesado tienen formas líquidas propias; caminar usa un ciclo ampliado y correr una carrera de postura agresiva, boca cerrada y puños cerrados, alternando el brazo delantero en cuatro poses marcadas a 12 fps.

Escalera al cielo tiene 18 fosos progresivos de 3600 a 6150 px, cadenas largas de voladores y checkpoints. Los pinchos usan mallas agrupadas y los Rubies lejanos evitan redibujarse; los detalles y la medición están en [rendimiento de la escalera](docs/sky_performance_feedback.md). Su Top 10 y fantasma del mejor tiempo se consultan en Mejores tiempos. El reloj se detiene al llegar al sol; caer conserva el tiempo transcurrido.

Arte, prompts y afinación del audio: [documentación de movimiento](docs/movement_polish_art.md).

La revisión de carrera, el HUD y las tres opciones de hum grave se describen en [carrera feroz y ajustes](docs/feral_sprint_feedback.md).

La corrección del braceo y sus prompts están en [carrera con brazos alternados](docs/sprint_arm_alternation.md).

## Combate y presentación

Los tres golpes ligeros dibujan sus slashes delante de Viridy; el remate refleja horizontalmente su media luna. El Guardián Pesado alterna el súper giro vertical con una variante horizontal con perspectiva; ambos avanzan a 65 px/s en la dirección fijada durante el aviso, sin corregirla al cruzarse con el jugador.

El shine empieza con un cubo dorado pequeño. Entre 0,08 y 0,24 s aparece el Metatrón completo con menor opacidad y giro. La presentación no modifica el radio, la ventana de parry, los i-frames ni el bloqueo. [Capturas y validación](docs/combat_feedback/README.md).
