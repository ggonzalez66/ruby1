#!/usr/bin/env python3
"""Genera stage3.tscn: Etapa 3 · La Cima (la última, después de vencer al guardián de la etapa 2).

Uso: python3 tools/generate_stage3.py   (desde la raíz del proyecto)

Torre compacta de 3 pisos, más exigente y sin carteles de técnica, con las piezas de la torre de la
etapa 1 (mismas medidas: fosos, ritmo de bunnyhop, pozo, escalera, pared de backflip y de wallride):
- Piso 1 (→): fosos, bunnyhop, un sol sobre un foso, tiradores que shinean más a menudo, la pared
  del backflip y el pozo de subida.
- Piso 2 (←): fosos con dummies para rebotar, pared de wallride, perseguidores y tiradores; sube por
  la escalera.
- Piso 3 (→): la arena del último guardián (a veces, los tres juntos como gran final).
"""

from level_kit import *  # noqa: F401,F403 (escena S, recursos y helpers comunes)

WIDTH = 7000
FLOORS = 3
T = Tower(WIDTH, 1100)
G = T.G
TOP = G(FLOORS + 1)
SHOOTER_SHINE = 0.35

# La cima: el cielo se va calentando al subir.
background(altitude_offset=0.6)

block("BoundaryLeft", -60, 0, TOP - 60, 360, WALL)
block("BoundaryRight", WIDTH, WIDTH + 60, TOP - 60, 360, CLIMB_WALL)
block("BoundaryTop", -60, WIDTH + 60, TOP - 60, TOP, SLAB_STYLE)

# ================================================================ PISO 1 (→)
g = G(1)
floor_title("TitleStage3", 140, g - 460, "ETAPA 3 · LA CIMA")
PITS = [(1500, 1800), (3700, 4050)]
x = 0
for a, b in PITS + [(WIDTH, WIDTH)]:
    block(unique("F1Ground"), x, a, g, g + 300)
    x = b
for a, b in PITS:
    block(unique("F1PitFloor"), a, b, g + 110, g + 300)
    thorns(unique("F1PitThorns"), a, b, g + 110)

checkpoint("CheckpointStart", 150, g)
sign("SignStage3", 400, g, "Etapa 3", "La cima. Los tiradores de aquí devuelven tus disparos más a menudo.\nArriba espera el último guardián.", 340)
chaser("ChaserF1A", 900, g)
chaser("ChaserF1B", 1150, g)
platform("F1ShooterPlatform", 2050, 2250, g - 210)
shooter("ShooterF1A", 2150, g - 210, (-1, 0.25), 2.4, shine_chance=SHOOTER_SHINE)
T.bunny_strips(1, 2500, 3, 1)
S.node("SunF1", None, {"position": vec(3875, g - 260)}, instance=SUN)
checkpoint("CheckpointF1Mid", 4300, g)
chaser("ChaserF1C", 4650, g)
chaser("ChaserF1D", 4900, g)
block("F1BackflipLedge", 5300, 5450, g - 270, g, WALL)
shooter("ShooterF1B", 5750, g, (-1, 0), 2.4, shine_chance=SHOOTER_SHINE)
checkpoint("CheckpointF1Shaft", 6200, g)
T.shaft(1, "right")

# ================================================================ PISO 2 (←)
g = G(2)
F2_PITS = [(4300, 4800), (1700, 2200)]
T.slab_with_gaps(2, [(WIDTH - 386, WIDTH)] + F2_PITS)
for a, b in F2_PITS:
    T.thorn_pit(2, a, b)
checkpoint("CheckpointF2", 6350, g)
chaser("ChaserF2A", 5800, g)
for index, bx in enumerate([4450, 4650]):
    dummy(f"DummyF2Bounce{index + 1}", bx, g - 140 - index * 40, aerial=True, max_health=60)
block("F2WallrideWall", 3500, 3700, g - 180, g, CLIMB_WALL)
shooter("ShooterF2A", 3100, g - 260, (1, 0.2), 2.6, True, shine_chance=SHOOTER_SHINE)
chaser("ChaserF2B", 2750, g)
chaser("ChaserF2C", 2500, g)
chaser("ChaserF2D", 1300, g)
checkpoint("CheckpointF2Stairs", 900, g)
T.stairs(2, 10, 440, "left")

# ================================================================ PISO 3 · ARENA (→)
g = G(3)
T.slab_with_gaps(3, [(0, 520)])
checkpoint("CheckpointArena", 650, g)
sign("SignLastGuardian", 900, g, "El último guardián", "El que queda por vencer... aunque a veces, como gran final, vuelven los tres a la vez.", 340)
platform("ArenaLowA", 2500, 2720, g - 170)
platform("ArenaHighA", 2850, 3010, g - 480)
platform("ArenaMid", 4150, 4430, g - 320)
platform("ArenaHighB", 5400, 5560, g - 480)
platform("ArenaLowB", 5700, 5920, g - 170)
S.node("BossSpawner", "Node2D", {
    "script": f'ExtResource("{SPAWNER}")',
    "spawn_point": vec(4300, g),
    "arena_min_x": "1500",
    "arena_max_x": "6800",
    "forced_boss": "4",
    "trio_chance": "0.2",
    "trio_health_factor": "0.75",
    "entry_from_left": "true",
})

# ---------------------------------------------------------------- Rengar, HUD y menús
player_and_ui(220, G(1) - 2, {"title_text": '"ETAPA 3 COMPLETADA"', "next_scene": '"res://stage4.tscn"'})

S.write(PROJECT / "stage3.tscn")
print("stage3.tscn generado con", len(S.nodes), "nodos")
