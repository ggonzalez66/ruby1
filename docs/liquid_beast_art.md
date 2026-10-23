# Bestia líquida de Viridy

Esta primera iteración se conserva como referencia. La variante activa y el giro compacto están documentados en [liquid_beast_v2_art.md](liquid_beast_v2_art.md).

Generado con la herramienta integrada `image_gen`, con transparencia real. Recurso del juego:
`assets/sprites/player/viridy/viridy_liquid_beast.png` (1254 × 1254, cuadrícula 2 × 2).

Referencias: los sprites actuales `viridy_ground_heavy.png` y `viridy_idle.png` para identidad y paleta;
las dos imágenes aportadas por el usuario para la silueta de transformación líquida y los ojos furiosos.

La fila superior contiene dos mordidas abiertas. La inferior contiene dos poses cerradas de mascado.
Godot usa celdas de 627 px, recortadas a 557 px de alto para las poses abiertas y 419 px para las cerradas,
para apoyar el dibujo en el suelo sin modificar el archivo original. La orientación aérea se aplica en
el sprite; la animación de captura gira alrededor de la boca alineada con el Ruby. El resto de los
frontflips conserva su sprite habitual. No cambian las colisiones ni los tiempos del ataque.

## Prompt inicial

Use case: stylized-concept. Create ONE production game sprite sheet, a new transformation animation asset for Viridy, an original green alchemical lion warrior in a side-scrolling action game. Input reference roles: first two supplied Venom sheets demonstrate ONLY the liquid stretched beast-head attack silhouette and ferocious broken-shaped eyes; final two green lion sheets define Viridy's colors, leonine face, mane and detailed arcade pixel-art rendering. NOT a blue Venom, no spider marks. Viridy's ENTIRE body liquefies into a large elongated lion-head teardrop: broad feline nose and muzzle at the RIGHT, massive jaws, ivory fangs, mane dissolving into tapering dark emerald liquid ribbons toward the LEFT. No humanoid arms, legs, torso, clothing or knives in this transformed shape. Jade/emerald body, pale yellow-green highlights and mane flowing backward, dark forest shadows; furiously jagged pale slit eyes like torn cracks with dark angular brow, unmistakably lion muzzle and mane rather than reptile. Crisp 1990s arcade sprite shading and strong dark outlines matching the green reference. Four closely consistent animation poses in a precise 2x2 grid, same scale and orientation, equal square cells. TOP LEFT: jaws open, compact windup. TOP RIGHT: longer forward lunge with jaws extremely wide open ready to bite, head still reads lion. BOTTOM LEFT: jaws CLOSED clamped on invisible core, teeth interlocked, cheek compressed. BOTTOM RIGHT: jaws still CLOSED, chewing compression, cheek and mane slightly squash, tightly angry eyes. Lower two are distinct subtle chewing frames of same character, not open mouth. All four face strictly right in side view, horizontal direction. Mouth midpoint at same position in each cell, silhouette fits completely inside each cell with at least 10 percent transparent margin. Genuine transparent background, isolated sprites, no ground, no shadows or glows, no lettering, no grid lines, no labels, no extra objects or red ruby drawn in mouth (engine supplies it), no particles that cross cells. Aim for 1536x1536 square sheet.

## Corrección final de espaciado

Edit this exact sprite sheet for game-ready spacing. Preserve the four green liquid lion designs, pixel art, colors, side-facing RIGHT orientation, and poses (top row two OPEN jaw bite attacks, bottom row two CLOSED jaw chewing poses). Keep exactly FOUR poses in a precise equal 2x2 grid. Shrink each entire sprite including every small droplet so it is comfortably inside its own quarter of the image with at least 12 percent of that cell width EMPTY TRANSPARENT padding on the left AND right, top AND bottom. No particle or outline may touch the edge of its quarter or overlap adjacent cells. Make all heads consistent size; align the muzzle tips horizontally to the same relative x within each cell and same approximate head center y. This is a spacing and alignment correction, preserve character art. No captions, no visible grid, no background, genuine alpha transparency.
