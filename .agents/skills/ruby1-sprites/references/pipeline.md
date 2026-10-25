# Pipeline de arte de Ruby1

Las rutas de esta referencia parten de la raíz del proyecto. Trabajar con una carpeta nueva por tanda; conservar originales, acabado y selección final. Leer únicamente la documentación de la familia de assets que corresponda.

## Referencias y herramientas

| Necesidad | Recurso existente |
| --- | --- |
| Identidad original de Viridy | `assets/sprites/player/Viridis.png`, `assets/sprites/player/viridy/viridy_idle.png` |
| Referencias de poses del usuario | `assets/sprites/references/venom/`, `assets/sprites/references/wolverine/` (locales, sin seguimiento) |
| Selección y escala activas | `movimiento.gd`: `_configure_character_animations()`, `_align_character_animation()`, `_update_character_orientation()`, `ANIMATION_VISUAL_SCALES`, `JADE_SHEETS` |
| Acabado OpenAI → SDXL | `tools/art/refine_viridy.py`, conexión en `tools/viridy.py` |
| Separación y normalización | `tools/normalize_sheet.py`, `tools/art/assemble_viridy.py` |
| Ensambladores de tandas específicas | `tools/art/assemble_feedback_v2.py`, `tools/art/assemble_screw_radial.py`, `tools/art/assemble_wrath.py` |
| Shader jade | `shaders/charge_glow.gdshader` |
| Historial de sprite, prompt, atlas y capturas | `docs/art/viridy_refresh/`, `docs/art/viridy_feedback_v2/`, `docs/art/screw_radial_v3/`, `docs/wrath_nature/` |

Los ensambladores específicos escriben nombres fijos y algunos contienen excepciones para una hoja concreta. No son convertidores genéricos. Elegir uno compatible, adaptarlo para la tanda nueva o usar el normalizador; inspeccionar las rutas de salida antes de ejecutarlo.

## Generación y acabado

Usar OpenAI para diseñar las poses, con imágenes de identidad y pose ya inspeccionadas. Mantener alfa real y espaciar siluetas completas dentro de cada celda. Guardar el prompt y el archivo original generado antes de cualquier acabado.

El acabado existente importa `tools/viridy.py`: `comfy_server()` detecta la puerta de enlace de WSL y usa el puerto 8188 de ComfyUI en Windows. Comprobar una consulta HTTP corta, por ejemplo `/system_stats`, y consultar `/object_info/CheckpointLoaderSimple` y `/object_info/VAELoader` antes de enviar el trabajo. Si la detección falla, investigar la conexión existente; no abrir puertos ni cambiar el firewall como parte rutinaria del arte.

`refine_viridy.py` usa actualmente SDXL base (`sd_xl_base_1.0.safetensors`), VAE `sdxl_vae_fp16_fix.safetensors`, 12 pasos, CFG 3, DPM++ 2M Karras, denoise 0,12 y mezcla RGB 18 %. Restaura el alfa tras descartar valores inferiores a 160. Son parámetros de acabado conservador; comparar detalles finos y no aplicar ese umbral a un VFX translúcido sin revisar el resultado. El script guarda entrada preparada, grafo, salida SDXL y mezcla final.

Su manifiesto JSON es una lista de objetos con `name` y `source` (ruta al original). `kind: "effect"` activa el prompt de VFX; por defecto trata personajes. `prompt` y `openai_original` pueden conservar la procedencia, como en los manifiestos históricos. El script omite un nombre cuyo PNG de destino ya existe: usar una carpeta nueva para comparar parámetros sin reutilizar una salida anterior.

```bash
python3 tools/art/refine_viridy.py /ruta/tanda/prompts.json /ruta/tanda/refined
```

## Atlas y ritmo

Usar vecino más cercano en reescalados de pixel art. Comprobar alfa, puntas, fragmentos sueltos y bordes entre celdas. Aplicar un factor coherente al ciclo; elegir un ancla de acción estable en vez de normalizar el tamaño por cada frame.

`tools/normalize_sheet.py --help` explica su formato de salida de 768 × 768, `--frames`, `--filas`, `--animacion` o `--alto`, y `--vista-previa`. Ese formato no se impone al resto de hojas: el juego también usa celdas de 512 × 512, 768 × 512 y otras. Conservar dimensiones, recortes, márgenes y escalas coherentes al registrar el atlas.

Tomar el período y las duraciones de los frames del código actual. La carrera usa apoyos ponderados: añadir dibujos no requiere acelerar o ralentizar el ciclo. Los cambios de frame no deben controlar por sí solos ventanas de combate. El screw y `ruby_spin` se registran como animaciones distintas.

## Importación y revisión en juego

Importar con `godot --headless --path . --import`, que espera a finalizar la importación. Revisar los `.import` nuevos y ejecutar `test_sprites.gd` y `test_art_refresh.gd` con datos temporales según `AGENTS.md`. Añadir `test_combos.gd` cuando la integración afecte transiciones; usar `test_feedback_v2.gd` para las estelas iniciales del screw.

Las capturas requieren ventana/rendering activo. Ejemplo con carpeta nueva y solo las poses pertinentes:

```bash
(
  qa_data=$(mktemp -d)
  trap 'rm -rf -- "$qa_data"' EXIT
  RUBY1_SKIP_COUNTDOWN=1 XDG_DATA_HOME="$qa_data" godot --path . --rendering-method gl_compatibility --audio-driver Dummy -s res://tools/art/capture_refresh.gd -- res://docs/art/nueva_tanda/runtime run,walk,dash
)
```

Otras poses admitidas incluyen `heavy`, `heavy_close`, `heavy_recovery`, `screw`, `light1`, `light2`, `light3` y `hurt`. Para Wrath, usar `tools/art/capture_wrath.gd`; su opción `-- --feedback-only` captura marca jade de jefe y opciones en una escena limpia. Revisar cada herramienta antes de usarla: algunas capturas tienen un destino fijo.

Inspeccionar los PNG con el visor de imágenes y, cuando el ritmo importe, revisar el ciclo o la transición en movimiento. Comparar facing izquierdo/derecho, primer frame, retorno a idle/carrera, shader y VFX. Guardar una hoja de contacto o comparación si ayuda a decidir, sin sustituir la revisión a escala de juego.
