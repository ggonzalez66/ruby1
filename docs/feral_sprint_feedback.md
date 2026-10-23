# Carrera feroz y ajustes de lectura

Hoja nueva: `assets/sprites/player/viridy/viridy_sprint_feral.png`, seis poses a 16 fps. Generada con la herramienta integrada `image_gen`, con las hojas originales como referencias; las versiones anteriores se conservan. Recorte y alineación mediante AtlasTexture, sin editar píxeles con Python.

## Prompt exacto

```text
Use case: stylized-concept game sprite animation. Reference 1 is the ORIGINAL sprint of Viridy and sets the aggressive forward lean and sprite identity; reference 2 sets his face and armor. Create a NEW SIX-FRAME FULL RUN CYCLE for this exact green alchemical LION warrior. The previous iteration was rejected for looking like a mild jog. This must look FERAL, FURIOUS, EXPLOSIVE, CHARGING TO MAUL prey. Torso leans sharply forwards, 40 degrees down from upright, head thrust forward LOW ahead of shoulders, shoulders hunched, snarling lion muzzle with fangs fully bared and mouth OPEN, eyes narrowed in rage, mane swept violently BACK nearly horizontal, claws TENSE and open, arms drive powerfully backwards/forwards, huge bounding leg extensions with compressed recoil then explosive push. Remain a bipedal armored lion, preserve green skin, green flame mane, dark bronze shoulder armor, wraps, brown waist cloth, long tail. No liquid transformation, no knives, no calm smiling expression, no upright jogging. Readable pixel clusters matching old arcade reference, NOT soft polished illustration. All poses FACE RIGHT. Full anatomical alternation: frames 1/2/3 NEAR leg drives forward then plants then pushes BACK, FAR arm drives forward; frames 4/5/6 FAR leg drives forward/plant/push while NEAR leg extends BEHIND to LEFT and NEAR arm drives forward. Distinguish bright near leg versus dark far leg. Maintain same head angle, proportions, size, foot baseline across all frames. EXACT sprite sheet layout 3 columns x 2 rows on 1536x1024 transparent sheet; each sprite fully within its own 512x512 cell, maximum width380px and maximum height330px, centered horizontally in cell, soles baseline at y430 within cell. Large transparent gutters at least60px horizontally so no sprites overlap. All mane and tail tips inside cell. Transparent background alpha zero, no background colors, no painted green halo, no floor, no dust or effects, no text, no grid. Preserve earlier assets; this is a new iteration.
```

## HUD y uppercut

El velocímetro ocupa una línea pequeña bajo la vida, con una barra de 2 píxeles, menos opacidad al detenerse y un signo + discreto si hay bonus de estilo. Usa la escala de presentación de 32 unidades de mundo por metro: carrera base = 63 km/h y screw de 1240 unidades/s = 140 km/h. La conversión solo afecta el texto.

El uppercut inicia el flip normal 0,18 s antes del ápice. El giro dura 0,24 s, conserva la gravedad y termina entrando en caída al aerial stall. La salida de ejecución aérea mantiene su propia transición.

## Opciones del campo de fuerza

Muestras en `docs/audio_previews/index.html`, regenerables con `python3 tools/generate_hum_previews.py`. A: 53,25 Hz; B: 106,5 Hz; C: textura grave sin nota definida. A y B son transposiciones artísticas de la anterior afinación de 852 Hz, sin afirmar una frecuencia oficial de Metatrón. Los tres bucles duran cuatro segundos, sin pulsación añadida ni vibrato, con nivel RMS comparable. `docs/audio_previews/.gdignore` mantiene los ejemplos fuera de las exportaciones del juego.


Selección final del usuario: B, grave cálido de 106,5 Hz, constante y sin pulsación. Cambiar `SELECTED` en `tools/forcefield_hum.py` y ejecutar `python3 tools/generate_sfx.py shine_hold` aplica otra opción.
