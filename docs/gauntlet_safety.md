# Preparación y confirmación del Gauntlet

Al tocar TERMINAR se abre un diálogo que pausa el juego y el cronómetro. El foco empieza en «Seguir jugando». Escape, B o Pausa cancelan; también se puede usar el botón. Al cancelar hay que salir físicamente del portal y volver a entrar para abrirlo otra vez. Solo «Terminar run» consume el portal y muestra los resultados. SEGUIR conserva su funcionamiento directo. La pausa normal no se abre encima de la confirmación.

Cada oleada y cada aparición de guardianes aplica `spawn_grace_time` (2 segundos por defecto) desde `gauntlet_director.gd`. El HUD muestra PREPARACIÓN y el tiempo restante. Los proyectiles de la ronda anterior se limpian al pasar de oleada.

El director asigna el margen a cada enemigo antes de añadirlo al árbol. RubyCore cuenta el tiempo y mantiene la IA en espera usando el mismo bloqueo local que ya comparten perseguidores, escuderos, tiradores, halcones y guardianes. Viridy puede moverse y atacar. El contador se detiene al pausar y no cambia el comportamiento de los enemigos fuera del Gauntlet.
