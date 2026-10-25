# Críticos, recuperación de jefes y ejecución universal

El crítico comparte `_impact_feedback` con el remate: mismo `guard_break` a +1 dB y pitch 1,25, mismos 16 fragmentos, destello y puff rojo. El núcleo permanece visible y agrietado. Se conservan daño, esencia y curación del crítico; el daño/empuje a enemigos cercanos sigue correspondiendo al remate final.

La apertura de los jefes dura 2,5 s también al llegar a cero. Si vence sin reclamar el Ruby, recuperan un 20 % de su vida máxima, redondeando hacia arriba, toda la postura y su IA normal. Reclamar el núcleo detiene el vencimiento durante la captura. Una ejecución completada cancela la apertura y nunca regenera al derrotado. Wrath conserva su ejecución directa.

Heavy terrestre, heavy aéreo, uppercut y Soul pull comparten la captura de 0,38 s: ouroboros centrado en el Ruby, invulnerabilidad y rebote final. Sin carrera salen con frontflip normal; en carrera salen como bestia alargada a 740 unidades/s, flip normal en el ápice y aerial stall. Se respeta el terreno al acercarse y al despegar. Las hojas anteriores se conservan.

La captura limpia los buffers anteriores y descarta jump, ataque, heavy, dash, rugido y fuego pulsados durante ella. Una pulsación nueva después de salir puede interrumpir inmediatamente la presentación del rebote. No se alteran los buffers ordinarios de combos fuera de la captura.

Durante el cooldown de 0,95 s del dash attack, atacar corriendo usa el combo ligero de tres golpes y conserva la velocidad de carrera. El combo termina aunque el cooldown venza entre sus golpes; al cerrarse, el próximo ataque disponible vuelve a ser dash attack.

La galería `index.html` incluye una comparación nativa de captura terrestre, crítico con Ruby intacto y remate. Para regenerarla:

```bash
RUBY1_SKIP_COUNTDOWN=1 godot --path . --rendering-method gl_compatibility --audio-driver Dummy -s res://tools/art/capture_combat_feedback.gd -- --execution-only
```

`execution_revision_validation.json` registra 417 comprobaciones aprobadas en nueve suites: ejecuciones, revisión de combate, combos, Wrath, Soul pull, movimiento, presentación del combate, shine/bloqueo y seguridad de Gauntlet. Incluye recuperar los tres jefes a cero, captura que protege la ventana de remate, ausencia de regeneración tras morir, descartes de los seis inputs durante captura y combo completo cuando vence el cooldown entre golpes.
