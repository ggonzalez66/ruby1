#!/usr/bin/env python3
"""Genera stage4.tscn: Etapa final · El camino al Ruby (después de vencer al último guardián).

Uso: python3 tools/generate_stage4.py   (desde la raíz del proyecto)

Plataformeo puro y difícil hacia la derecha: fosos de espinas (tocarlas devuelve al último
checkpoint) que solo se cruzan rebotando con el heavy en enemigos voladores. Los rebotes hacia delante
se hacen manteniendo correr (rebote en carrera); en picado (abajo) se rebota más alto.
- Foso 1: voladores quietos, cada vez más separados.
- Foso 2: voladores que se mueven (suben y bajan, van y vienen, orbitan).
- Foso 3: escalera de rebotes que sube a un pilar alto.
- Foso 4: bajada con voladores quietos y móviles hasta la isla final.
- Isla final: chimenea de walljumps con espinas alternadas.
- Piso superior: cámara del Ruby, centrado sobre un pedestal elevado.
"""

from level_kit import *  # noqa: F401,F403 (escena S, recursos y helpers comunes)

WIDTH = 7600
TOP = -2100
FLYER_HEALTH = 9999
THORN_DAMAGE = 20
RUBY = S.ext_res("Script", "res://ruby_crystal.gd", "15_ruby")

# Lo más alto de la jungla: el cielo cálido de la cima.
background(altitude_offset=1.0)

block("BoundaryLeft", -60, 0, TOP - 60, 360, WALL)
block("BoundaryRight", WIDTH, WIDTH + 60, TOP - 60, 360, WALL)
block("BoundaryTop", -60, WIDTH + 60, TOP - 60, TOP, SLAB_STYLE)
floor_title("TitleStage4", 140, -460, "ETAPA FINAL · EL CAMINO AL RUBY")

ISLANDS = [(0, 450), (1900, 2150), (3700, 3950), (7000, WIDTH)]
PITS = [(450, 1900), (2150, 3700), (3950, 5050), (5350, 7000)]
for index, (a, b) in enumerate(ISLANDS):
    block(f"Island{index + 1}", a, b, 0, 300)
for index, (a, b) in enumerate(PITS):
    block(f"PitFloor{index + 1}", a, b, 110, 300)
    thorns(f"PitThorns{index + 1}", a, b, 110, THORN_DAMAGE, to_checkpoint=True)
# Pilar alto entre el foso 3 y el 4: se llega por la escalera de rebotes.
PILLAR = (5050, 5350, -700)
block("Pillar", PILLAR[0], PILLAR[1], PILLAR[2], 300)


def flyer(name, x, y, **props):
    dummy(name, x, y, aerial=True, max_health=FLYER_HEALTH, **props)


# ---------------------------------------------------------------- Foso 1: quietos
checkpoint("CheckpointStart", 150, 0)
sign("SignStage4", 320, 0, "Etapa final", "Solo queda el camino al Ruby. Las espinas te devuelven al último checkpoint.\nRebota con {heavy_attack} en los voladores; mantén {dash} para rebotar hacia delante, y con {move_down} en picado rebotas más alto.", 380)
for index, (bx, by) in enumerate([(620, -150), (900, -190), (1200, -150), (1500, -200), (1780, -160)]):
    flyer(f"FlyerA{index + 1}", bx, by)

# ---------------------------------------------------------------- Foso 2: móviles
checkpoint("CheckpointMoving", 2020, 0)
flyer("FlyerB1", 2400, -170, move_offset=(0, -90), move_period=2.4)
flyer("FlyerB2", 2750, -200, move_offset=(140, 0), move_period=3.0)
flyer("FlyerB3", 3100, -160, orbit_radius=60.0, move_period=3.0)
flyer("FlyerB4", 3450, -220, move_offset=(0, 110), move_period=2.2, move_phase=0.5)

# ---------------------------------------------------------------- Foso 3: escalera al pilar
checkpoint("CheckpointClimb", 3820, 0)
for index, (bx, by) in enumerate([(4150, -170), (4400, -330), (4650, -480), (4900, -640)]):
    flyer(f"FlyerC{index + 1}", bx, by)

# ---------------------------------------------------------------- Foso 4: bajada
checkpoint("CheckpointPillar", 5200, PILLAR[2])
flyer("FlyerD1", 5600, -560)
flyer("FlyerD2", 5900, -430, move_offset=(0, 80), move_period=2.6)
flyer("FlyerD3", 6200, -320)
flyer("FlyerD4", 6500, -450, orbit_radius=50.0, move_period=3.2)
flyer("FlyerD5", 6870, -270)

# ---------------------------------------------------------------- Chimenea y piso exclusivo del Ruby
# La boca ocupa el lugar donde antes estaba la gema. 180 px de ancho permiten
# subir con walljumps normales; las bandas alternadas obligan a elegir el contacto.
checkpoint("CheckpointRuby", 7080, 0)
sign("SignRubyChimney", 7120, 0, "La cámara del Ruby", "Sube por la chimenea con {jump}.\nLas espinas alternan de pared: elige dónde apoyar cada walljump.", 350)
ROOM_Y = -1200
SHAFT_LEFT, SHAFT_RIGHT = 7290, 7470
block("RubyChimneyLeft", SHAFT_LEFT - 60, SHAFT_LEFT, ROOM_Y, -80, WALL)
block("RubyChimneyRight", SHAFT_RIGHT, SHAFT_RIGHT + 60, ROOM_Y, 0, WALL)
block("RubyRoomFloorLeft", 0, SHAFT_LEFT, ROOM_Y, ROOM_Y + 60, SLAB_STYLE)
block("RubyRoomFloorRight", SHAFT_RIGHT, WIDTH, ROOM_Y, ROOM_Y + 60, SLAB_STYLE)
# El borde de la entrada izquierda queda a 80 px del suelo y se puede franquear.
for index, y in enumerate([-300, -700, -1100]):
    S.node(f"RubySpikesLeft{index}", "Area2D", {
        "position": vec(SHAFT_LEFT, y), "rotation": "1.57079632679",
        "script": f'ExtResource("{HAZARD}")', "size": vec(52, 22),
        "damage": 20, "send_to_checkpoint": "true",
    })
for index, y in enumerate([-400, -800]):
    S.node(f"RubySpikesRight{index}", "Area2D", {
        "position": vec(SHAFT_RIGHT, y), "rotation": "-1.57079632679",
        "script": f'ExtResource("{HAZARD}")', "size": vec(52, 22),
        "damage": 20, "send_to_checkpoint": "true",
    })
checkpoint("CheckpointRubyRoom", 7140, ROOM_Y)
floor_title("TitleRubyRoom", 3000, ROOM_Y - 610, "LA CÁMARA DEL RUBY")
block("RubyPedestalStep", 3490, 4110, ROOM_Y - 80, ROOM_Y, PLATFORM)
block("RubyPedestal", 3660, 3940, ROOM_Y - 180, ROOM_Y - 80, PLATFORM)
S.node("Ruby1", "Area2D", {"position": vec(WIDTH / 2, ROOM_Y - 180), "script": f'ExtResource("{RUBY}")'})

# ---------------------------------------------------------------- Rengar, HUD y menús
player_and_ui(220, -2, {
    "title_text": '"RUBY1"',
    "message_text": '"Te fundiste con el Ruby1. ¡Fin de la demo!"',
    "final_screen": "true",
})

S.write(PROJECT / "stage4.tscn")
print("stage4.tscn generado con", len(S.nodes), "nodos")
