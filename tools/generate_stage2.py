#!/usr/bin/env python3
"""Genera stage2.tscn: Etapa 2 · La Jungla Profunda (después de vencer al guardián de la torre).

Uso: python3 tools/generate_stage2.py   (desde la raíz del proyecto)

Etapa horizontal hacia la derecha con desnivel, hecha con piezas de las mismas medidas que la torre
(pozo de running walljumps, ritmo de bunnyhop, fosos con dummies para rebotar):
- Suelo bajo (y = 0, x 0..4200): foso de espinas con dummies aéreos, perseguidores, un tirador en alto
  y un sol; al final, el pozo que sube al acantilado.
- Acantilado (y = -1100, x 4200..7000): espinas al ritmo del bunnyhop, una pared de wallride y más
  enemigos. Al final se salta abajo, a la arena.
- Arena (y = 0, x 7000..9600): uno de los dos guardianes que no cayeron en la torre.
"""

from level_kit import *  # noqa: F401,F403 (escena S, recursos y helpers comunes)

WIDTH = 9600
TOP = -1800
CLIFF_X = 4200
CLIFF_END = 7000
T = Tower(WIDTH, 1100)
LOW = T.G(1)
HIGH = T.G(2)

# Atardecer: entre el cielo de la base y el de la cima.
background(altitude_offset=0.5)

block("BoundaryLeft", -60, 0, TOP - 60, 360, WALL)
block("BoundaryRight", WIDTH, WIDTH + 60, TOP - 60, 360, CLIMB_WALL)
block("BoundaryTop", -60, WIDTH + 60, TOP - 60, TOP, SLAB_STYLE)
floor_title("TitleStage2", 140, LOW - 460, "ETAPA 2 · LA JUNGLA PROFUNDA")

# ---------------------------------------------------------------- Suelo bajo
PIT = (700, 1300)
block("GroundStart", 0, PIT[0], LOW, LOW + 300)
block("PitFloor", PIT[0], PIT[1], LOW + 110, LOW + 300)
thorns("PitThorns", PIT[0], PIT[1], LOW + 110)
block("GroundLow", PIT[1], CLIFF_X, LOW, LOW + 300)

checkpoint("CheckpointStart", 150, LOW)
sign("SignStage2", 400, LOW, "Etapa 2", "La jungla profunda: sin más carteles de técnica.\nCruza el foso rebotando en los dummies (o con salto largo + frontflip) y sube por el pozo del acantilado.", 360)
for index, bx in enumerate([830, 1000, 1170]):
    dummy(f"DummyPitBounce{index + 1}", bx, LOW - 130 - (index % 2) * 40, aerial=True, max_health=60)
chaser("ChaserLowA", 1650, LOW)
chaser("ChaserLowB", 1950, LOW)
platform("ShooterPlatformLow", 2250, 2450, LOW - 210)
shooter("ShooterLow", 2350, LOW - 210, (-1, 0.25), 2.6, shine_chance=0.3)
S.node("SunLow", None, {"position": vec(2800, LOW - 180)}, instance=SUN)
chaser("ChaserLowC", 3150, LOW)
chaser("ChaserLowD", 3400, LOW)
checkpoint("CheckpointShaft", 3550, LOW)

# Pozo de running walljumps (346 de ancho, entrada de 140) contra la cara del acantilado. Como en la
# torre, una pared sigue más arriba que la salida: desde ella el último salto cae sobre el acantilado.
block("ShaftWall", CLIFF_X - 386, CLIFF_X - 346, HIGH - 400, LOW - 140, CLIMB_WALL)
block("Cliff", CLIFF_X, CLIFF_END, HIGH, LOW + 300)
block("CliffFace", CLIFF_X, CLIFF_X + 40, HIGH, LOW, CLIMB_WALL)
block("CliffDrop", CLIFF_END - 40, CLIFF_END, HIGH, LOW, WALL)

# ---------------------------------------------------------------- Acantilado
checkpoint("CheckpointCliff", 4450, HIGH)
T.bunny_strips(2, 4750, 3, 1)
chaser("ChaserHighA", 6000, HIGH)
block("CliffWallrideWall", 6250, 6450, HIGH - 180, HIGH, CLIMB_WALL)
shooter("ShooterHigh", 6650, HIGH - 260, (-1, 0.2), 2.8, True, shine_chance=0.3)
sign("SignGuardian", 6820, HIGH, "Abajo", "El siguiente guardián te espera en la arena.\nSalta cuando estés listo.", 320)

# ---------------------------------------------------------------- Arena
block("ArenaGround", CLIFF_END, WIDTH, LOW, LOW + 300)
checkpoint("CheckpointArena", 7350, LOW)
platform("ArenaLowA", 7900, 8100, LOW - 170)
platform("ArenaMid", 8350, 8600, LOW - 330)
platform("ArenaLowB", 8850, 9050, LOW - 170)
S.node("BossSpawner", "Node2D", {
    "script": f'ExtResource("{SPAWNER}")',
    "spawn_point": vec(8550, LOW),
    "arena_min_x": "7500",
    "arena_max_x": "9500",
    "forced_boss": "4",
    "trio_chance": "0",
    "entry_from_left": "true",
})

# ---------------------------------------------------------------- Rengar, HUD y menús
player_and_ui(220, LOW - 2, {"title_text": '"ETAPA 2 COMPLETADA"', "next_scene": '"res://stage3.tscn"'})

S.write(PROJECT / "stage2.tscn")
print("stage2.tscn generado con", len(S.nodes), "nodos")
