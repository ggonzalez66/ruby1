# Viridy: screw frontal, dash de alcance y sprint

Esta tanda usa OpenAI `image_gen` para crear poses nuevas y SDXL local para el acabado. Todos los PNG de las tandas anteriores se conservan. La galería `index.html` permite reproducir el arte actual y mostrar las versiones anteriores al lado; `runtime/` contiene capturas del renderer de Godot con el shader jade y los VFX activos.

| Archivo nuevo | Frames | Cambio |
| --- | ---: | --- |
| `assets/sprites/player/viridy/viridy_screw_front_v2.png` | 6 | Cara, ambos ojos y pecho orientados hacia la cámara; brazos abiertos, piernas recogidas y melena que extiende tentáculos. |
| `assets/sprites/player/viridy/viridy_dash_reach_v2.png` | 4 | Cuerpo estirado hacia delante; palma abierta grande, visible a la derecha y separada del hocico en las dos poses centrales. |
| `assets/sprites/player/viridy/viridy_sprint_wolverine_v2.png` | 8 | Torso más inclinado, codos que se impulsan atrás, zancadas y vuelo más abiertos; cuatro claves con brazo cercano atrás y cuatro delante. Boca cerrada y puños cerrados. |
| `assets/sprites/player/viridy/viridy_claw_slashes_v2.png` | 8 | Cuatro frames de tres arañazos plateados y cuatro de media luna para el remate. |

Referencias de pose: `references/venom/screw attack`, `references/wolverine/dash attack`, `references/wolverine/sprint` y `references/wolverine/slash_vfx`, dentro de `assets/sprites/`. La identidad frontal viene de `Viridis.png`; la lateral, de `viridy_idle.png`.

## Producción y conservación

`prompts.json` contiene los prompts exactos de las cinco generaciones, los originales de OpenAI y sus copias de trabajo. El sprint final selecciona las poses 0, 1, 2, 6, 4, 7 y 3 de la primera generación y la cuarta pose de la segunda, ajustando su resolución. Las propuestas no usadas también se conservan.

Archivo de trabajo: `/home/ggonzalez66/ruby1_referencias/feedback_v2_20261024/`, con subcarpetas `openai/` y `refined/`. Cada hoja tiene su salida SDXL íntegra, grafo API y resultado mezclado. Acabado: `sd_xl_base_1.0.safetensors`, VAE fp16 fix, 12 pasos DPM++ 2M Karras, CFG 3, denoise 0,12, semillas 801–805 y mezcla RGB del 18 %, restaurando el alfa de entrada. Los efectos tienen un prompt específico sin personajes; el ensamblador neutraliza el halo a plateado/azul claro. No se interpolan frames.

```bash
python3 tools/art/refine_viridy.py docs/art/viridy_feedback_v2/prompts.json /ruta/refined
python3 tools/art/assemble_feedback_v2.py /ruta/refined
RUBY1_SKIP_COUNTDOWN=1 godot --path . --rendering-method gl_compatibility --audio-driver Dummy -s res://tools/art/capture_refresh.gd -- res://docs/art/viridy_feedback_v2/runtime
```

## Integración

La física, daño, alcance de hitboxes, cooldowns y ventanas de cancelación permanecen iguales. El sprint conserva su período de 1/3 s: 24 fps con duración relativa 1,7 en los dos apoyos, 0,65 en los cuatro pasos y 1 en las dos poses restantes. El dash conserva sus 0,22 s y el screw sus 0,34 s.

Los slashes usan el reloj del ataque, se reflejan con la dirección del jugador y se dibujan detrás del cuerpo para mantener visible la mano. El remate usa la media luna y los demás golpes, las tres marcas de garra. Al pasar al screw desaparece la estela y se conserva el remolino procedural anterior. Las funciones de estelas anteriores quedan disponibles con sufijo `_legacy`. La ejecución aérea conserva su ouroboros independiente y la pose frontal del screw no rota.

`validation.json` registra las suites comprobadas; `native_smoke.json`, los arranques de los exportados. Los originales, referencias, prompts y capturas se excluyen del contenido de los ejecutables.
