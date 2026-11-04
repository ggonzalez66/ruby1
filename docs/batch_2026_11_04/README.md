# Tanda del 2026-11-04

Capturas en `runtime/` (`tools/art/capture_batch_nov4.gd`, con renderer; `CAPTURE_ONLY=<sección>`).
Pruebas nuevas: `tests/integration/test_level_variants.gd`.

## Controles y movimiento

- Caminar es más rápido: `max_speed` 320 → 400 (animación de caminar a 15 fps). El control en el aire sigue en
  320 (`air_max_speed`): los niveles se diseñaron con él. Un salto que sale caminando conserva su impulso
  (`ground_momentum`); un walljump vuelve al control aéreo de siempre.
- Lanza de jade: mantener LT apunta y al soltarlo se lanza; volver a pulsar LT la recupera. Las demás armas
  siguen con LT + RT. La mira mide 420 px (`light_combo.AIM_LENGTH`).
- RB (Enfoque y cámara lenta) es siempre un toggle.
- Ligeros aéreos: la suspensión solo continúa mientras se sigue conectando; un golpe al aire la corta.
- Combo ligero: dos zarpazos, rodillazo (cuadros de rodilla de `viridy_kick1_v2_arcade.png`) y dos patadas.
  Las hojas arcade más pequeñas se agrandan (`ARCADE_SIZE_FIX`). El rodillazo y las patadas tienen un
  barrido de PixelFX del tamaño de su zona de golpe. El efecto del primer zarpazo ahora baja (de arriba
  abajo) y el del segundo sube a la altura del brazo.
- Al caer de un salto normal (sin carrera) se usa la pose del aerial stall.
- Pasarelas atravesables (`platform.gd` `one_way`): se suben saltando a través y se bajan con abajo + salto.
- Agua (`water_zone.gd`, estilo Metroid): dentro, Viridy camina, salta y cae más lento (`WATER_SCALES`), sin
  tocar los ataques; deja estelas de burbujas. Está en la poza de la fuente y en las variantes B de la fábrica.

## Mejoras nuevas

- Ejecución certera (`sure_execution`): un ataque pesado que deja al enemigo sin vida lo ejecuta al instante.
- Lanza punzante (`spear_sting`): el enemigo con la lanza clavada recibe un 25 % más de daño.
- La pistola tiene cargador de 12 balas y recarga en 1,3 s al vaciarse (balas junto a la mira).

## Enemigos y niveles

- Enemigos elementales: coronita del color de su elemento sobre la cabeza (`element_aura.gd` busca la cabeza
  en el sprite o en los polígonos de cada tipo).
- Los enemigos ya no se meten dentro de los bloques: comprueban su cuerpo entero antes de moverse y, si
  quedan dentro, salen por el lado libre más cercano. Las pasarelas no les cuentan como pared.
- Sabueso: "!" dramático de PixelFX y gruñido de aviso (0,28 s de aviso, antes 0,24), estela roja al
  lanzarse, sonido de captura y uno por cada machaque.
- El dron sanador se tambalea un instante con cada golpe.
- Variantes de nivel: cada cámara puede faltar (35 %, siempre queda una) y cada enfrentamiento elige una
  de tres afueras (original, el canal, el patio de carga) y uno de tres interiores (original, el sótano
  inundado, la línea de montaje).

## Efectos y presentación (PixelFX)

- Estados: llamas (`burning`), bloque de hielo (`ice_block`), hielo roto (`ice_shatter`), estrellas de
  aturdido (`stunned`) en enemigos y en Viridy; fogonazo en pistola, railgun, fusilero y araña (`muzzle`).
- Ambiente: luciérnagas y hojas que caen en la jungla; ondas y flor de curación en la fuente; reloj al
  activar el Enfoque; transición de escena de fuego jade (`SceneFade`, autoload).
- Efectos propios del juego (`tools/art/pixelfx_fx/*.js`, categoría `ruby1/`): onda expansiva del
  aterrizaje del picado (recrea las ondas de polígonos originales), brasas que se levantan y quedan
  suspendidas, estallido del ruby en rombo y orbes rojos que absorbe Viridy, corte del uppercut que se
  queda en el aire, barrido de patada, llamitas de la melena, luciérnaga, hoja y burbujas.
- El enganche a la pared del picado es discreto (chispa y polvo) y deslizarse por la pared suelta polvo.
- Arbustos: quien está dentro (Viridy o un enemigo) se ve solo como contorno.
- Muerte de Viridy (`death_cinematic.gd`): congelado en el golpe letal con zoom y pantalla en negativo,
  golpe crítico con eco, vuela girando y estalla en fuego verde.
