#!/usr/bin/env python3
"""Genera sun_world.tscn: el mundo espiritual dentro del sol (final de la run, tras la Araña Colosal).

Uso: python3 tools/generate_sun_world.py   (desde la raíz del proyecto)

Todo del color del sol. Seis pisos de plataformeo apilados (se sube zigzagueando) y un séptimo piso
dedicado al Ruby, con él en el centro. La lava (lava.gd) devuelve al último checkpoint sin quitar vida;
cada piso empieza con un checkpoint.
- Piso 1 · L→R: islas que se caen (plataformas que se desmoronan al pisarlas). Sube rebotando en espíritus.
- Piso 2 · R→L: rebotes sobre la lava (espíritus quietos). Sube por una escalera que se derrumba.
- Piso 3 · L→R: espíritus que se mueven y plataformas que caen. Sube por una chimenea de walljumps.
- Piso 4 · R→L: cadena de plataformas que caen con géiseres de lava en los huecos. Sube rebotando en
  espíritus que se mueven.
- Piso 5 · L→R: géiseres entre plataformas pequeñas y espíritus. Sube por una escalera que se derrumba.
- Piso 6 · R→L: la prueba final, todo mezclado. Sube por una chimenea de walljumps.
- Piso 7: la cámara del Ruby, centrado sobre su pedestal.
"""

from level_kit import *  # noqa: F401,F403 (escena S, recursos y helpers comunes)

W = 3200
FH = 640
FLOORS = 7
TOP = -(FLOORS - 1) * FH - 760
COLUMN = 360
LAVA = S.ext_res("Script", "res://lava.gd", "20_lava")
FALLING = S.ext_res("Script", "res://falling_platform.gd", "21_falling")
GEYSER = S.ext_res("Script", "res://lava_geyser.gd", "22_geyser")
SUN_BACKGROUND = S.ext_res("Script", "res://sun_background.gd", "23_sunbg")
RUBY = S.ext_res("Script", "res://ruby_crystal.gd", "15_ruby")
# Pálidos y fríos: se leen bien contra el naranja del sol.
SPIRIT = color(0.7, 0.92, 1.25)


def G(n):
    """Altura del suelo del piso n (1..7)."""
    return -(n - 1) * FH


S.node("SunBackground", "ParallaxBackground", {"script": f'ExtResource("{SUN_BACKGROUND}")', "world_height": f"{-TOP:g}"})
block("BoundaryLeft", -60, 0, TOP, 360, SUN_STYLE)
block("BoundaryRight", W, W + 60, TOP, 360, SUN_STYLE)
block("BoundaryTop", -60, W + 60, TOP - 60, TOP, SUN_STYLE)


def island(n, a, b):
    y = G(n)
    block(unique(f"F{n}Island"), a, b, y, y + (300 if n == 1 else 60), SUN_STYLE)


def trench(n, a, b):
    """Foso de lava entre a y b: la superficie queda 80 px bajo el suelo del piso."""
    y = G(n)
    bottom = y + (300 if n == 1 else 170)
    block(unique(f"F{n}TrenchBed"), a - 40, b + 40, y + 120, bottom, SUN_STYLE)
    if n > 1:
        block(unique(f"F{n}TrenchSide"), a - 40, a, y + 60, y + 120, SUN_STYLE)
        block(unique(f"F{n}TrenchSide"), b, b + 40, y + 60, y + 120, SUN_STYLE)
    S.node(unique(f"F{n}Lava"), "Area2D", {
        "position": vec((a + b) / 2, y + 80), "script": f'ExtResource("{LAVA}")',
        "size": vec(b - a, 40),
    })


def stone(n, x, dy, width=150):
    """Plataforma fija de piedra solar (dy: altura sobre el suelo del piso, negativa = arriba)."""
    y = G(n) + dy
    block(unique(f"F{n}Stone"), x - width / 2, x + width / 2, y, y + 24, SUN_STYLE)


def falling(n, x, dy, width=140):
    S.node(unique(f"F{n}Falling"), "StaticBody2D", {
        "position": vec(x, G(n) + dy + 12), "script": f'ExtResource("{FALLING}")', "size": vec(width, 24),
    })


def geyser(n, x, phase=0.0, period=3.2):
    S.node(unique(f"F{n}Geyser"), "Area2D", {
        "position": vec(x, G(n) + 80), "script": f'ExtResource("{GEYSER}")',
        "phase": f"{phase:g}", "period": f"{period:g}", "height": "380",
    })


def spirit(n, x, dy, **props):
    """Espíritu del sol (dummy volador invencible) para rebotar con el heavy."""
    dummy(unique(f"F{n}Spirit"), x, G(n) + dy, aerial=True, max_health=9999, modulate=SPIRIT, **props)


def shaft(n, side):
    """Chimenea de walljumps de 180 de ancho en la columna de subida, hasta el piso n + 1."""
    top = G(n + 1)
    bottom = G(n) - 140
    if side == "right":
        block(f"F{n}ShaftWall", W - 240, W - 180, top, bottom, SUN_STYLE)
    else:
        block(f"F{n}ShaftWall", 180, 240, top, bottom, SUN_STYLE)


def title(n, x, text):
    floor_title(f"TitleFloor{n}", x, G(n) - 520, text)


