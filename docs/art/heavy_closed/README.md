# Heavy terrestre: cierre de fauces

El último frame del heavy terrestre reutiliza la primera pose cerrada de `viridy_liquid_beast_arcade.png`, con márgenes de atlas para conservar el canvas y el apoyo del ataque. Su recuperación visual de 0,09 s utiliza las dos poses cerradas de `ruby_chew`, y conserva el fundido al volver a correr. Los PNG anteriores permanecen intactos.

La duración del ataque sigue siendo 0,14 s. Daño, hitboxes, velocidades, cooldowns y cancelaciones conservan sus valores. La salida de la ejecución terrestre y el heavy aéreo mantienen sus poses independientes.

Capturas reales de Godot: `runtime/heavy.png` muestra la mordida inicial, `runtime/heavy_close.png` su cierre y `runtime/heavy_recovery.png` la recuperación.

```bash
RUBY1_SKIP_COUNTDOWN=1 godot --path . --rendering-method gl_compatibility --audio-driver Dummy -s res://tools/art/capture_refresh.gd -- res://docs/art/heavy_closed/runtime heavy,heavy_close,heavy_recovery
```

`validation.json` registra las suites comprobadas.
