# Bestia desatada y giro compacto

Esta iteración del giro compacto se conserva. La hoja ouroboros actual y las salidas de ejecución están documentadas en [liquid_ouroboros_art.md](liquid_ouroboros_art.md).

Generadas con la herramienta integrada `image_gen`, con transparencia real. Se conserva intacta la primera hoja `assets/sprites/player/viridy/viridy_liquid_beast.png`.

Nuevos recursos del juego:
- `assets/sprites/player/viridy/viridy_liquid_beast_v2.png`: dos mordidas abiertas y dos poses cerradas de mascado, en cuadrícula 2 × 2; ojos blancos rasgados, fauces y materia líquida más deformadas.
- `assets/sprites/player/viridy/viridy_liquid_spin.png`: cuatro fases internas de una silueta compacta enrollada sobre sí misma, compartidas por el screw attack y la ejecución aérea.

Ambas hojas tienen 1254 × 1254 px y celdas de 627 px. La cabeza v2 se recorta a 588 px de alto en la fila abierta y 446 px en la fila cerrada. El giro usa las celdas completas para mantener un pivote fijo, con un canvas de 100 px en juego. Los recortes y la rotación se aplican mediante AtlasTexture y AnimatedSprite2D; los PNG generados no se modifican.

La variante alargada se usa en el heavy terrestre y aéreo y en la recuperación del heavy terrestre; todas las capturas del Ruby usan ahora el giro compacto. El giro compacto rota sobre su centro: durante la ejecución aérea ese centro se coloca en el Ruby. El sprite no orbita alrededor de la boca de la cabeza alargada. El screw conserva las brasas y las llamas de estilo; los frontflips normales mantienen su animación original. Daño, colisiones, duración de captura y rebotes se conservan.

## Prompt de la cabeza v2

Use case: stylized-concept. Create a NEW v2 animation sprite sheet for Viridy's liquid-lion heavy bite, using the attached sheet as a reference for palette and arcade rendering ONLY, not a layout to copy unchanged. User requests more feral, less civilized, less anthropomorphic, more like the terrifying elongated liquid beast-head attack silhouette in 1990s Marvel vs Capcom Venom. Original GREEN ALCHEMICAL LION identity, not Venom character. Entire body is one stretched predatory head of liquid dark emerald matter, with elongated leonine muzzle and long reptilian-free feline jaws, huge ivory fangs, backward-ripping liquid mane. Visibly STRETCH THE SKULL AND JAWS FORWARD: muzzle and jaws much longer than in reference; not merely a normal round lion head with a mane behind it. A feral mouth pulling the entire fluid body into a teardrop, thick liquid ribbons rather than decorative groomed hair. Eyes are glaring solid WHITE WITHOUT pupils, long very narrow jagged torn slashes, uneven fractured outline, extreme uncontrolled animal fury. Facial skin stretches and tears into angular white-eye streaks; no friendly eyes, no human brow expression, no human body, no armor, no knife. Dark forest and emerald body, lime green highlights, ivory teeth, black mouth, minimal dark red inside mouth. Detailed 1990s fighting-game pixel sprite, crisp dark outlines and clustered shading, not smooth vector illustration. ONE transparent PNG sprite sheet in equal 2x2 square cells, four consistent same-size side-view sprites facing RIGHT. Top left: elongated jaws open on windup. Top right: fully stretched forward attack with huge OPEN jaws. Bottom left: SAME long feral head with jaws CLOSED gripping an invisible core. Bottom right: same jaws CLOSED and compressed for chewing, subtly different cheek and jaw shape. All four muzzle tips same relative location; eyes still visible on closed frames. Every sprite entirely within its own cell, at least 12 percent EMPTY TRANSPARENT padding on ALL sides of each cell, no stray droplet near any cell boundary. Absolutely no captions, text, labels, visible grid, background, ground, shadows or colored aura. Do not draw the Ruby: game renders it. True alpha transparency. Keep current reference assets intact; this is a new iteration.

## Corrección de espaciado

undefined

## Prompt del giro compacto

undefined
