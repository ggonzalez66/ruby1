# Combate, Ruby y controles

`index.html` permite revisar capturas reales del renderer de Godot: combo en ambas direcciones, vida y postura del Ruby, las dos variantes del giro, la formación del shine, taunt, pausa y Ready/GO. Se reutilizan los sprites existentes y no se borra arte anterior.

Los slashes del combo se dibujan delante de Viridy. El tercer golpe refleja horizontalmente su media luna; el reflejo se combina con la orientación del personaje. Al entrar en un dash se limpia ese reflejo y su estela conserva su capa anterior.

El Ruby pasa de 11 a 15 px de radio en los guardianes y aumenta 2 px en enemigos normales. Su rojo claro representa la vida restante; el fondo oscuro representa lo perdido y el borde negro se conserva. El contorno amarillo exterior pierde un tercio por cada parry distinto. Sustituye las barras anteriores, conserva las grietas y usa un halo de rombo para señalar open. Los nombres de los guardianes se mantienen. Los Rubies fuera de pantalla conservan la optimización de redibujado.

El Guardián Pesado alterna giros verticales y horizontales. Al iniciar el aviso fija el sentido hacia Viridy; durante los 1,6 s de giro avanza a 65 px/s, limitado por los extremos de su arena. El horizontal proyecta la espada con una profundidad de 0,23 y la alterna delante/detrás del cuerpo. Los segmentos del parry y el barrido de daño usan la misma proyección. La duración, daño, vueltas, recuperación y regla de un parry válido por giro se conservan.

Select (R en teclado) activa la pose orgullosa estando quieto en el suelo. Se mantiene su activación automática después de 4 s, la ganancia de estilo y la cancelación al moverse o actuar. El reinicio directo desaparece. La pausa ofrece **Reiniciar desde Checkpoint** y **Reiniciar Etapa**; el segundo recarga la escena y reinicia reloj, enemigos y checkpoints. Gauntlet solo ofrece el segundo. Los controles guardados en versión 2 o 3 se migran a la 4 conservando los otros bindings; Select se reserva para el nuevo taunt. El aviso de muerte explica cómo reiniciar desde pausa.

Ready muestra 0.00 y cuenta hasta 1.00 en un segundo real. Durante ese segundo el mundo está detenido; el reloj de la run empieza con GO. Se conservan los sonidos de Ready y GO y se añade el pulso intermedio a 0,50 s.

El shine comienza con un cubo isométrico dorado de 16 px de alto. Entre 0,08 y 0,24 s se forma el Metatrón existente; completo usa una opacidad aproximada de 0,43 y gira. Las ondas visuales comienzan ligeramente después del cubo, y el destello de impacto se conserva al conectar un parry, sin el destello grande automático al pulsar. El radio del parry, sus 0,16 s, i-frames, empuje y bloqueo no se modifican.

```bash
RUBY1_SKIP_COUNTDOWN=1 godot --path . --rendering-method gl_compatibility --audio-driver Dummy -s res://tools/art/capture_combat_feedback.gd
```

`validation.json` recoge los resultados de integración. La nueva suite `test_combat_feedback.gd` prueba también golpes reales de ambos giros, coincidencia entre dibujo y segmentos de parry, dirección fijada, taunt sin reinicio, reinicios de pausa y migración de controles. Las suites históricas de velocidad y presentación se ajustaron a los requisitos nuevos. Las capturas y pruebas quedan excluidas de los ejecutables.
