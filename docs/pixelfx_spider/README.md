# PixelFX, Araña Colosal y mundo del sol (2026-11-03)

## Efectos con PixelFX

Los efectos breves del juego se dibujan con hojas de [PixelFX](https://github.com/patch-gg/pixelfx) (MIT;
licencia en `assets/fx/pixelfx/LICENSE-pixelfx.txt`).

- La copia de PixelFX vive fija fuera del repo, en `~/tools/pixelfx` (commit `a841596`, v0.3.0). Para
  instalarla: `git clone https://github.com/patch-gg/pixelfx ~/tools/pixelfx && (cd ~/tools/pixelfx && npm install)`.
- `python3 tools/art/export_pixelfx.py [nombre ...]` la usa por defecto (otra ruta: `--pixelfx` o la variable
  `PIXELFX`). Renderiza cada efecto con Node, corta las colas largas, recorta el espacio vacío y escribe
  `assets/fx/pixelfx/<nombre>.png` y `pixel_fx_data.gd`.
- `pixel_fx.gd` (`PixelFx.play`) los reproduce como `AnimatedSprite2D` con filtro nearest. Las hojas "grises"
  se tiñen en vivo con la paleta del golpe (shader de mapa de degradado).
- `fx.gd` conserva su API: `impact`, `deflect`, `dust`, `puff`, `shatter` y `ruby_critical` usan PixelFX, y se
  suman `explosion`, `big_explosion`, `heal`, `warp_in`, `charge`, `zap`, `collect`, `shield_hit` y
  `bullet_impact`. Las ondas del rugido, el anillo del doble salto, el shine y el texto flotante siguen
  siendo procedurales porque muestran radios de juego.

## Cámaras destructibles

`security_camera.gd` es un `Area2D` en la capa de enemigos: se rompe de un solo golpe (golpes, lanza o
balas), da estilo ("CÁMARA DESTRUIDA") pero no rubíes, no alerta a los guardias y, rota, ya no ve.

## La Araña Colosal

Llega a la Torre al caer el trío (`run_encounter.gd`); el sol solo aparece al vencerla.

- `spider_boss.gd`: cuatro patas con IK de dos segmentos y pisadas plantadas. Hace estocadas con una pata,
  embiste y dispara la railgun (apunta, fija y dispara tres veces).
- `spider_leg.gd`: el ruby de cada pata. Se golpea hasta exponerlo y se ejecuta con un pesado; si no, se
  rompe solo.
- `spider_core.gd`: el ruby central. No se aturde ni pierde postura, y la ultimate no lo toma mientras
  queden patas. El escudo bloquea el daño hasta que caen las cuatro patas.
- Sin patas se desploma y llama una vez a cuatro esbirros. Muere al romper el ruby central.

## El mundo espiritual del sol

`sun_world.tscn` (`tools/generate_sun_world.py`) reemplaza a `stage4.tscn` como final de la run
(`RunState.PARKOUR_SCENE`); `stage4` sigue en la historia.

- Tiene seis pisos de plataformeo en zigzag y un séptimo con el Ruby en el centro.
- En cada piso hay lava (`lava.gd`), que devuelve al checkpoint sin quitar vida, y un checkpoint al empezar.
- Hay plataformas que se caen (`falling_platform.gd`), géiseres (`lava_geyser.gd`: dañan solo mientras se ve la columna de fuego) y espíritus en los que se
  rebota con el pesado.

## Ira encadenada

La mejora `wrath_chain` del catálogo de rubíes modifica la Ira de la Naturaleza
(`wrath_of_nature.gd`):

- Al morder a un enemigo, la bestia se detiene un instante para elegir otra de las 8 direcciones.
- Cada relanzamiento va un 22 % más rápido.
- Mantener el ataque ligero pasa de largo, como sin la mejora.

Capturas: `godot --path . --rendering-driver opengl3 -s res://tools/art/capture_pixelfx_spider.gd` →
`runtime/`. Pruebas: `tests/integration/test_spider_sun.gd`.
