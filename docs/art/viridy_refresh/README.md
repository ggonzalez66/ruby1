# Viridy: tanda arcade

Arte generado con la herramienta integrada OpenAI `image_gen`, usando el Viridy original como identidad y las referencias locales indicadas por el usuario como guía de poses. No se sustituye ningún PNG anterior. Los nuevos archivos llevan el sufijo `_arcade`.

Abrir `index.html` para reproducir las hojas, variar la velocidad y recorrer los frames. `contact.png` reúne las poses. `prompts.json` conserva los prompts exactos y la procedencia de cada generación; la primera propuesta completa de carrera no se usa entera, solo su primera mitad, combinada con la generación de braceo opuesto.

| Hoja | Poses | Uso |
| --- | ---: | --- |
| `viridy_run_arcade.png` | 6 | Carrera: apoyo, paso y vuelo para cada mitad del ciclo; alternancia de brazos. |
| `viridy_walk_arcade.png` | 8 | Caminata baja con referencia de Venom. |
| `viridy_dash_claw_arcade.png` | 4 | Preparación, extensión, barrido y recuperación del dash attack. |
| `viridy_liquid_beast_arcade.png` | 4 | Dos mordidas abiertas y dos poses de mascado; heavy aéreo y salidas de ejecución. |
| `viridy_ground_heavy_arcade.png` | 4 | Extensión del cuerpo y separación de la bestia. |
| `viridy_heavy_remnant_arcade.png` | 1 | Parte abandonada en el punto de partida, sin colisión. |
| `viridy_hurt_arcade.png` | 3 | Reacción al daño durante el bloqueo de control existente. |
| `viridy_screw_arcade.png` | 6 | Cuerpo fijo en el aire; crecimiento y flexión de púas de la melena. |
| `viridy_light1_arcade.png` | 4 | Zarpazo horizontal, referencia Wolverine light1. |
| `viridy_light2_arcade.png` | 4 | Barrido diagonal ascendente, referencia Wolverine light2. |
| `viridy_light3_arcade.png` | 3 | Remate desde los brazos cruzados sobre la cabeza, referencia Wolverine light3. |

## Acabado local y reproducción

ComfyUI en Windows, `sd_xl_base_1.0.safetensors` + `sdxl_vae_fp16_fix.safetensors`. Se refinó cada hoja completa con img2img, denoise 0,12, 12 pasos DPM++ 2M Karras, CFG 3, semillas 801–811, lado máximo aproximado de 1024 px. Se mezcló un 18 % del RGB refinado sobre la imagen OpenAI, restaurando su alfa y eliminando únicamente el halo de alfa inferior a 160. No se empleó interpolación ni generación automática de frames intermedios. Esta pasada no usa la LoRA de edificios/objetos.

Los originales OpenAI, hojas refinadas, salidas SDXL íntegras y grafos API quedan en `/home/ggonzalez66/ruby1_referencias/animation_refresh_20261024/`. Los originales de `image_gen` también siguen en su ubicación de generación. No se borraron variantes previas.

```bash
python3 tools/art/refine_viridy.py docs/art/viridy_refresh/prompts.json /ruta/refined
python3 tools/art/assemble_viridy.py /ruta/refined
```

El ensamblador separa los componentes alfa de cada pose, incluso cuando sus rectángulos se solapan, y alinea los apoyos. La parte abandonada del tercer frame del heavy se separa del personaje móvil. `atlases.json` documenta las celdas finales. El shader jade existente iguala el pigmento verde y conserva ojos, dientes, armadura y telas.

## Integración y ritmos

La duración, daño, hitboxes, velocidades, cooldowns, hitstop, rebotes y ventanas de cancelación no cambian. Las animaciones de ataques y daño se sincronizan con sus temporizadores de física. El heavy terrestre sigue durando 0,14 s; su salida líquida visual dura como máximo 0,09 s adicionales y cualquier acción permitida la reemplaza inmediatamente. El remanente se desvanece en el mundo y se elimina solo.

La carrera conserva el período de 1/3 s; los dos apoyos duran más que las poses de paso. La caminata conserva 12 fps y ocho frames. La reacción al daño utiliza los 0,25 s de aturdimiento existentes y no se muestra al resistir con Imparable. El screw mantiene el lanzamiento, cancelaciones, hitbox y remolino; solo deja de rotar el sprite del cuerpo. La ejecución aérea conserva el ouroboros anterior en una animación independiente `ruby_spin`.

Los fantasmas guardados adaptan escala y posición de las animaciones renovadas sin cambiar su trayectoria ni sus tiempos. Los registros antiguos que llaman `spin` al ouroboros muestran la pose nueva del screw; los registros nuevos distinguen `ruby_spin`.

Las referencias y las vistas de revisión se excluyen de los ejecutables.
