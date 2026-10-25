# Rework de la lanza jade — 2026-10-25

La lanza se lanza, queda clavada y vuelve físicamente al pulsar recall. Si está clavada en un enemigo ejecutable, recall conserva la teleejecución existente.

- Se clava en enemigos y terreno; ya no crea el antiguo splash de fuego en el terreno.
- Regresa a 1800 unidades/s, orientada hacia Viridy, y atrae una sola vez a cada enemigo atravesado. El barrido detecta todos los objetivos, incluso con varios impactos en un mismo frame. No añade daño instantáneo. Respeta paredes; si el regreso se bloquea, recupera el arma.
- El DoT aplica 1 punto por segundo durante un máximo de 2 segundos: como máximo 2 puntos por lanzamiento. Sigue siendo no letal y no interrumpe ataques. Captura, stasis y remate suspenden el daño sin prolongar la duración ni acumular ticks.
- Al expirar el DoT se eliminan las motas y se restauran los materiales; la lanza sigue clavada hasta recall. El recall detiene el efecto inmediatamente.
- El efecto usa `mane_emitter.gd` en verde jade (`0.12, 0.85, 0.38`), distribuido por el volumen del enemigo. Las motas quedan en coordenadas del mundo, como las de la melena.
- Se reutiliza `viridy_spirit_spear_v1.png`: 4 celdas de 768 × 192. Escala visual 0,20, ancho 153,6 unidades (el doble de la versión anterior). Ancla clavada: centro del impacto, asta desplazada 40 unidades hacia atrás y ángulo de entrada conservado. Se mantiene la hurtbox de 52 × 18, las velocidades de lanzamiento, gravedad, cooldown y cancelaciones.
- El HUD muestra CLAVADA o VUELVE según el estado.

No se generó arte nuevo. Se conservan las hojas y capturas anteriores en `../spirit_spear/`.

## Capturas revisadas

Capturas de Godot con ventana y renderer OpenGL Compatibility (Mesa llvmpipe), shader y partículas activos. Se revisaron ambas orientaciones, clavado en enemigo y suelo, regreso y expiración del efecto.

| Caso | Captura |
| --- | --- |
| Vuelo derecha | [flight_right.png](runtime/flight_right.png) |
| Vuelo izquierda | [flight_left.png](runtime/flight_left.png) |
| Clavado con motas verdes | [embedded_motes.png](runtime/embedded_motes.png) |
| Clavado tras expirar el DoT | [embedded_expired.png](runtime/embedded_expired.png) |
| Regreso entre enemigos | [return_multi.png](runtime/return_multi.png) |
| Clavado en suelo | [embedded_ground.png](runtime/embedded_ground.png) |

Reproducir con datos temporales mediante `tools/art/capture_spear_rework.gd`, usando `--rendering-method gl_compatibility` y renderer con ventana.

## Validación

344/344 comprobaciones en siete suites: lanza/DoT, barrido del regreso, Soul pull/ejecución, feedback, sprites, shine y transiciones de arte. La suite nueva comprueba 40 enemigos por frame en ambos sentidos, solapamiento entre frames sin repetir la atracción, exclusión de enemigos fuera del trayecto, recuperación y paredes. Las suites de input verifican lanzamiento, recall y ejecución con el flujo del jugador.

Las suites terminaron con código 0 y sin errores de script. Algunas ejecuciones emiten avisos de recursos/objetos al cerrar Godot. Se confirmó el mismo aviso con el código y la prueba de lanza de HEAD, en un directorio temporal aislado (25/25 comprobaciones). No se atribuye ese aviso al rework ni se considera una validación limpia del cierre del motor.

`validation.json` registra resultados y capturas de esta revisión. La sensación de velocidad y atracción queda disponible para valoración al jugar.


## Ejecutables regenerados

- Windows: `builds/windows/Ruby1.exe`, 133.767.984 bytes.
- Linux: `builds/linux/Ruby1.x86_64`, 126.161.456 bytes.
- Presets existentes, Godot 4.2.2, PCK embebido. Exportaciones secuenciales completadas sin errores. `builds.json` registra SHA-256 y tamaños.
- Linux: los seis escenarios (`main`, `stage2`, `stage3`, `stage4`, `gauntlet`, `sky_stairs`) arrancan con 120 iteraciones solicitadas, código 0 y sin errores de script. Persisten avisos de recursos al cierre en algunos escenarios.
- Windows nativo: los seis intentos inicializan OpenGL sobre la GPU, pero terminan con código 1 y errores de escritura de caché de shaders; algunos añaden avisos de recursos al cierre. Una exportación de la versión anterior (HEAD antes del commit) reproduce el mismo resultado en `main`. Esto limita la validación nativa de Windows y no se cuenta como arranque limpio ni como prueba de gameplay. `native_smoke.json` conserva los resultados y la comparación.

Los binarios permanecen en `builds/`, excluido de Git por la configuración existente. Se versionan código, pruebas, capturas e informes.