# ---------------------------------------------------------------- Piso 1 · islas que se caen
island(1, 0, 420)
trench(1, 420, W - 560)
island(1, W - 560, W)
checkpoint("CheckpointFloor1", 200, G(1))
title(1, 140, "DENTRO DEL SOL · PISO 1 · ISLAS QUE SE CAEN")
sign("SignSun", 330, 0, "Dentro del sol", "La lava te devuelve al último checkpoint.\nLas piedras agrietadas se desmoronan al pisarlas: no te detengas.\nRebota con {heavy_attack} en los espíritus; con {move_down} en picado rebotas más alto.", 400)
for index, (x, dy, kind) in enumerate([(600, -40, "stone"), (860, -80, "fall"), (1120, -120, "fall"), (1380, -60, "stone"),
                                        (1640, -110, "fall"), (1900, -150, "fall"), (2160, -90, "fall"), (2420, -50, "stone")]):
    (stone if kind == "stone" else falling)(1, x, dy)
# Subida 1 → 2 (columna derecha): espíritus quietos en zigzag.
for x, dy in [(3020, -150), (2900, -300), (3060, -450), (2940, -600)]:
    spirit(1, x, dy)

# ---------------------------------------------------------------- Piso 2 · rebotes sobre la lava
island(2, W - 900, W - COLUMN)
trench(2, 560, W - 900)
island(2, 0, 560)
checkpoint("CheckpointFloor2", W - 600, G(2))
title(2, 1200, "PISO 2 · REBOTES SOBRE LA LAVA")
for x, dy in [(2120, -160), (1840, -200), (1560, -170), (1270, -210), (990, -180), (720, -160)]:
    spirit(2, x, dy)
# Subida 2 → 3 (columna izquierda): escalera que se derrumba.
for x, dy in [(250, -130), (100, -270), (250, -410), (100, -550)]:
    falling(2, x, dy, 120)

# ---------------------------------------------------------------- Piso 3 · todo se mueve
island(3, COLUMN, 900)
trench(3, 900, W - 560)
island(3, W - 560, W)
checkpoint("CheckpointFloor3", 600, G(3))
title(3, 900, "PISO 3 · TODO SE MUEVE")
falling(3, 1080, -60)
spirit(3, 1350, -180, move_offset=(0, -90), move_period=2.4)
falling(3, 1610, -80)
spirit(3, 1880, -190, orbit_radius=60.0, move_period=3.0)
spirit(3, 2170, -170, move_offset=(140, 0), move_period=3.0)
falling(3, 2450, -60)
shaft(3, "right")

# ---------------------------------------------------------------- Piso 4 · cadena que cae y géiseres
island(4, W - 900, W - COLUMN)
trench(4, 560, W - 900)
island(4, 0, 560)
checkpoint("CheckpointFloor4", W - 600, G(4))
title(4, 1100, "PISO 4 · LA CADENA QUE CAE")
for index, x in enumerate(range(2160, 640, -215)):
    falling(4, x, -40 - (index % 2) * 30, 130)
for index, x in enumerate([1945, 1300, 870]):
    geyser(4, x + 107, phase=index * 1.1)
# Subida 4 → 5 (columna izquierda): espíritus que se mueven.
spirit(4, 220, -150, move_offset=(0, -60), move_period=2.2)
spirit(4, 90, -310)
spirit(4, 250, -460, orbit_radius=40.0, move_period=2.8)
spirit(4, 100, -600)

# ---------------------------------------------------------------- Piso 5 · géiseres
island(5, COLUMN, 900)
trench(5, 900, W - 560)
island(5, W - 560, W)
checkpoint("CheckpointFloor5", 600, G(5))
title(5, 900, "PISO 5 · GÉISERES")
stone(5, 1050, -40, 110)
geyser(5, 1200, phase=0.0)
stone(5, 1360, -60, 110)
spirit(5, 1610, -180)
geyser(5, 1760, phase=1.6)
stone(5, 1910, -80, 110)
spirit(5, 2150, -190, move_offset=(0, 80), move_period=2.6)
geyser(5, 2300, phase=0.8)
stone(5, 2450, -60, 110)
# Subida 5 → 6 (columna derecha): escalera que se derrumba.
for x, dy in [(2950, -130), (3100, -270), (2950, -410), (3100, -550)]:
    falling(5, x, dy, 120)

# ---------------------------------------------------------------- Piso 6 · la prueba final
island(6, W - 900, W - COLUMN)
trench(6, 560, W - 900)
island(6, 0, 560)
checkpoint("CheckpointFloor6", W - 600, G(6))
title(6, 1100, "PISO 6 · LA PRUEBA FINAL")
falling(6, 2160, -50, 130)
spirit(6, 1930, -190, move_offset=(0, -80), move_period=2.2)
falling(6, 1700, -90, 120)
geyser(6, 1560, phase=0.5, period=2.6)
spirit(6, 1400, -200, orbit_radius=55.0, move_period=2.6)
falling(6, 1150, -70, 120)
spirit(6, 920, -180, move_offset=(120, 0), move_period=2.4)
stone(6, 700, -50, 110)
shaft(6, "left")

# ---------------------------------------------------------------- Piso 7 · la cámara del Ruby
island(7, COLUMN, W)
checkpoint("CheckpointRuby", 520, G(7))
floor_title("TitleRuby", 1250, G(7) - 640, "EL CORAZÓN DEL SOL")
block("RubyPedestalStep", W / 2 - 310, W / 2 + 310, G(7) - 80, G(7), SUN_STYLE)
block("RubyPedestal", W / 2 - 140, W / 2 + 140, G(7) - 180, G(7) - 80, SUN_STYLE)
S.node("Ruby1", "Area2D", {"position": vec(W / 2, G(7) - 180), "script": f'ExtResource("{RUBY}")'})

# ---------------------------------------------------------------- Viridy, HUD y menús
player_and_ui(200, -2, {
    "title_text": '"RUBY1"',
    "message_text": '"Te fundiste con el Ruby1 en el corazón del sol."',
    "final_screen": "true",
})

S.write(PROJECT / "sun_world.tscn")
print("sun_world.tscn generado con", len(S.nodes), "nodos")
