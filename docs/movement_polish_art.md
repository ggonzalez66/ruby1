# Movimiento, VFX y sonido — octubre 2026

Revisión posterior: la carrera actual es `viridy_sprint_feral.png`, el medidor usa km/h, el uppercut comienza el flip antes del ápice y el hum se sustituyó por un campo grave constante. Detalles y nuevos prompts: [carrera feroz y ajustes](feral_sprint_feedback.md). Los prompts siguientes documentan la iteración anterior.

Arte generado con la herramienta integrada `image_gen` en modo de edición con referencias locales y transparencia. Los PNG originales de Viridy se conservan. Las regiones y márgenes de AtlasTexture mantienen escala y apoyo; no se modificaron imágenes con Python.

Activos finales:
- `assets/sprites/player/viridy/viridy_walk_v2.png`: 8 poses, 12 fps.
- `assets/sprites/player/viridy/viridy_sprint_v2.png`: 6 poses, 14 fps.
- `assets/sprites/player/viridy/viridy_liquid_dash.png`: 2 poses exclusivas, 18 fps.
- `assets/sprites/player/viridy/viridy_liquid_landing.png`: squash y recuperación, 20 fps durante 0.1 s.

## Prompts exactos

### sprint_cycle

Referencia: `/var/www/godot_projects/ruby1/assets/sprites/player/viridy/viridy_sprint.png`

```text
Use case: stylized-concept. Create a NEW complete SIX-FRAME sprint cycle sprite sheet for the exact green alchemical lion warrior Viridy shown in the reference. Preserve pixel-art face, green flowing mane, green skin, dark bronze shoulder armor, brown waist cloth, wrist wraps, leg wraps, tail and proportions. Side view, ALL SIX face RIGHT throughout. The problem to FIX is that the old reference always presents the same leading arm and same leading leg. The new cycle MUST physically alternate left/right limbs through a FULL stride, not mirror the whole character or repeat the same leg. Layout EXACT 3 columns by 2 rows read left-to-right top-to-bottom. Frames 1-3: camera-near leg leads forward then plants then pushes back, opposite far arm leads forward. Frames 4-6: camera-FAR leg leads forward then plants then pushes back, camera-NEAR arm leads forward while the NEAR leg clearly extends BEHIND the hips. Maintain a clear distinct dark FAR leg behind the lighter NEAR leg so swapping overlap is unmistakable. In frame 2 near foot is planted AHEAD of hip and far foot lifted behind; in frame 5 far foot planted ahead and near foot extends BEHIND. Contralateral arms alternate equally: forward fist changes from far to near arm halfway. Sprint low leaned-forward with broad leg extension, readable foot contacts, fluid mane and tail continuing backward. No weapons, no duplicate arms or feet. Detailed arcade pixel clusters like reference, not smooth illustration. Every frame SAME body scale and feet baseline, SAME head orientation, silhouette fully isolated inside equal cells, at least 12 percent transparent margin in each cell. Genuine transparent background, no ground, no dust, no text, no numbers, no grid. Prefer landscape sheet 1536x1024 with six equal square cells. This is a new asset; keep reference unchanged.
```

### walk_cycle

Referencia: `/var/www/godot_projects/ruby1/assets/sprites/player/viridy/viridy_walk.png`

```text
Use case: stylized-concept. Create a NEW full EIGHT-FRAME walk cycle sprite sheet for EXACT green lion warrior Viridy from reference. Preserve his face, green mane and fur, dark bronze shoulder armor, brown waist cloth, bracers and leg wraps, tail, crisp detailed 1990s arcade pixel art. All eight poses face RIGHT in side view; no changes of facing. Critical correction: old sheet repeats the SAME leading leg and arm. Make a real FULL alternating gait: frames 1-4 NEAR leg contact ahead -> down -> passing under hips -> up; frames 5-8 FAR leg contact ahead -> down -> passing -> up. During far-leg contact at frame 5 the NEAR leg is stretched BEHIND the hips, with dark FAR leg clearly visible ahead. Near and far arms swing in opposite directions to the respective legs: the camera-near fist must go fully backward then fully forward between halves. Do not just mirror whole sprites; torso and head still face RIGHT. Show both complete legs with correct depth/occlusion. Layout EXACT 4 columns x 2 rows, sequential eight poses. Calm purposeful walking, body upright, consistent body scale and head position, modest vertical bob, tail and mane move subtly. Grounded contact baseline same within all cells. No blades, no dust, no effects. Maintain consistent distinct near/far limb shading so alternating contact can be read at game size. All silhouettes fit completely inside their equal cells with generous transparent margin at least 10 percent each side; no stray pixels at cell edges. True alpha transparent background, no ground, no labels, no numbers, no grid. Wide sprite sheet about 2048x1024, eight square cells. Preserve original asset.
```

