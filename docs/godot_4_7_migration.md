# Migración a Godot 4.7.2

Rama `godot-4.7`, desde `main` en `5a64733` (Godot 4.2.2). Binario usado: Godot 4.7.2 estable oficial
(`4.7.2.stable.official.ed1daf0bf`), con sumas SHA-512 verificadas contra la publicación de GitHub.

## Qué cambió en el proyecto

- `project.godot` declara la versión 4.7. Al importar, Godot 4.7 creó un `.uid` junto a cada script y
  shader (164 archivos): se versionan, porque guardan la identidad del recurso si se mueve o renombra.
- El juego no necesitó cambios de código: importa y corre sin errores de script. Revisé las guías de
  migración 4.3 → 4.7 contra el proyecto: no usa `TileMap`, `WorldEnvironment`/glow, navegación,
  `RichTextLabel.add_image`, `@export_file`, ni compara `event.device` con 0. Las tres `Curve` que crea
  tienen sus puntos dentro de [0, 1].
- `tests/run_tests.sh` acepta `GODOT=<binario>`.

## Diferencias de 4.7 que afectaron a pruebas y herramientas

- **Pulsaciones simuladas.** `Input.action_press` ahora marca la acción como «recién pulsada» en el
  physics frame siguiente (`get_physics_frames() + 1`). Con input real no cambia nada: los eventos se
  procesan antes de que avance el contador de física, así que el jugador no tiene un frame de retraso.
  Once suites simulaban toques de un solo frame o pulsaban y procesaban en el mismo frame. Se ajustaron
  sin cambiar lo que comprueban: el toque dura dos frames, o se espera a que la pulsación cuente antes de
  procesar a mano. En dos casos con tiempos al límite (el muñeco del riposte y el bot de la chimenea) se
  movió el muñeco 15 px o se cambia la dirección en el mismo frame que cuenta el salto.
- **Scripts con `-s`.** Ya no compilan si precargan scripts que usan autoloads. Las herramientas de
  captura cargan esos scripts con `load()` al empezar.
- **Ejecutables exportados.** Release y debug ya no aceptan una escena por línea de comandos. La prueba
  por escena usa el paquete exportado con el binario de Godot (`--main-pack`).
- **Capturas.** Al arrancar con renderer, 4.7 compila shaders y los primeros frames tardan. Con
  `--fixed-fps 60` las capturas vuelven a ser deterministas. Aparte, `capture_batch_nov4.gd` dejaba el
  juego en pausa tras la sección `fade` (fallo de la herramienta, también en 4.2): ahora lo reanuda.

## Verificación

- Suite completa con 4.7.2: 1746/1746, sin errores de script.
- Capturas de `tools/art/capture_batch_nov4.gd` con 4.7.2 en Windows (GPU real), comparadas con las de
  4.2.2: mismos efectos, HUD, agua, pasarelas, sabueso, muerte y transición. Las diferencias vienen de
  capturas viejas de 4.2, anteriores a correcciones (barrido de patada sólido, pasarela con celosía,
  un solo «!»), o del azar de las cámaras ausentes.
- Builds (`builds/godot47/`, fuera de git):
  - Windows `Ruby1.exe` 187 592 984 bytes, sha256 `4bc208fc649b026e…`. Arranca y sale sin errores.
  - Linux `Ruby1.x86_64` 151 740 488 bytes, sha256 `83e1301e40f89333…`.
  - El paquete exportado abre las 22 escenas en Linux y 15 en Windows, 300 frames cada una, sin errores.
- Los ejecutables pesan más que con 4.2.2 (Windows +39 MB, Linux +11 MB): son los templates de 4.7.

## Mejoras de 4.7 que aún no están activadas

- Interpolación de física 2D (`physics/common/physics_interpolation`): suaviza el movimiento en pantallas
  de más de 60 Hz. Cambia cómo se ve cada teletransporte (reaparecer, ejecuciones, cámara), así que va en
  un cambio aparte con sus pruebas.
- Compilación previa de shaders al exportar: reduciría el primer tirón de cada efecto en Windows.
