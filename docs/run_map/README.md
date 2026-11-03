# Run con mapa de hexágonos

Diseño del usuario (bocetos del 2026-11-03): el Árbol Madre es el hub. Al salir por la derecha empieza
una run y aparece el mapa: un panal de hexágonos entre el Árbol Madre y la Torre con el sol.

- **Mapa** (`run_map.gd`, estado en `run_state.gd`): 28 hexágonos en 6 filas. Se avanza a un vecino sin
  visitar, de lado o hacia arriba, y solo si la Torre sigue alcanzable (sin callejones). La primera fila son
  enfrentamientos; cada fila tiene al menos una fuente y dos enfrentamientos; no hay dos zorros juntos.
- **Enfrentamiento** (fábrica en tres escenas, `run_encounter.gd`):
  1. `factory_outdoor.tscn`: afueras con reja; al caer todos los guardias se abre la puerta.
  2. `factory_indoor.tscn`: tres pisos; al limpiarlos se abre la puerta del guardián (arriba a la derecha).
  3. `factory_boss.tscn`: un guardián que aún no se venció en la run. Da la única mejora gratis.
  Los enemigos salen de los `Marker2D` de `Spawns` (`kind`, `min_depth`) y escalan con los enfrentamientos
  superados, como las rondas del Gauntlet.
  Cámaras de seguridad (`security_camera.gd`): 3 en las entradas de afuera y 5 dentro. Barren con un cono;
  si ven a Viridy (sin paredes en medio ni invisibilidad de bush) la alarma salta en ~0,35 s y llaman 4
  refuerzos una vez. La alarma de los guardias se llena en 1,2 s y dura 9 s sin verla; el centinela llama
  4 refuerzos.
- **Fuente de curación** (`fountain.gd`): meterse en el agua cura toda la vida, una vez.
- **Zorro comerciante** (`fox_shop.gd`, `fox_stall.gd`): 4 mejoras por visita, reroll de 5 rubíes que cambia
  solo lo no vendido. Los rubíes de las ejecuciones se guardan para aquí.
- **La Torre** (`tower_finale.tscn`): los tres guardianes juntos y, tras ellos, la Araña Colosal; al vencerla
  aparece el sol. El sol absorbe a Viridy y lleva al mundo espiritual del sol (`sun_world.tscn`, ver
  `docs/pixelfx_spider/README.md`); fundirse con el Ruby termina la run.

La vida se conserva entre escenas. Morir en un combate termina la run (vuelta al Árbol Madre o al menú).
El Gauntlet por oleadas sigue disponible en Level Testing.

Regenerar las escenas de combate: `python3 tools/generate_run_stages.py`.
Capturas: `godot --path . --rendering-driver opengl3 -s res://tools/art/capture_run_map.gd` → `runtime/`.