### beast_dash

Referencia: `/var/www/godot_projects/ruby1/assets/sprites/player/viridy/viridy_liquid_beast_v2.png`

```text
Use case: stylized-concept. Design a NEW dedicated liquid-beast DASH sprite sheet for Viridy. Reference defines dark emerald liquid lion identity, lime highlights, fierce torn WHITE pupil-less eyes, ivory teeth and arcade pixel shading. This is a DIFFERENT anatomical pose from the open-jaw heavy bite: a sleek aerodynamic predatory lion TORPEDO, low narrow wedge-shaped skull, jaws tightly clenched with fangs tucked against the muzzle, brow lowered, mane folds into swept-back thick liquid ribbons around a streamlined stretched body ending in a sharp tapered tail. No circular body and NO giant open bite. Entire body transformed, no humanoid limbs, no knife or armor. Two animation poses, exactly two equal square cells in ONE HORIZONTAL ROW: left condensed launch/compression torpedo, right strongly stretched forward burst torpedo, both face RIGHT, same fierce eyes and same head scale, correct lion nose. Clearly new dash silhouette with compact closed mouth. Keep muzzle tip and centerline aligned between frames. Crisply shaded arcade sprite matching reference palette. All sprite and droplets entirely inside each cell with at least 15 percent EMPTY TRANSPARENT margin on each side, no aura, no standalone motion trails, no ground, no labels, no text. True transparent alpha, landscape 2:1 sheet. Original reference unchanged.
```

### beast_landing

Referencia: `/var/www/godot_projects/ruby1/assets/sprites/player/viridy/viridy_liquid_beast_v2.png`

```text
Use case: stylized-concept. Create a NEW two-frame LIQUID BEAST LANDING SQUASH sprite sheet for Viridy after a falling heavy attack. Reference defines his emerald liquid lion head, lime highlights, jagged angry WHITE eyes, ivory fangs, detailed arcade pixel-art outlines and clustered shading. The head is now SQUASHED against the floor into a wide compressed living liquid puddle, not the normal head reused, not a humanoid landing and no knife. Distinct feline face at RIGHT end, muzzle and jaws CLOSED, eyes still furiously glaring. Mane and chin mass splat laterally into thick fluid lobes and flatten underneath. Frame 1 is the strong impact squash: about HALF the normal vertical head height, wide and low liquid silhouette, compressed cheeks and flattening mane. Frame 2 recovers slightly upward, still flattened to about TWO THIRDS normal height, preserving the SAME horizontal scale and same feet/chin baseline. Two equal square cells in ONE horizontal row, both face RIGHT, body centered at same x, clear difference in squash. No actual floor line; isolated transparent sprite, lower visible contour of both sprites same y in each cell. At least 15 percent EMPTY TRANSPARENT padding all cell sides, no outlying dust or particles crossing boundaries, no Ruby drawn. No limbs, weapons, armor, ground, glows, labels, numbers or grid. True alpha transparency, crisp detailed fighting-game pixel sprite. This is a new sibling asset; preserve source.
```

### Iteraciones de sprint

```text
Edit this 6-frame sprite sheet. KEEP character identity, green lion Viridy, armor, pixel shading, RIGHT-facing direction and exact 3 columns x 2 rows layout. REMOVE ALL THE DARK GREEN BACKGROUND AND HALO completely so background is truly transparent alpha 0, including between limbs and tail. Each frame must have exactly the same scale and baseline. CRITICAL: swap the limb poses in the ENTIRE SECOND ROW: the NEAR leg (bright, visible thigh) must extend BACKWARDS and the FAR dark leg must lead FORWARDS, with NEAR arm leading forwards and FAR arm back. First row near leg leads, second row far leg leads. This must be a true alternating left/right running gait, not repeating the same leg lead in both rows. No glow outside character, no floor, no background shading, no text. Preserve 1536x1024 3x2 equal grid.
```

