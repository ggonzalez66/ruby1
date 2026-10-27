#!/usr/bin/env python3
"""Genera gauntlet.tscn: el Gauntlet por oleadas.

Uso: python3 tools/generate_gauntlet.py   (desde la raíz del proyecto)

Un solo piso con el suelo en y = 0: Rengar empieza a la izquierda y la arena (x 1400..4400) es un
espacio despejado con plataformas flotantes y la pared del fondo para wallrides (los guardianes no
chocan con el escenario, así que lo acrobático está en el aire). El director de oleadas
(gauntlet_director.gd) lleva las rondas: oleada de enemigos normales, después el guardián (a veces los
tres) y, al ganar, portales para seguir (derecha) o terminar (izquierda).
"""

from level_kit import *  # noqa: F401,F403 (escena S, recursos y helpers comunes)

WIDTH = 4400
TOP = -1500
ARENA_MIN = 1800
ARENA_MAX = 4300
DIRECTOR = S.ext_res("Script", "res://gauntlet_director.gd", "16_director")

# El cielo de la cima de la torre: es la sala de los guardianes.
background(altitude_offset=1.0)

# Contorno: pared izquierda, pared del fondo con enredaderas (wallride) y techo.
block("BoundaryLeft", -60, 0, TOP - 60, 360, WALL)
block("BoundaryRight", WIDTH, WIDTH + 60, TOP - 60, 360, CLIMB_WALL)
block("BoundaryTop", -60, WIDTH + 60, TOP - 60, TOP, SLAB_STYLE)
block("Ground", 0, WIDTH, 0, 300)

floor_title("TitleGauntlet", 140, -460, "GAUNTLET · OLEADAS")

# ---------------------------------------------------------------- Inicio
checkpoint("CheckpointStart", 120, 0)
sign("SignGauntlet", 60, 0, "Gauntlet", "Elige un arma suspendida con {move_up}. El portal azul inicia el reloj y la primera oleada.\nAcaba con los enemigos y después con el guardián.\nAl ganar, el portal de la derecha sigue a la siguiente ronda y el de la izquierda termina.", 380)

# ---------------------------------------------------------------- Arena
# Plataformas a dos alturas: las bajas se alcanzan con un salto (y agarre), las altas desde ellas.
platform("ArenaLowA", 2250, 2470, -170)
platform("ArenaLowB", 3780, 4000, -170)
platform("ArenaMid", 2980, 3260, -320)
platform("ArenaHighA", 2600, 2760, -480)
platform("ArenaHighB", 3480, 3640, -480)
# Más arriba: subida en zigzag por los dos lados (cada nivel 160 px más alto, a doble salto y agarre
# del anterior) hasta una plataforma en lo alto del centro.
platform("ArenaLeftLow", 1550, 1750, -170)
platform("ArenaLeftMid", 1850, 2010, -330)
platform("ArenaTier4L", 2300, 2460, -640)
platform("ArenaTier4C", 3040, 3200, -640)
platform("ArenaTier4R", 3780, 3940, -640)
platform("ArenaTier5L", 2620, 2780, -800)
platform("ArenaTier5R", 3460, 3620, -800)
platform("ArenaTier6C", 2960, 3240, -960)
platform("ArenaTier6L", 2300, 2440, -960)
platform("ArenaTier6R", 3800, 3940, -960)
platform("ArenaTier7L", 2620, 2760, -1120)
platform("ArenaTier7R", 3480, 3620, -1120)
platform("ArenaTop", 2900, 3060, -1280)
S.node("BossSpawner", "Node2D", {
    "script": f'ExtResource("{SPAWNER}")',
    "spawn_point": vec(3150, 0),
    "arena_min_x": f"{ARENA_MIN:g}",
    "arena_max_x": f"{ARENA_MAX:g}",
    "forced_boss": "-1",
    "trio_chance": "0.25",
    "auto_spawn": "false",
    "entry_from_left": "true",
})
S.node("GauntletDirector", "Node2D", {
    "script": f'ExtResource("{DIRECTOR}")',
    "arena_min_x": "1400",
    "arena_max_x": "4100",
    "spawner_path": 'NodePath("../BossSpawner")',
    "left_portal_x": "600",
    "right_portal_x": "4150",
})

# ---------------------------------------------------------------- Rengar, HUD y menús
player_and_ui(220, -2, {"title_text": '"GAUNTLET COMPLETADO"', "final_screen": "true"})

S.write(PROJECT / "gauntlet.tscn")
print("gauntlet.tscn generado con", len(S.nodes), "nodos")
