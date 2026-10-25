# Validación de gameplay

Ejecutar desde la raíz de Ruby1. Elegir las filas relacionadas con el cambio; no ejecutar todas las suites por una edición visual o documental menor.

| Cambio o riesgo | Suites en `tests/integration/` |
| --- | --- |
| Uppercut → heavy, prioridades, dash attack y cadenas | `test_combos.gd`, `test_combat_modes.gd` |
| Captura, crítico, remate, salida aérea y cancelaciones | `test_executions.gd`, `test_combat_revision.gd` |
| Parry, shine, i-frames y feedback de combate | `test_shine_shield.gd`, `test_combat_feedback.gd` |
| Wrath: carga, dirección, invulnerabilidad, captura y cancelación | `test_wrath_nature.gd` |
| Lanza jade, DoT no letal, recall y teleejecución | `test_spirit_spear.gd`, `test_jade_soul_pull.gd`, `test_feedback_v2.gd` |
| Halcón, terreno, primer screw y marca jade | `test_feedback_v2.gd` |
| Uppercut contra plataformas y paredes | `test_uppercut_collision.gd` |
| Gauntlet: aparición, gracia y portal de terminar | `test_gauntlet_safety.gd` |
| Movimiento, velocidad y bunnyhop | `test_movement_polish.gd`, `test_regression.gd` |
| Animación, escala y separación entre pose y gameplay | `test_sprites.gd`, `test_art_refresh.gd` |
| Enemigos, detección y ataques | `test_enemigos.gd` |
| Reloj, récords y fantasmas | `test_speedrun.gd`, `test_sky_records.gd` |
| Escalera al cielo: geometría, presupuestos y alcance | `test_sky_performance.gd`; consultar `tests/reach/` si cambia el recorrido |
| Audio y herramientas de WAV | `test_sfx.gd`, `tests/tools/test_sound_tuning.py` |

## Una suite con datos aislados

```bash
(
  qa_data=$(mktemp -d)
  trap 'rm -rf -- "$qa_data"' EXIT
  RUBY1_SKIP_COUNTDOWN=1 XDG_DATA_HOME="$qa_data" godot --headless --path . --audio-driver Dummy -s res://tests/integration/test_combos.gd
)
```

Mantener el log completo cuando falle. Comprobar salida del proceso, `RESULTADO` y errores de script; la ausencia de un mensaje de fallo no equivale a una prueba completada. La cuenta Ready/Go tiene sus propias pruebas: `RUBY1_SKIP_COUNTDOWN=1` facilita las demás suites, pero no demuestra su comportamiento visual.

`bash tests/run_tests.sh` crea su propio directorio temporal y recorre integración y herramientas Python. Usarlo para cambios transversales cuando las pruebas pertinentes ya hayan pasado. No reutilizar totales de informes históricos como resultados de la revisión actual.

## Reproducciones y mediciones

Para input/cancelaciones, reproducir el orden real de pulsar/soltar y la transición a la siguiente acción, en vez de limitarse a asignar el estado final. Para terreno, probar a ambos lados y con velocidad alta, incluyendo el volumen del cuerpo y el bloqueo de visión/daño. Comprobar limpieza al reiniciar si se añaden capturas, marcas, tweens o bucles.

Para caídas de FPS, medir con renderer activo. `tools/profile_sky_stairs.gd` y `docs/sky_performance_feedback.md` contienen el caso de Escalera al cielo. Comparar tiempo de frame, scripts, física y dibujo en el mismo equipo/configuración; una prueba headless o un presupuesto de nodos no mide los FPS visibles.

Para apariencia, usar las capturas específicas de `tools/art/`; consultar la skill de sprites si cambia un asset o su integración. Para builds, seguir `AGENTS.md` y las instrucciones de entrega del usuario.
