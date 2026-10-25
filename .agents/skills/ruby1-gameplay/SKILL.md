---
name: ruby1-gameplay
description: "Modificar y depurar movimiento, combate, enemigos y colisiones en Ruby1 (Godot/GDScript), conservando timings y cancelaciones cuando corresponda. Usar para bunnyhop, uppercut, heavy, screw, parry, ejecuciones, fuego jade, Wrath o problemas de sus interacciones. Para trabajo exclusivamente de sprites, usar ruby1-sprites."
---

# Ruby1 Gameplay

## Ubicar el trabajo

Resolver la ruta real de esta carpeta; la raíz de Ruby1 está tres niveles arriba (`../../..`). Comprobar `project.godot` y `movimiento.gd`, y leer su `AGENTS.md`. Un enlace en la instalación personal de Codex apunta a esta misma copia versionada.

Usar esta skill para implementar o investigar comportamiento del juego. Si el encargo también crea o integra arte, consultar `ruby1-sprites` para esa parte. No convertir una revisión estética en un rebalanceo.

## Entender y reproducir

1. Identificar el resultado que pide el usuario y la interacción que debe conservarse. Para bugs, registrar modo, suelo/aire, dirección, carrera, inputs y estado enemigo. Reproducir con inputs reales cuando el problema dependa de su orden; llamar solo a una función interna no comprueba el enrutamiento del input.
2. Seguir input → transición de estado → movimiento/impacto → recuperación. Empezar en `movimiento.gd` y saltar al módulo correspondiente según `AGENTS.md`. Verificar exports de la escena, no solo defaults del script.
3. Separar el reloj de gameplay del de presentación. Revisar condiciones de entrada, cooldowns, prioridades y cancelaciones, además del frame visible. Obtener los valores actuales del código; los documentos de tandas antiguas pueden describir reglas sustituidas.

## Implementar conservando el flow

- En un cambio visual, mantener tiempos, daño, alcance, velocidad y permisos de acción. En un cambio mecánico pedido, modificar la regla necesaria y sus interacciones directas.
- El uppercut y las salidas de ejecución pueden seguir dibujando un flip mientras otra acción ya está disponible. No añadir un bloqueo basado en `animation_finished` para resolver una transición visual ni restaurar buffers de ejecución eliminados sin una petición de gameplay.
- Distinguir invulnerabilidad, Imparable y captura de Ruby. Usar las consultas del sistema existente; no extender i-frames para disimular errores de presentación. Wrath distingue carga, READY, AIM y avance.
- El heavy ordinario reclama un Ruby que ya estaba open antes del impacto. El crítico y el remate de jefe tienen resultados distintos. Wrath es la excepción que puede ejecutar jefes con vida; conservar esa diferencia al reutilizar lógica.
- Los enemigos usan `Area2D` como hurtbox. Un cambio directo de `position` no resuelve terreno: para desplazamientos rápidos, empujes y lanzamientos consultar el volumen barrido. `enemy_launch_motion.gd` es la utilidad existente para enemigos; el terreno usa capa 2. Revisar también visión y daño a través de paredes.
- El fuego jade y Soul pull hacen cero daño; la marca temporal y la stasis deben restaurar los materiales, estados y controles al consumirse, morir, reiniciar o cambiar de escena. Detener los bucles de audio en las salidas y cancelaciones correspondientes.
- Mantener el orden de actualización de presentación antes de copiar afterimages. Al entrar a screw desde suelo o pared, alinear textura, escala y orientación antes de generar la primera estela.

## Verificar y entregar

Consultar [references/validation.md](references/validation.md) para elegir pruebas y comandos. Añadir una regresión de comportamiento cuando el fallo lo justifique; comprobar entradas, resultados y límites, sin tests que solo reproduzcan la implementación.

Para un ajuste de sensación, comparar el caso pedido y la transición contigua con el mismo escenario e inputs. Para rendimiento, usar `tools/profile_sky_stairs.gd` o el profiler con dibujo activo y comparar en el mismo equipo y renderer.

Revisar el diff para detectar cambios accidentales de timings. Informar qué cambió, qué pruebas se ejecutaron y qué depende aún de una valoración al jugar. Aplicar las instrucciones vigentes de entrega; esta skill no impone exportaciones o publicaciones adicionales.
