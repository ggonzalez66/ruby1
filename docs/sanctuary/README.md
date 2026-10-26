# Level Testing y Santuario

Primera etapa de prueba de la futura estructura roguelike. Acceso: **Menú principal → Level Testing → Santuario**.

## Recorrido disponible

El santuario es un claro de 6400 unidades de ancho, con el Árbol Madre como centro y punto de aparición de Viridy. Una laguna turquesa rodea su isla; una pequeña cascada, flores de agua, polen y aves acompañan el paisaje. El fondo utiliza capas de bosque y una copa de gran escala para representar el corazón de la naturaleza.

Las orillas ofrecen tramos para correr y encadenar bunnyhops. Rocas altas, raíces y plataformas entre las ramas permiten practicar saltos, salto aéreo, trepadas y cambios de dirección. Se conserva el script y la física actuales de Viridy.

La laguna tiene agua animada, salpicaduras de entrada y un fondo sólido y seguro. Se puede recorrer su fondo y salir por las orillas con la movilidad normal. Este prototipo no incorpora natación, flotabilidad ni ahogamiento.

Es una escena de exploración y pruebas: no hay enemigos, portales, inicio de run, cuenta atrás ni escritura de récords. Los límites contienen al jugador y una salvaguarda recupera a Viridy junto al árbol si sale del recinto. El hub narrativo, los diálogos, la selección de armas y las expediciones todavía no forman parte de esta escena.

Desde Pausa se puede reiniciar desde el punto de aparición, reiniciar toda la escena, volver a **Level Testing** o regresar al menú principal. El HUD conserva velocidad y Ferocity para observar la movilidad.

## Archivos y futuras etapas

| Archivo | Responsabilidad |
| --- | --- |
| `level_testing.gd` / `level_testing.tscn` | Selector. `LEVELS` contiene título, descripción y ruta de cada etapa disponible. |
| `sanctuary.gd` / `sanctuary.tscn` | Composición del santuario, geometría, aparición, agua, efectos y HUD. |
| `sanctuary_ground.gd` | Un mismo contorno define dibujo y colisión de cada superficie. |
| `sanctuary_visuals.gd` | Bosque, Árbol Madre, raíces, follaje y luz. El dibujo se mantiene estático. |
| `sanctuary_lagoon_details.gd` | Flores flotantes y aves; solo esta capa pequeña se redibuja a 20 Hz. |
| `shaders/sanctuary_water.gdshader` | Color, profundidad visual y ondulaciones de la laguna. |
| `pause_menu.gd` | `testing_mode` activa reinicio de etapa y regreso al selector en las escenas de prueba. |

Para añadir otra etapa, crear su escena y registrar una entrada en `LEVELS`. El selector tiene desplazamiento y seguimiento del foco para alojar más escenarios. Las nuevas escenas de exploración pueden usar `testing_mode = true` en su menú de pausa y deben permanecer fuera de `RunSession.MODES` mientras no sean modos cronometrados.

La composición se construye al cargar la escena. Las superficies se editan en `_build_terrain()` y `LEDGES`, en `sanctuary.gd`; no hay un generador externo ni se modificaron otros mapas. El paisaje usa dibujo y shaders nativos de Godot, sin generar ni sustituir sprites del personaje.

Abrir directamente:

```bash
godot --path . res://sanctuary.tscn
```

## Revisión visual

Las capturas se generan con `tools/art/capture_sanctuary.gd`, usando renderer con ventana, shader y partículas activos. Ejecutar con `XDG_DATA_HOME` temporal para aislar los ajustes y récords del usuario.

```bash
godot --path . --rendering-method gl_compatibility --audio-driver Dummy -s res://tools/art/capture_sanctuary.gd
```

| Vista | Captura |
| --- | --- |
| Menú principal | [main_menu.png](runtime/main_menu.png) |
| Selector de pruebas | [level_testing.png](runtime/level_testing.png) |
| Aparición junto al árbol | [spawn.png](runtime/spawn.png) |
| Árbol Madre y claro | [mother_tree.png](runtime/mother_tree.png) |
| Laguna | [lagoon.png](runtime/lagoon.png) |
| Circuito occidental y cascada | [west_trails.png](runtime/west_trails.png) |
| Copa y ramas | [canopy.png](runtime/canopy.png) |
| Pausa y regreso al selector | [pause.png](runtime/pause.png) |

## Validación

`test_level_testing.gd` recorre los menús con eventos de teclado, verifica aparición y movimiento, salto aéreo, colisiones, agua sin daño, salida por la orilla, límites, recuperación de caídas, reinicio, navegación de vuelta y ausencia de archivos de récords. También se ejecutan las regresiones de modos/menú y ajustes.

Los resultados de esta revisión se registran en `validation.json`. Las capturas con renderer sirven para revisar la composición y la lectura del terreno; no son una medición de FPS. Persisten avisos de recursos al cerrar Godot ya observados en revisiones anteriores. Las exportaciones de esta entrega se describen a continuación.


## Ejecutables actualizados

Exportaciones release realizadas secuencialmente con los presets existentes, Godot 4.2.2 y PCK embebido:

- Windows: `builds/windows/Ruby1.exe`, 133.798.304 bytes.
- Linux: `builds/linux/Ruby1.x86_64`, 126.191.776 bytes.

`builds.json` registra sus tamaños y hashes SHA-256. Los ejecutables incluyen Level Testing y el santuario.

La suite `test_level_testing.gd` se ejecutó como script externo sobre cada ejecutable exportado, usando su PCK embebido y directorios de trabajo/datos temporales. Pasaron **25/25 comprobaciones en Windows nativo con OpenGL Compatibility** y **25/25 en Linux headless**: menú, selector, aparición, movilidad, agua, colisiones, pausa, reinicio, regreso y aislamiento de récords. Ambos procesos terminaron con código 0 y sin errores de script. Windows conserva el aviso de recursos al cerrar Godot. Los resultados están en `native_smoke.json`; estos checks del santuario no equivalen a volver a validar todos los modos anteriores.

Los binarios permanecen en `builds/`, excluido de Git. Se versionan el código, las pruebas, las capturas, la visión narrativa y los informes.
