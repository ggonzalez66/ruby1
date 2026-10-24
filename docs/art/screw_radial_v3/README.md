# Screw attack: melena radial

Variante `viridy_screw_radial_v3.png`: seis poses frontales con tentáculos detrás del cuerpo que también se extienden por los lados y por debajo de los pies. Se conservan `viridy_screw_front_v2.png`, el screw lateral y todas las tandas anteriores.

Generación: OpenAI `image_gen`, editando la hoja frontal aprobada. `prompts.json` conserva el prompt exacto y las rutas originales. Acabado local: Stable Diffusion XL `sd_xl_base_1.0.safetensors`, VAE fp16 fix, 12 pasos DPM++ 2M Karras, CFG 3, denoise 0,12, semilla 801 y mezcla RGB del 18 %, restaurando el alfa de origen. El archivo de trabajo completo está en `/home/ggonzalez66/ruby1_referencias/screw_radial_v3_20261024/`.

Las celdas originales de 512 × 512 se escalan uniformemente a 720 × 720 con unos 24 px de margen en celdas de 768 × 768. Se separan primero las seis siluetas y se incluyen 16 px adicionales alrededor de cada celda original para conservar las puntas que sobrepasan ligeramente la cuadrícula. No se realinean según la longitud de la melena: así el cuerpo mantiene su posición mientras crecen los tentáculos. La hoja final mide 4608 × 768. El torso se alinea con el centro del remolino en Godot; el ouroboros de las ejecuciones conserva su alineación independiente.

La duración del ataque sigue siendo 0,34 s. No cambian física, daño, hitboxes, cancelaciones ni el VFX circular existente.

```bash
python3 tools/art/refine_viridy.py docs/art/screw_radial_v3/prompts.json /ruta/refined
python3 tools/art/assemble_screw_radial.py /ruta/refined/screw_radial.png
RUBY1_SKIP_COUNTDOWN=1 godot --path . --rendering-method gl_compatibility --audio-driver Dummy -s res://tools/art/capture_refresh.gd -- res://docs/art/screw_radial_v3/runtime
```

`index.html` compara ambas animaciones, `comparison.png` muestra sus seis poses y `runtime/screw.png` muestra la nueva variante con el shader y el remolino en juego. `validation.json` registra las comprobaciones.
