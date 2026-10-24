# Rebote, carrera y rendimiento de Escalera al cielo

Revisión posterior: la ejecución aérea en carrera sale a `sprint_speed + execution_air_exit_boost` (560 + 180 = 740 unidades/s), punto intermedio entre el rebote normal y la salida excesiva anterior. El heavy deja de convertir su velocidad de impacto en bonus y la salida no activa el salto largo. La componente vertical sigue usando los ratios del rebote habitual según la trayectoria del heavy. Las acciones pueden seguir interrumpiendo el flip estético.

La carrera usa cuatro poses a 12 fps, dos por cada brazo delantero. Se omite la pose intermedia de cada tripleta, manteniendo los apoyos más tiempo. Se conservan las hojas, los puños y la boca cerrados, la escala y la alternancia de brazos.

Escalera al cielo conserva sus 18 fosos y 273 voladores. Los cambios de rendimiento son:

- Las espinas se agrupan en mallas de hasta 64 triángulos, con descarte por bloques fuera de cámara, en vez de crear un nodo por pincho. Las colisiones y el retorno al checkpoint conservan sus dimensiones.
- Los tres límites exteriores conservan colisión, pero no dibujan ladrillos y musgo. El techo abarca 93 740 unidades; la decoración completa añadía miles de comandos de dibujo.
- El Ruby actualiza su brillo solo cerca de la pantalla. La postura, las aperturas y los demás temporizadores siguen contando fuera de cámara.

La escena completa pasa de 16 997 a 3003 nodos en la medición inicial. Con Godot 4.2.2, OpenGL Compatibility y Mesa llvmpipe (renderizado por CPU), la misma muestra de arranque bajó de 160,10 ms a 30,77 ms de mediana por frame. Estos números comparan esta máquina; no predicen los FPS de una GPU distinta. La medición final del recorrido registró medianas de 29,29 ms en el arranque, 22,49 ms en la isla 9 y 28,62 ms en la cima.

Para repetir una medición con dibujo activo, usando el mismo renderer, resolución y equipo entre versiones:

```sh
RUBY1_SKIP_COUNTDOWN=1 godot --path . --rendering-method gl_compatibility --disable-vsync --max-fps 0 -s res://tools/profile_sky_stairs.gd
```

`tests/integration/test_sky_performance.gd` verifica el presupuesto de nodos, los apoyos, las colisiones horizontales y rotadas, el retorno al checkpoint y los temporizadores fuera de cámara. No exige una tasa de FPS al hardware del test.
