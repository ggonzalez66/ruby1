# Fuego jade y continuidad visual

Activo final: `assets/sprites/player/viridy/viridy_jade_fire.png`, cuatro frames en cuadrícula 2 × 2. Generado con la herramienta integrada `image_gen`, usando `viridy_idle.png` como referencia del jade y del sombreado. Fondo transparente; el archivo generado se copió al proyecto conservando el original. No se editaron píxeles con Python. El juego recorta las celdas y anima a 14 fps. `jade_fire_visual.gd` comparte la primera celda entre el HUD y el aviso de recuperación.

La mecánica conserva lanzamiento, anclaje, caída, recuperación, atracción, riposte y devoluciones por rugido. La llama se orienta con su trayectoria, tiene estela jade y sonidos de aire y crepitación sintetizados por `tools/generate_sfx.py`. Los identificadores internos `knife` y `throw_knife` se conservan para no alterar controles guardados, contadores y estadísticas. Los textos visibles usan Fuego jade.

Las hojas nuevas de caminar, correr, bestia líquida, ouroboros, dash y aterrizaje usan una corrección selectiva del pigmento verde en `shaders/charge_glow.gdshader`. Sus formas y frames se conservan. La corrección se activa por textura; las hojas originales permanecen sin corrección. Respeta los tonos neutros de ojos, dientes, metal y tela. El fantasma también aplica la paleta según su frame.

La salida aérea en carrera usa 740 unidades/s (`sprint_speed` 560 + `execution_air_exit_boost` 180) como punto intermedio. El extra no procede de la velocidad extrema del heavy ni modifica el rebote ordinario. Al aterrizar o iniciar otro ataque se cierra ese impulso de salida. Saltar o lanzar fuego permite continuar con el movimiento habitual.

Las ejecuciones iniciadas desde el suelo usan ahora el mismo ouroboros y rebote que las aéreas. La salida alargada con boca abierta se conserva para la carrera, en el aire; ya no se realiza el deslizamiento o fundido terrestre ni se guardan acciones pulsadas durante la captura.

## Prompt exacto

```text
Use case: stylized-concept. Asset type: game projectile sprite sheet, four animated frames. Reference image shows Viridy; use ONLY his ORIGINAL muted JADE GREEN palette and classic arcade pixel-art shading as color/style reference, not his anatomy. Create a projectile made entirely of magical JADE GREEN FIRE, a compact bright pale jade core at RIGHT with flame tongues streaming to LEFT. Organic fire comet, no weapon, no blade, no handle, no character face or lion head. Four slightly different flickering silhouettes for a seamless loop, ALL face RIGHT and share the exact same core position and baseline. Palette: desaturated cool jade midtones approximately #41866b, deep green #163f37 shadows, pale celadon #bbd89e and tiny ivory highlights; avoid neon lime, yellow-green, electric chartreuse, cyan or blue. Crisp detailed 1990s arcade sprite pixel clusters, no smooth painterly look. EXACT layout 2 columns x 2 rows, four equal square cells, canvas 1024x1024; each cell512x512. Each comet maximum380px wide by210px tall, centered at x256 y256 within cell; core near x350 and tail toward x80. At least60px fully transparent gutters in every cell; all flames inside own cell. True transparent background alpha0, no black backdrop, no green haze, no aura outside silhouette, no text, no grid, no floor, no sparks crossing cells. This must read as jade fire at small game scale.
```

El resultado final tiene 1280 × 1280; el consumidor calcula el tamaño de celda desde la textura para mantener el recorte correcto.
