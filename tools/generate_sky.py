#!/usr/bin/env python3
"""Genera sky_stairs.tscn: Escalera al Cielo (modo del menú principal, sin combate).

Uso: python3 tools/generate_sky.py   (desde la raíz del proyecto)

Plataformeo puro hacia arriba y a la derecha: pilares cada vez más altos sobre un suelo de espinas
(tocarlas devuelve al último checkpoint) y voladores para rebotar con el heavy. Se encadenan tramos con
las mismas medidas relativas que los de la etapa final (ya comprobados con la búsqueda de recorrido):
- C (escalera): cuatro voladores que suben ~160 px cada uno hasta un pilar 700 px más alto.
- A (cadena): cinco voladores quietos a la misma altura hasta el pilar siguiente.
- B (móviles): cuatro voladores que se mueven (suben y bajan, van y vienen, orbitan).
Al final, el sol: al tocarlo, Rengar se funde con él y termina la etapa.
"""

from level_kit import *  # noqa: F401,F403 (escena S, recursos y helpers comunes)

FLYER_HEALTH = 9999
THORN_DAMAGE = 20
SEGMENTS = ["C", "A", "C", "B", "C", "C"]
GOAL = S.ext_res("Script", "res://ruby_crystal.gd", "15_goal")


def flyer(name, x, y, **props):
    dummy(name, x, y, aerial=True, max_health=FLYER_HEALTH, **props)


# Primero se calcula el recorrido (islas y voladores) para saber el ancho y la altura.
START = (0, 450, 0)
islands = []  # (nombre, x0, x1, top)
flyers = []   # (nombre, x, y, props)
edge, top = START[1], START[2]
for index, kind in enumerate(SEGMENTS):
    n = index + 1
    if kind == "C":
        for i, (dx, dy) in enumerate([(200, -170), (450, -330), (700, -480), (950, -640)]):
            flyers.append((f"Seg{n}F{i + 1}", edge + dx, top + dy, {}))
        islands.append((f"Seg{n}Land", edge + 1100, edge + 1400, top - 700))
        edge, top = edge + 1400, top - 700
    elif kind == "A":
        for i, (dx, dy) in enumerate([(170, -150), (450, -190), (750, -150), (1050, -200), (1330, -160)]):
            flyers.append((f"Seg{n}F{i + 1}", edge + dx, top + dy, {}))
        islands.append((f"Seg{n}Land", edge + 1450, edge + 1700, top))
        edge = edge + 1700
    elif kind == "B":
        flyers.append((f"Seg{n}F1", edge + 250, top - 170, {"move_offset": (0, -90), "move_period": 2.4}))
        flyers.append((f"Seg{n}F2", edge + 600, top - 200, {"move_offset": (140, 0), "move_period": 3.0}))
        flyers.append((f"Seg{n}F3", edge + 950, top - 160, {"orbit_radius": 60.0, "move_period": 3.0}))
        flyers.append((f"Seg{n}F4", edge + 1300, top - 220, {"move_offset": (0, 110), "move_period": 2.2, "move_phase": 0.5}))
        islands.append((f"Seg{n}Land", edge + 1550, edge + 1800, top))
        edge = edge + 1800
FINAL = ("FinalIsland", edge, edge + 800, top)
WIDTH = edge + 800
TOP = top - 1300

# Cuanto más arriba, más cálido el cielo (el sol está en la cima).
background(altitude_offset=0.45)
block("BoundaryLeft", -60, 0, TOP - 60, 360, WALL)
block("BoundaryRight", WIDTH, WIDTH + 60, TOP - 60, 360, WALL)
block("BoundaryTop", -60, WIDTH + 60, TOP - 60, TOP, SLAB_STYLE)
floor_title("TitleSky", 140, -460, "ESCALERA AL CIELO")
# Suelo de espinas bajo todo el recorrido (los pilares se dibujan encima).
block("ThornFloor", 0, WIDTH, 110, 300)
thorns("ThornsAll", 0, WIDTH, 110, THORN_DAMAGE, to_checkpoint=True)

block("StartIsland", START[0], START[1], START[2], 300)
checkpoint("CheckpointStart", 150, 0)
sign("SignSky", 320, 0, "Escalera al Cielo", "Sin combate: solo subir. Las espinas te devuelven al último checkpoint.\nRebota con {heavy_attack} en los voladores; mantén {dash} para ir hacia delante, y con {move_down} en picado rebotas más alto.", 380)
for name, x0, x1, island_top in islands + [FINAL]:
    block(name, x0, x1, island_top, 300)
    checkpoint(f"Checkpoint{name}", (x0 + x1) / 2 - (60 if name == "FinalIsland" else 0), island_top)
for name, x, y, props in flyers:
    flyer(name, x, y, **props)
S.node("Sun", "Area2D", {
    "position": vec(FINAL[1] + 450, FINAL[3]),
    "script": f'ExtResource("{GOAL}")',
    "goal_style": '"sun"',
})

player_and_ui(220, -2, {
    "title_text": '"ESCALERA AL CIELO"',
    "message_text": '"Subiste hasta el sol y te fundiste con él."',
    "final_screen": "true",
})

S.write(PROJECT / "sky_stairs.tscn")
print("sky_stairs.tscn generado con", len(S.nodes), "nodos; ancho", WIDTH, "alto", -top)
