# Wrath of Nature y Soul pull

La galería `index.html` muestra capturas del renderer de Godot: carga, preparación, avance, Rubies robados, mascado, rotura, recuperación y fuego marcado con tether/teleejecución.

## Wrath of Nature

Abajo en el suelo permite agacharse sin cambiar movimiento, inputs ni la caja de colisión original. Con SSS, sostenerlo 1 s sin atacar, hacer dash o rugir carga la ultimate. La carga reserva el rango frente al desgaste pasivo y puede cancelarse antes de gastar nada; recibir daño conserva sus consecuencias normales. Al completarla consume toda la ferocidad y muestra **Wrath of Nature** durante una preparación de 4 s con aura roja animada. En esa preparación los golpes siguen quitando vida, pero no interrumpen, y los proyectiles se destruyen. Caducar no devuelve estilo.

Con la ultimate cargada, pulsar **heavy** abre una anticipación de **0,25 s**, por delante del uppercut o cualquier otro ataque. Viridy queda quieto y una flecha indica la dirección. Durante esa ventana se elige o corrige cualquiera de las ocho direcciones; se conserva la última indicada aunque se suelte. Si no se indica ninguna, usa el facing al pulsar heavy. Al terminar la ventana sale automáticamente, sin segundo botón, a 1850 unidades/s. La selección conserva el aura y el estado imparable, pero aún recibe daño; la invulnerabilidad empieza al salir. Confirmar antes de caducar READY reserva los 0,25 s completos.

Durante el avance no se corrige la dirección. Una consulta de volumen barrido captura los Rubies de las hurtboxes atravesadas; se respeta el terreno entre la trayectoria y cada núcleo. Los normales y los jefes, incluso con vida, quedan en stasis hasta la rotura. El sol y los elementos sin Ruby no se capturan. Los actores se liberan correctamente si la acción se cancela por reinicio o cambio de escena.

Seis sonidos originales sintetizados en `tools/generate_sfx.py`: carga grave en bucle (se detiene al cancelar/completar), confirmación de carga, anticipación de 0,25 s, rugido de salida con fuego, impacto grave y fragmentación con absorción. Todos usan el bus SFX y su volumen de Opciones.

Se detiene al chocar con paredes, techo o suelo, o alcanzar 4800 unidades/3 s. El retroceso de 190 unidades/s se amortigua durante 0,12 s, desplazándolo unos 11 px. Después hay 0,30 s de mascado; todos los Rubies se rompen desde la boca, las víctimas mueren y la energía cura con los valores de ejecución existentes (normal 12, jefe 25, sin pasar del máximo). La recuperación de 0,18 s funde la bestia con Viridy. Todo el ataque, incluida esa recuperación, es invulnerable y termina con ferocidad cero. Las bajas no recargan el rango durante la ultimate.

`wrath_of_nature.gd` contiene los parámetros y la secuencia. El actor normal conserva sus ventanas de combo y recuperación. Los afterimages usan el material y color SSS habituales; el fuego residual reutiliza el arte jade, sin hitbox ni daño.

## Fuego jade

Una sola marca activa. Lanzamiento y recall hacen **0 daño**. Al impactar un enemigo el proyectil desaparece, explota visualmente y deja una marca verde animada que lo sigue. Pulsar de nuevo crea un tether jade de opacidad 0,18 y un Soul pull de 0,22 s, sin un proyectil de regreso. Se respeta el terreno para la atracción. Los enemigos que ya podían devolver fuego conservan esa defensa.

Si el objetivo marcado ya está open al pulsar recall, se busca un destino libre de terreno alrededor del núcleo y se teletransporta a Viridy para iniciar la ejecución aérea existente. Esa ejecución mantiene invulnerabilidad, curación, giro ouroboros, rebote y cancelaciones habituales. Contra un jefe se mantienen las reglas ordinarias de crítico y remate; la excepción que ejecuta con vida es Wrath of Nature.

Al tocar terreno explota, deja un splash visual durante unos 3 s y libera la disponibilidad. También se disipa después de 4 s de vuelo si no encuentra objetivo. El cooldown de lanzamiento es **1 s**, configurable como `jade_fire_cooldown` en el jugador, y se muestra junto al icono del HUD. Lanzar el fuego ya no impide heavy terrestre, aéreo ni uppercut. El combate cura por ejecución; se elimina la antigua curación por conectar ataques fuertes SS/SSS y se mantiene sin curación el riposte. Los checkpoints conservan su función de restauración.

## Arte y reproducción

Nueva hoja: `assets/sprites/player/viridy/viridy_wrath_nature_v1.png`, cuatro celdas de 768 × 512 en una fila. Dos fauces abiertas para avanzar y dos cerradas para mascado. Se usa un canvas de 185 unidades frente a las 125 de la bestia ordinaria. Se conservan todos los sprites anteriores.

Generación con la herramienta integrada OpenAI `image_gen`, editando la bestia aprobada como referencia de identidad. `prompts.json` guarda el prompt exacto, la ruta original y la copia de trabajo. SDXL local aplica el acabado: `sd_xl_base_1.0.safetensors`, VAE fp16 fix, 12 pasos DPM++ 2M Karras, CFG 3, denoise 0,12, semilla 801 y mezcla RGB de 18 %, conservando alfa. El ensamblador recorta por componentes y mantiene alineadas las fauces; el shader jade conserva ojos y colmillos claros. Originales, salida SDXL y grafo quedan en `/home/ggonzalez66/ruby1_referencias/wrath_20261024/`.

```bash
python3 tools/art/refine_viridy.py docs/wrath_nature/prompts.json /ruta/refined
python3 tools/art/assemble_wrath.py /ruta/refined/wrath.png
RUBY1_SKIP_COUNTDOWN=1 godot --path . --rendering-method gl_compatibility --audio-driver Dummy -s res://tools/art/capture_wrath.gd
```

`validation.json` registra integración y herramientas. `test_wrath_nature.gd` cubre carga, gasto, daño durante preparación, proyectiles, stasis, jefes con vida, ocho direcciones, input real, límites, colisiones y cancelación segura. `test_jade_soul_pull.gd` cubre vuelo real, marca, daño cero, heavy independiente, cooldown, teleejecución con rebote y splash temporal. Las pruebas anteriores se actualizaron donde la mecánica pedida sustituyó su comportamiento. `native_smoke.json` registra arranques de las builds; `builds.json`, tamaños y hashes.

La revisión de dirección y audio está registrada en `input_audio_validation.json`: 283 comprobaciones de Wrath, SFX, combos, ejecuciones, Soul pull y WAV finales. Se revisó `runtime/aim.png` en el renderer nativo y se verificaron de nuevo los seis escenarios en ambas builds.