```text
Create a sprite sheet of this exact GREEN LION WARRIOR (Viridy), based on the attached WALK sprite reference. Change WALK to a FAST RUN, six frames, 3 columns by 2 rows, each square cell 512px, sheet1536x1024. CRITICAL fully transparent background alpha zero as in this reference, NO GREEN BACKGROUND, NO GRADIENT, NO GLOW, no shadows, no ground. Six independent right-facing sprites all centered and padded. FIRST ROW: NEAR (visible bright) LEG FORWARD and FAR leg behind, with near arm BEHIND and far arm forward, poses contact / down / passing. SECOND ROW: NEAR bright LEG BEHIND (extends toward LEFT) and FAR dark LEG FORWARD (extends toward RIGHT), with near arm FORWARD, far arm BEHIND, poses contact / down / passing. Need clear alternate leg and arm, not repeated pose. Distinct hips, knees, elbows showing alternating depth. Same scale and near horizontal sprint lean, same calm fierce lion face, mane, brown armor and cloth, pixel art shading. No weapons, no lettering, no framing. Use reference colors not oversaturated neon.
```

```text
Fix this 6-frame sprite sheet for a game. Keep EXACT Viridy lion design and the 6 pose concepts. Main correction: EVERY sprite must fit inside its own 512x512 cell in a 1536x1024 sheet (3 columns x 2 rows), with MINIMUM 80 PIXELS TRANSPARENT PADDING at the LEFT AND RIGHT of EVERY CELL. Shrink each character to MAXIMUM WIDTH 350px and MAXIMUM HEIGHT 350px. Leave a large empty transparent gap between all sprites; NO OVERLAP across any cell border. All feet same baseline at y=430 in each cell; character centered x=256 in eachcell. Keep background fully transparent alpha0. Keep first row near arm back; second row near arm forward. In second row the NEAR bright leg must be extended backwards to LEFT while the FAR dark leg extends forwards to RIGHT to show opposite contact phase. Right-facing running ONLY. No text or grid or floor or glow. This is an atlas layout correction with generous transparent gutters.
```

La última iteración da más espacio entre poses para que no entren fragmentos de la celda vecina.

## Ajustes de juego

La velocidad horizontal se presenta en km/h, con escala visual de 32 unidades de mundo por metro. Sobre la carrera base (560 px/s), el bonus aumenta linealmente hasta +24 estilo/s a 1400 px/s; el movimiento no asciende más allá de S. El screw lanza a un mínimo de 1240 px/s, o añade 220 px/s si el impulso previo era mayor. Mantener correr permite llevarlo al bunnyhop.

Uppercut: pose original de puñetazo ascendente (`viridy_uppercut.png`), giro normal de 0,24 s que comienza 0,18 s antes del ápice, con gravedad continua y entrada en aerial stall ya cayendo. El combo queda disponible a los 0,35 s desde el inicio; el heavy puede interrumpir la subida o el flip estético.

El VFX del screw usa tres espirales con radio creciente. El parry añade tres ondas durante su ventana inicial y un rugido sintetizado original con ±12 % de pitch. El humming actual usa un campo de fuerza grave y constante; las opciones de escucha y la afinación seleccionada están en `tools/forcefield_hum.py` y `docs/feral_sprint_feedback.md`. Receta reproducible: `python3 tools/generate_sfx.py shine_hold roar_parry`.

## Escalera al cielo

18 fosos, de 3600 a 6150 px, cada uno 150 px más largo. Los apoyos quedan separados por un máximo de 310 px; la dificultad aumenta con más rebotes, islas más estrechas y movimiento de voladores. Hay checkpoints, pinchos de retorno bajo cada foso y pinchos en el frente inferior de cada isla para impedir el atajo de trepar desde abajo. El cronómetro sigue al volver al checkpoint. El Top 10 y fantasma se guardan por separado de las cuatro etapas de la torre; llegar al sol cierra la medición antes de la fusión. `python3 tools/generate_sky_stairs.py` regenera la escena de forma determinista.


Validación: `tests/run_tests.sh` (672 comprobaciones), `RUBY1_REACH_QUICK=1 RUBY1_SKIP_COUNTDOWN=1 godot --headless --fixed-fps 60 --path . -s res://tests/reach/test_sky_reach.gd` (busca una cadena física válida en cada tramo) y `godot --headless --fixed-fps 60 --path . -s res://tests/reach/test_sky_no_bounce.gd` (tres intentos sin apoyos). La opción rápida termina la búsqueda de cada salto en cuanto encuentra un plan válido; sin ella se exploran los tipos de rebote y fases alternativos.
