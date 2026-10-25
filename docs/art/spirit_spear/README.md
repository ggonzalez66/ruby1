# Lanza espiritual jade

La jabalina sustituye visualmente al proyectil de fuego. Conserva el input `throw_knife`, la disponibilidad de una única marca, velocidades por dirección, gravedad, impulso corriendo/riposte, límites de vuelo, cooldown de un segundo y permisos para encadenar otros ataques.

## Comportamiento

- El impacto clava una lanza visible en el enemigo, conserva su ángulo de entrada y emite motas verdes desde el cuerpo usando el emisor de la melena de Viridy. El impacto no añade daño instantáneo.
- Mientras está clavada, aplica **1 de daño cada segundo durante un máximo de 2 s** (2 puntos como máximo), con un mínimo de **1 de vida** para enemigos normales y jefes. La quemadura puede dejar a un normal open por poca vida, pero nunca completa una baja ni inicia el remate de un jefe.
- La quemadura usa `RubyCore.apply_spirit_burn()` en lugar de `take_hit()`: no empuja, rompe guardia ni interrumpe ataques. No aplica daño durante una captura/stasis o el remate de un jefe a cero; esos estados no prolongan los dos segundos ni acumulan ticks pendientes.
- Recall detiene el DoT y devuelve la lanza visible a 1800 unidades/s. Atrae una vez a cada enemigo que atraviesa, sin daño instantáneo adicional. Si está clavada en un objetivo open, conserva la teleejecución aérea y las reglas ordinarias de crítico/remate de jefe.
- En el terreno queda clavada con su ángulo de entrada, sin el splash de fuego antiguo. Permanece hasta recall. El regreso respeta paredes y recupera el arma si se bloquea. La muerte del objetivo, el reinicio y el cambio de escena eliminan la marca y restauran los materiales originales.
- Al cumplir dos segundos, desaparecen las motas y el tintado; la lanza sigue visible y permite recall o ejecución.

Los valores se ajustan con `burn_tick_interval` y `burn_tick_damage` en `knife.gd`. Se mantienen los nombres internos anteriores para conservar inputs guardados, señales, estadísticas y llamadas existentes; el menú muestra «Lanza jade / Soul pull».

## Arte e integración

| Archivo nuevo | Disposición | Uso |
| --- | --- | --- |
| `assets/sprites/player/viridy/viridy_javelin_throw_v1.png` | 4 celdas de 768 × 640, línea de apoyo 608 | Preparación sobre el hombro, impulso, liberación y follow-through |
| `assets/sprites/player/viridy/viridy_spirit_spear_v1.png` | 2 × 2 celdas de 768 × 192 | Lanza horizontal con cuatro fases de llama y punta alineada |

El lanzamiento mantiene sus **0,15 s** de pose y se sincroniza con ese reloj. Las cuatro imágenes no añaden startup, recovery ni bloqueo de acciones. La animación puede reemplazarse inmediatamente por un heavy. El sprite del arma mide 153,6 unidades de ancho (escala 0,20: el doble de la iteración inicial); conserva la hurtbox de 52 × 18 y las trayectorias previas. Los fantasmas de récords anteriores normalizan la nueva pose a su escala y orientación actuales, conservando la trayectoria grabada. El HUD usa su propia región de atlas; los efectos de quemadura reutilizan `mane_emitter.gd` en color verde, sin sprites de las llamas antiguas.

Generación mediante la herramienta integrada OpenAI `image_gen`, con `viridy_idle.png` y `viridy_light1_arcade.png` como referencias de identidad y estilo. El arma usa `viridy_jade_fire.png` como referencia de color. `prompts.json` contiene los prompts exactos y procedencia; `source/` conserva las dos salidas originales. No se borran ni sobrescriben las hojas anteriores.

Acabado SDXL local comprobado en ComfyUI/Windows: `sd_xl_base_1.0.safetensors`, VAE `sdxl_vae_fp16_fix.safetensors`, 12 pasos DPM++ 2M Karras, CFG 3, denoise 0,12, semillas 801–802 y mezcla RGB 18 %, restaurando alfa. Los grafos utilizados quedan junto a este documento. Originales, salidas SDXL completas y mezclas permanecen en `/home/ggonzalez66/ruby1_referencias/spirit_spear_20261025/`.

```bash
python3 tools/art/refine_viridy.py docs/art/spirit_spear/prompts.json /ruta/nueva/refined
python3 tools/art/assemble_spirit_spear.py /ruta/nueva/refined
godot --headless --path . --import
RUBY1_SKIP_COUNTDOWN=1 XDG_DATA_HOME=/tmp/ruby1_spirit_spear_capture godot --path . --rendering-method gl_compatibility --audio-driver Dummy -s res://tools/art/capture_spirit_spear.gd
```

La revisión del regreso físico, tamaño doble y motas verdes está en [spear_rework](../spear_rework/README.md). La galería histórica `index.html` reproduce las capturas nativas a ambos lados y muestra vuelo, lanza clavada, quemadura y recall. `test_spirit_spear.gd` verifica intervalos, mínimo de vida, ausencia de hitstun, captura/stasis, remate, consumo, limpieza, input real y heavy independiente; las suites de Soul pull y sprites se actualizan a la nueva presentación. Los resultados de esta revisión se guardan en `validation.json`.
