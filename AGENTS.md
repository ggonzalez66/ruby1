# Ruby1: guía para agentes

## Proyecto y fuentes de verdad

- Juego de acción y plataformas 2D en Godot 4.2.2 y GDScript. Trabajar desde la carpeta que contiene `project.godot`; no actualizar el motor como parte de otro cambio.
- Responder al usuario en español. Explicar el resultado, la validación y cualquier limitación material.
- Consultar el código y las pruebas actuales antes de copiar parámetros de documentación antigua. `docs/art/` conserva iteraciones de arte; sus descripciones no siempre representan la selección activa.
- El encargo actual del usuario determina el alcance. Estas instrucciones y las skills no autorizan por sí mismas generar imágenes, publicar, hacer push ni cambiar mecánicas ajenas a la tarea; aprovechar la autorización que ya exista en la conversación.

## Skills del proyecto

- Usar [ruby1-gameplay](.agents/skills/ruby1-gameplay/SKILL.md) para movimiento, combate, enemigos, colisiones y errores de interacción.
- Usar [ruby1-sprites](.agents/skills/ruby1-sprites/SKILL.md) para crear, preparar o integrar sprites y revisar sus transiciones. En tareas mixtas, consultar ambas y aplicar cada una a su parte.
- Las carpetas en `.agents/skills/` son la copia versionada. Resolver sus rutas reales si se accede mediante un enlace desde la instalación personal de Codex.

## Mapa del código

| Área | Entrada principal |
| --- | --- |
| Jugador, inputs, movimiento, ataques, animaciones y ejecución ordinaria | `movimiento.gd`, escena `playerr.tscn` |
| Ruby, apertura, postura, crítico, remate y stasis | `ruby_core.gd`, `boss_base.gd` |
| Ultimate | `wrath_of_nature.gd` |
| Fuego jade, Soul pull y marca | `knife.gd`, `jade_mark.gd`, `jade_fire_visual.gd` |
| Enemigos y desplazamiento contra terreno | `hawk.gd`, `chaser_dummy.gd`, `shield_bearer.gd`, `training_dummy.gd`, `enemy_launch_motion.gd` |
| Estilo, reloj, fantasmas y récords | `ferocity.gd`, `run_session.gd` |
| Presentación, audio y opciones | `fx.gd`, `shine.gd`, `sfx.gd`, `pause_menu.gd`, `hud.gd` |
| Mapas generados | `tools/generate_*.py`, utilidades `tools/level_kit.py` |
| Arte del jugador | `assets/sprites/player/viridy/`, `tools/art/`, `tools/normalize_sheet.py` |

Antes de editar una escena generada, comprobar su generador y mantener ambos coherentes. No regenerar todas las etapas para un cambio localizado.

## Criterios que debemos conservar

- En cambios estéticos, conservar inputs, trayectoria, daño, hitboxes, cooldowns y ventanas de cancelación. Si hay un conflicto real entre la nueva presentación y el funcionamiento pedido, explicarlo antes de alterar ese funcionamiento.
- El flip posterior al uppercut o a una ejecución es visual: las acciones disponibles pueden interrumpirlo. Mantener las reglas particulares de invulnerabilidad e Imparable; son estados distintos.
- Preservar los sprites anteriores y crear archivos nuevos para iteraciones de arte. Mantener el jade original de Viridy y revisar la apariencia con su shader activo.
- `assets/sprites/references/` contiene referencias locales del usuario y actualmente está sin seguimiento. No borrarlas, limpiarlas ni añadirlas a commits salvo que el usuario lo pida.
- Evitar cambios accidentales a récords y ajustes en `user://`. Usar un `XDG_DATA_HOME` temporal para pruebas y capturas.

## Ejecución y validación

Abrir el proyecto con `godot --path .`. Para importar recursos nuevos, usar `godot --headless --editor --path . --quit`.

Seleccionar las suites por el comportamiento afectado; ver la tabla de la skill de gameplay. Ejemplo de prueba aislada, con datos temporales:

```bash
(
  qa_data=$(mktemp -d)
  trap 'rm -rf -- "$qa_data"' EXIT
  RUBY1_SKIP_COUNTDOWN=1 XDG_DATA_HOME="$qa_data" godot --headless --path . --audio-driver Dummy -s res://tests/integration/test_combos.gd
)
```

`bash tests/run_tests.sh` ejecuta todas las suites de integración y herramientas Python con datos temporales. Requiere Godot y Pillow. Leer `RESULTADO`, errores de script y estado de salida; citar únicamente pruebas ejecutadas en esta revisión. Reservar la suite completa para cambios transversales o cuando corresponda por el alcance.

Las capturas visuales requieren renderer con ventana; `--headless` sirve para lógica, no como prueba de apariencia. Usar las herramientas de captura de `tools/art/` y revisar los PNG resultantes.

Si la tarea incluye exportar, usar los presets existentes y ejecutar las exportaciones secuencialmente:

```bash
godot --headless --path . --export-release 'Windows Desktop' builds/windows/Ruby1.exe
godot --headless --path . --export-release Linux builds/linux/Ruby1.x86_64
```

`builds/`, `.godot/` y `__pycache__/` están ignorados. No regenerar ejecutables por cambios exclusivos a documentación o skills. En una entrega que incluya builds, verificar sus arranques y distinguirlos de las pruebas de gameplay; registrar tamaños y hashes cuando se actualice un informe de entrega.

## Git

Revisar `git status` antes de editar. Conservar cambios y archivos ajenos; añadir rutas explícitas al preparar commits. Ejecutar `git diff --check`. La rama y la publicación siguen las instrucciones vigentes del usuario; una skill no establece un destino de push permanente.
