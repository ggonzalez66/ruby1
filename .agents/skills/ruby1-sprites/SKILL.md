---
name: ruby1-sprites
description: "Crear, preparar e integrar sprites y animaciones de Ruby1 con identidad jade de Viridy, versiones conservadas y revisión en Godot. Usar para hojas, frames, poses, ciclos, liquid beast, escalas, pivotes y transiciones visuales; combina generación OpenAI y acabado SDXL cuando la tarea lo requiere. Para reglas de combate o movimiento, usar ruby1-gameplay."
---

# Ruby1 Sprites

## Ubicar y delimitar

Resolver la ruta real de esta carpeta; la raíz de Ruby1 está tres niveles arriba (`../../..`). Comprobar `project.godot` y leer `AGENTS.md`. Consultar `movimiento.gd` para identificar el asset y la animación activos antes de elegir referencias. `docs/art/` también contiene propuestas anteriores.

Aplicar esta skill a creación, preparación, integración y corrección visual de sprites. Para una tarea mixta con cambios mecánicos, consultar `ruby1-gameplay`. No generar imágenes nuevas si basta ajustar un atlas, una escala, un ancla o una selección de frames existentes.

## Definir la tanda

- Inspeccionar el sprite activo y las referencias locales relevantes. Separar identidad, pose, secuencia y VFX; una referencia de Venom o Wolverine aporta la acción solicitada, mientras la identidad es Viridy.
- Mantener el jade del personaje original, melena, armadura y vendas según las referencias aprobadas. Revisar con `shaders/charge_glow.gdshader`: `JADE_SHEETS` puede aplicar una corrección adicional en juego.
- Para carrera normal, conservar boca cerrada, manos empuñadas y alternancia real de brazos y piernas. La cantidad de frames es una decisión de la tanda; conservar el ritmo de apoyos y período si el usuario solo pide arte.
- Distinguir el screw, el giro de ejecución, el uppercut y la bestia alargada: consultar sus animaciones activas; compartir un efecto no implica compartir el mismo sprite.
- Definir dirección, poses clave, número/disposición de frames, transparencia y ancla estable. Para una mordida que captura un Ruby, alinear las fauces; para carrera, los apoyos; para giros, el centro. No centrar cada silueta por separado si provoca saltos de ancla.

## Producir y conservar

Para ilustración o poses nuevas, usar la generación de imágenes de OpenAI y las instrucciones de la skill `imagegen` disponible en el entorno. Inspeccionar los archivos de referencia antes de editar y pedir fondo transparente. Conservar prompt, salida original y copia de trabajo.

Usar el acabado SDXL local para las tareas correspondientes al flujo acordado, con [references/pipeline.md](references/pipeline.md). Comprobar conexión, checkpoint y VAE antes de ejecutar; no tratar una configuración histórica como disponibilidad actual. Si la herramienta falta o falla, explicar el bloqueo concreto y continuar con la preparación o revisión que sea posible, sin afirmar que se completó el acabado.

Crear archivos nuevos con un sufijo de versión identificable; conservar hojas anteriores y propuestas descartadas. Las herramientas de ensamblado de tandas anteriores tienen rutas de salida fijas: inspeccionarlas antes de reutilizarlas para evitar sobrescribir originales.

La generación y las ediciones visuales corresponden al generador de imágenes o al flujo SD autorizado. Reutilizar Python/Pillow para recorte, separación, alfa, empaquetado y normalización existentes; no sustituir una pose nueva por deformaciones de la misma pose ni fabricar alternancia únicamente reflejando todo el personaje.

## Integrar sin cambiar gameplay

1. Revisar dimensiones de celda, regiones y márgenes efectivos. Ruby1 mezcla hojas de varios tamaños; no asumir una cuadrícula universal de 768 px. Reutilizar el helper adecuado de `_configure_character_animations()` en `movimiento.gd`.
2. Ajustar atlas, orden, duración relativa, escala, offset, orientación y shader. Conservar el período visual si procede (`sum(frame_duration) / animation_speed`), los temporizadores de ataque, trayectoria, hitboxes, daño y cooldowns.
3. Mantener la lógica de cancelación independiente del fin visual del flip. Si el arte no puede expresar la mecánica sin cambiarla, explicar el conflicto antes de alterar el funcionamiento solicitado.
4. Alinear el sprite antes de generar afterimages. Revisar el primer frame de cada transición, el facing opuesto, salto desde suelo/pared y retorno al estado normal; una hoja de mayor resolución no debe producir una estela gigante.
5. Para slashes y otras capas, comprobar `z_index`, pivote, reflexión y orientación con el golpe real. Evitar tapar la lectura del cuerpo o mover una hitbox para ajustarla a un dibujo.

## Validación visual y entrega

Seguir los comandos y rutas de [references/pipeline.md](references/pipeline.md). Importar los assets, ejecutar las pruebas de sprites/arte y las de combos cuando cambie una transición. Revisar las capturas del renderer con shader y VFX activos; una hoja o una prueba headless no demuestra el resultado visual.

Registrar la selección final, origen, dimensiones, anclas y capturas en la documentación de la nueva tanda. Distinguir checks automatizados de valoración visual. Incluir únicamente los archivos de esta tarea en la entrega y conservar las referencias locales sin seguimiento.
