#!/usr/bin/env python3
"""Genera gauntlet.tscn: arena abierta contra los tres guardianes a la vez.

Uso: python3 tools/generate_gauntlet.py   (desde la raíz del proyecto)

Un solo piso con el suelo en y = 0, de izquierda a derecha:
- Calentamiento (x 0..1600): centinelas (perseguidores, un tirador en alto y dummies aéreos para
  rebotar), para llegar a la arena con algo de estilo.
- Arena (x 1800..4400): espacio despejado con plataformas flotantes y la pared del fondo para
  wallrides. Los guardianes no chocan con el escenario, por eso el suelo de la arena no tiene
  obstáculos: todo lo acrobático está en el aire.
"""

from level_kit import *  # noqa: F401,F403 (escena S, recursos y helpers comunes)

WIDTH = 4400
TOP = -1500
ARENA_MIN = 1800
ARENA_MAX = 4300

# El cielo de la cima de la torre: es la sala de los guardianes.
background(altitude_offset=1.0)

# Contorno: pared izquierda, pared del fondo con enredaderas (wallride) y techo.
block("BoundaryLeft", -60, 0, TOP - 60, 360, WALL)
block("BoundaryRight", WIDTH, WIDTH + 60, TOP - 60, 360, CLIMB_WALL)
block("BoundaryTop", -60, WIDTH + 60, TOP - 60, TOP, SLAB_STYLE)
block("Ground", 0, WIDTH, 0, 300)

floor_title("TitleGauntlet", 140, -460, "GAUNTLET · LOS TRES GUARDIANES")

# ---------------------------------------------------------------- Calentamiento
checkpoint("CheckpointStart", 120, 0)
sign("SignGauntlet", 360, 0, "Gauntlet", "Los tres guardianes te esperan al fondo.\nCalienta con sus centinelas: el estilo que acumules llega contigo al combate.", 340)
dummy("DummyBounceA", 640, -150, aerial=True, max_health=60)
dummy("DummyBounceB", 860, -190, aerial=True, max_health=60)
chaser("ChaserA", 1050, 0)
platform("ShooterPlatform", 1180, 1380, -210)
shooter("ShooterHigh", 1280, -210, (-1, 0.25), 2.6)
chaser("ChaserB", 1450, 0)

# ---------------------------------------------------------------- Arena
checkpoint("CheckpointArena", 1650, 0)
# Plataformas a dos alturas: las bajas se alcanzan con un salto (y agarre), las altas desde ellas.
platform("ArenaLowA", 2250, 2470, -170)
platform("ArenaLowB", 3780, 4000, -170)
platform("ArenaMid", 2980, 3260, -320)
platform("ArenaHighA", 2600, 2760, -480)
platform("ArenaHighB", 3480, 3640, -480)
S.node("BossSpawner", "Node2D", {
    "script": f'ExtResource("{SPAWNER}")',
    "spawn_point": vec(3150, 0),
    "arena_min_x": f"{ARENA_MIN:g}",
    "arena_max_x": f"{ARENA_MAX:g}",
    "forced_boss": "3",
    "trio_entry_from_left": "true",
})

# ---------------------------------------------------------------- Rengar, HUD y menús
player_and_ui(220, -2, {"title_text": '"GAUNTLET COMPLETADO"'})

S.write(PROJECT / "gauntlet.tscn")
print("gauntlet.tscn generado con", len(S.nodes), "nodos")
