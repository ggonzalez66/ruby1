#!/usr/bin/env python3
"""Genera las escenas de combate de la run del mapa (RunState):

  factory_outdoor.tscn  Fase 1 · afueras de la fábrica: reja, fachada y la puerta (se abre al limpiar).
  factory_outdoor_b/c   Variantes de las afueras: el canal inundado y el patio de carga.
  factory_indoor.tscn   Fase 2 · dentro: tres pisos con enemigos y la puerta del guardián arriba a la derecha.
  factory_indoor_b/c    Variantes de dentro: el sótano inundado y la línea de montaje.
  factory_boss.tscn     Fase 3 · la sala del guardián: uno que aún no se venció en la run; mejora gratis.
  tower_finale.tscn     La Torre: los tres guardianes juntos y, al vencerlos, el sol.

Uso: python3 tools/generate_run_stages.py   (desde la raíz del proyecto)

Los enemigos son Marker2D bajo "Spawns" con metadata kind / min_depth: el director (run_encounter.gd)
saca los que tocan según la profundidad de la run (min_depth <= enfrentamiento actual).
"""

import importlib

import level_kit

FLOOR = 440


def scene(K, director_props, spawns, build, player_x, player_y=-2, background=None):
    """Monta una escena: decorado y bloques (build), Spawns, director y el jugador con la interfaz."""
    if background is not None:
        K.background(altitude_offset=background)
    build(K)
    K.S.node("Spawns", "Node2D")
    for index, spawn in enumerate(spawns):
        kind, x, y = spawn[:3]
        min_depth = spawn[3] if len(spawn) > 3 else 1
        K.S.node(f"Spawn{index + 1}", "Marker2D", {
            "position": K.vec(x, y),
            "metadata/kind": f'"{kind}"',
            "metadata/min_depth": min_depth,
        }, parent="Spawns")
    director = K.S.ext_res("Script", "res://run_encounter.gd", "20_run_director")
    props = {"script": f'ExtResource("{director}")', "spawns_path": 'NodePath("../Spawns")'}
    props.update(director_props)
    K.S.node("RunDirector", "Node2D", props)
    K.player_and_ui(player_x, player_y, {"title_text": '"RUN"', "final_screen": "true"})


def decor(K, mode, area, **extra):
    script = K.S.ext_res("Script", "res://factory_decor.gd", "21_decor")
    props = {"script": f'ExtResource("{script}")', "mode": f'"{mode}"',
             "area": f"Rect2({area[0]:g}, {area[1]:g}, {area[2]:g}, {area[3]:g})"}
    props.update(extra)
    K.S.node("FactoryDecor", "Node2D", props)


def camera(K, name, x, y, aim, sweep=35, period=4.0):
    """Cámara de seguridad (security_camera.gd): aim en grados (0 derecha, 90 abajo)."""
    script = K.S.ext_res("Script", "res://security_camera.gd", "23_camera")
    K.S.node(name, "Area2D", {"position": K.vec(x, y), "script": f'ExtResource("{script}")',
                              "aim_angle": f"{aim:g}", "sweep": f"{sweep:g}", "period": f"{period:g}"})


def water(K, name, x0, x1, y_surface, depth):
    """Agua (water_zone.gd): dentro Viridy se mueve lenta y pesada."""
    script = K.S.ext_res("Script", "res://water_zone.gd", "24_water")
    K.S.node(name, "Node2D", {"position": K.vec((x0 + x1) / 2, y_surface), "script": f'ExtResource("{script}")',
                              "size": K.vec(x1 - x0, depth)})


def door(K, name, x, y, label):
    script = K.S.ext_res("Script", "res://factory_door.gd", "22_door")
    K.S.node(name, "Area2D", {"position": K.vec(x, y), "script": f'ExtResource("{script}")',
                              "label_text": f'"{label}"'})


# ---------------------------------------------------------------- Fase 1 · afueras
OUTDOOR_WIDTH = 4600


def build_outdoor(K):
    decor(K, "outdoor", (2600, -1000, 2000, 1000), fence_from="900", fence_to="2300")
    K.block("BoundaryLeft", -60, 0, -1600, 360, K.WALL)
    K.block("BoundaryRight", OUTDOOR_WIDTH, OUTDOOR_WIDTH + 60, -1600, 360, K.METAL)
    K.block("Ground", 0, OUTDOOR_WIDTH, 0, 300)
    K.floor_title("TitleOutdoor", 140, -460, "LA FÁBRICA · AFUERAS")
    K.sign("SignOutdoor", 60, 0, "La fábrica",
           "Los guardias no saben que estás aquí: acércate por la espalda y ejecútalos con un pesado.\n"
           "La puerta se abre cuando no quede ninguno en pie.", 360)
    # Cajas para cubrirse y pasarelas de la fachada.
    K.platform("CrateA", 1300, 1460, -120, 120)
    K.platform("CrateB", 2060, 2200, -150, 150)
    # Pasarelas atravesables: se suben saltando desde abajo y se bajan con abajo + salto.
    K.catwalk("CatwalkLow", 2700, 3100, -300)
    K.catwalk("CatwalkHigh", 3300, 3800, -520)
    K.catwalk("CatwalkRight", 3950, 4450, -300)
    K.catwalk("CatwalkCrates", 1240, 1560, -250)
    door(K, "FactoryDoor", 3550, 0, "ENTRAR")
    # Cámaras en las entradas: la reja y la puerta de la fábrica.
    camera(K, "CameraGate", 905, -300, 50, 25, 3.6)
    camera(K, "CameraDoor", 3550, -330, 125, 30, 4.2)
    camera(K, "CameraFacade", 2640, -620, 120, 25, 5.0)


OUTDOOR_SPAWNS = [
    ("bush", 520, 0), ("bush", 1880, 0),
    ("melee", 1150, 0), ("shooter", 1700, 0), ("melee", 2450, 0),
    ("shooter_high", 2900, -300), ("rifleman", 3250, 0),
    ("hound", 2000, 0, 2), ("sentinel", 3550, -520, 2), ("shield", 3900, 0, 2),
    ("flyer", 2500, -260, 3), ("stinger", 3000, -250, 3), ("stinger", 3080, -290, 3),
    ("restorer", 3300, -200, 4), ("melee", 4250, 0, 4), ("rifleman", 4200, -300, 5),
]

# Variante B · el canal: una zanja inundada cruza el patio, con un puente-pasarela por encima.
def build_outdoor_b(K):
    decor(K, "outdoor", (2600, -1000, 2000, 1000), fence_from="700", fence_to="1450")
    K.block("BoundaryLeft", -60, 0, -1600, 360, K.WALL)
    K.block("BoundaryRight", OUTDOOR_WIDTH, OUTDOOR_WIDTH + 60, -1600, 360, K.METAL)
    K.block("GroundWest", 0, 1500, 0, 300)
    K.block("CanalBed", 1500, 2200, 140, 300, K.METAL)
    K.block("GroundEast", 2200, OUTDOOR_WIDTH, 0, 300)
    water(K, "CanalWater", 1500, 2200, 20, 120)
    # Escalones a los lados del canal para salir del agua.
    K.block("CanalStepWest", 1500, 1590, 60, 80, K.METAL)
    K.block("CanalStepEast", 2110, 2200, 60, 80, K.METAL)
    K.floor_title("TitleOutdoor", 140, -460, "LA FÁBRICA · EL CANAL")
    K.catwalk("CanalBridge", 1420, 2280, -170)
    K.platform("CrateA", 900, 1060, -120, 120)
    K.platform("CrateC", 2600, 2760, -140, 140)
    K.catwalk("CatwalkLow", 3000, 3400, -260)
    K.catwalk("CatwalkRight", 3750, 4250, -300)
    K.catwalk("CatwalkHigh", 3250, 3650, -480)
    door(K, "FactoryDoor", 3550, 0, "ENTRAR")
    camera(K, "CameraCanal", 1850, -380, 90, 40, 4.0)
    camera(K, "CameraDoor", 3550, -330, 125, 30, 4.2)
    camera(K, "CameraFacade", 2950, -600, 110, 25, 5.0)


OUTDOOR_B_SPAWNS = [
    ("bush", 450, 0), ("bush", 2450, 0),
    ("melee", 1100, 0), ("shooter", 1850, -170), ("melee", 2500, 0),
    ("shooter_high", 3200, -260), ("rifleman", 2900, 0),
    ("hound", 1300, 0, 2), ("sentinel", 3450, -480, 2), ("shield", 3900, 0, 2),
    ("flyer", 1850, -330, 3), ("stinger", 3000, -330, 3), ("stinger", 3080, -370, 3),
    ("restorer", 2700, -260, 4), ("melee", 4300, 0, 4), ("rifleman", 4000, -300, 5),
]


# Variante C · el patio de carga: pilas de contenedores que se trepan y pasarelas altas.
def build_outdoor_c(K):
    decor(K, "outdoor", (2600, -1000, 2000, 1000), fence_from="400", fence_to="800")
    K.block("BoundaryLeft", -60, 0, -1600, 360, K.WALL)
    K.block("BoundaryRight", OUTDOOR_WIDTH, OUTDOOR_WIDTH + 60, -1600, 360, K.METAL)
    K.block("Ground", 0, OUTDOOR_WIDTH, 0, 300)
    K.floor_title("TitleOutdoor", 140, -460, "LA FÁBRICA · PATIO DE CARGA")
    K.block("ContainerA", 900, 1200, -150, 0, K.METAL)
    K.block("ContainerB", 1050, 1300, -300, -150, K.METAL)
    K.block("ContainerC", 2000, 2400, -120, 0, K.METAL)
    K.block("ContainerD", 2700, 2950, -240, 0, K.METAL)
    K.catwalk("LoadingRamp", 2450, 2700, -150)
    K.catwalk("CraneWalk", 1350, 1900, -330)
    K.catwalk("CatwalkHigh", 3100, 3700, -420)
    K.catwalk("CatwalkRight", 3900, 4400, -260)
    door(K, "FactoryDoor", 3550, 0, "ENTRAR")
    camera(K, "CameraCrane", 1250, -470, 70, 30, 4.0)
    camera(K, "CameraDoor", 3550, -330, 125, 30, 4.2)
    camera(K, "CameraYard", 2200, -420, 95, 40, 4.6)


OUTDOOR_C_SPAWNS = [
    ("bush", 600, 0), ("bush", 1700, 0), ("bush", 3300, 0),
    ("melee", 1500, 0), ("shooter_high", 1150, -300), ("melee", 2550, 0),
    ("shooter", 2200, -120), ("rifleman", 3200, 0),
    ("hound", 1900, 0, 2), ("sentinel", 3400, -420, 2), ("shield", 4000, 0, 2),
    ("flyer", 2600, -380, 3), ("stinger", 2850, -330, 3), ("stinger", 2930, -370, 3),
    ("restorer", 3600, -250, 4), ("melee", 4300, 0, 4), ("rifleman", 4150, -260, 5),
]

# ---------------------------------------------------------------- Fase 2 · dentro
INDOOR_WIDTH = 3600


def build_indoor(K):
    tower = K.Tower(INDOOR_WIDTH, FLOOR)
    decor(K, "indoor", (-200, -1500, INDOOR_WIDTH + 400, 1900))
    K.block("BoundaryLeft", -60, 0, -1400, 360, K.METAL)
    K.block("BoundaryRight", INDOOR_WIDTH, INDOOR_WIDTH + 60, -1400, 360, K.METAL)
    K.block("Ceiling", -60, INDOOR_WIDTH + 60, -1380, -1320, K.METAL)
    K.block("Ground", 0, INDOOR_WIDTH, 0, 300, K.METAL)
    K.floor_title("TitleIndoor", 140, -330, "LA FÁBRICA · DENTRO")
    # Piso 2: hueco a la derecha; piso 3: hueco a la izquierda (escaleras de plataformas en cada hueco).
    for floor, gap in ((2, (2980, 3340)), (3, (260, 620))):
        y = tower.G(floor)
        x = 0
        for a, b in [gap, (INDOOR_WIDTH, INDOOR_WIDTH)]:
            if a > x:
                K.block(f"F{floor}Slab{x}", x, a, y, y + 60, K.METAL)
            x = b
        # Escalones de chapa alternados dentro del hueco (doble salto y agarre), como Tower.stairs.
        base = tower.G(floor - 1)
        left_first = floor == 2
        for step, y_top in enumerate((base - 170, max(base - 340, y + 130))):
            on_left = left_first if step % 2 == 0 else not left_first
            a, b = (gap[0], gap[0] + 160) if on_left else (gap[1] - 160, gap[1])
            K.block(f"F{floor - 1}Step{step + 1}", a, b, y_top, y_top + 20, K.METAL)
    # Contenedores y pasarelas para cubrirse en cada piso.
    K.block("F1Crate", 1250, 1400, -110, 0, K.METAL)
    K.block("F1Crate2", 2300, 2420, -90, 0, K.METAL)
    # Pasarelas atravesables sobre cada piso (abajo + salto para bajar).
    K.catwalk("F2Catwalk", 1500, 1900, -440 - 170)
    K.catwalk("F1CatwalkA", 760, 1150, -190)
    K.catwalk("F1CatwalkB", 2150, 2600, -200)
    K.catwalk("F3Catwalk", 2450, 2900, -880 - 180)
    K.block("F3Crate", 1600, 1760, -880 - 110, -880, K.METAL)
    door(K, "BossDoor", 3420, -880, "GUARDIÁN →")
    # Cámaras en el techo de cada piso y en la entrada.
    camera(K, "CameraEntrance", 420, -372, 60, 25, 3.8)
    camera(K, "CameraF1", 2000, -372, 90, 45, 4.5)
    camera(K, "CameraF2", 1100, -812, 90, 45, 4.0)
    camera(K, "CameraF2Stairs", 2800, -812, 90, 40, 3.6)
    camera(K, "CameraF3", 2300, -1312, 90, 45, 4.4)


INDOOR_SPAWNS = [
    ("melee", 900, 0), ("shooter", 1700, 0), ("rifleman", 2700, 0),
    ("melee", 2500, -440), ("shooter", 1200, -440),
    ("melee", 1000, -880), ("rifleman", 2000, -880), ("shooter_high", 1700, -880 - 110),
    ("shield", 2100, 0, 2), ("hound", 600, -440, 2), ("sentinel", 1700, -610, 2),
    ("stinger", 2200, -640, 3), ("stinger", 2280, -680, 3), ("shield", 2900, -880, 3), ("restorer", 1400, -300, 3),
    ("melee", 3100, -440, 4), ("hound", 2500, -880, 4), ("flyer", 2600, -1100, 5),
]

def indoor_shell(K, title):
    decor(K, "indoor", (-200, -1500, INDOOR_WIDTH + 400, 1900))
    K.block("BoundaryLeft", -60, 0, -1400, 360, K.METAL)
    K.block("BoundaryRight", INDOOR_WIDTH, INDOOR_WIDTH + 60, -1400, 360, K.METAL)
    K.block("Ceiling", -60, INDOOR_WIDTH + 60, -1380, -1320, K.METAL)
    K.floor_title("TitleIndoor", 140, -330, title)


def indoor_floors(K, tower, gaps, left_first, catwalk_spans=()):
    """Losas de los pisos 2 y 3 con su hueco y escalones; catwalk_spans: tramos de losa que son pasarela."""
    for floor in (2, 3):
        gap = gaps[floor]
        y = tower.G(floor)
        x = 0
        for a, b in [gap, (INDOOR_WIDTH, INDOOR_WIDTH)]:
            if a > x:
                pieces = [(x, a)]
                for c0, c1, f in catwalk_spans:
                    if f == floor and x < c0 and c1 < a:
                        pieces = [(x, c0), (c1, a)]
                        K.catwalk(f"F{floor}Walk{c0}", c0, c1, y)
                for p0, p1 in pieces:
                    K.block(f"F{floor}Slab{p0}", p0, p1, y, y + 60, K.METAL)
            x = b
        base = tower.G(floor - 1)
        first = left_first[floor]
        for step, y_top in enumerate((base - 170, max(base - 340, y + 130))):
            on_left = first if step % 2 == 0 else not first
            a, b = (gap[0], gap[0] + 160) if on_left else (gap[1] - 160, gap[1])
            K.block(f"F{floor - 1}Step{step + 1}", a, b, y_top, y_top + 20, K.METAL)


# Variante B · el sótano inundado: el primer piso tiene una piscina; los huecos de las escaleras, al revés.
def build_indoor_b(K):
    tower = K.Tower(INDOOR_WIDTH, FLOOR)
    indoor_shell(K, "LA FÁBRICA · SÓTANO INUNDADO")
    K.block("GroundWest", 0, 800, 0, 300, K.METAL)
    K.block("FloodBed", 800, 2000, 160, 300, K.METAL)
    K.block("GroundEast", 2000, INDOOR_WIDTH, 0, 300, K.METAL)
    water(K, "FloodWater", 800, 2000, 30, 130)
    K.block("FloodStepWest", 800, 900, 80, 100, K.METAL)
    K.block("FloodStepEast", 1900, 2000, 80, 100, K.METAL)
    K.catwalk("FloodWalk", 1150, 1650, -150)
    indoor_floors(K, tower, {2: (260, 620), 3: (2980, 3340)}, {2: True, 3: False})
    K.block("F1Crate", 2500, 2650, -110, 0, K.METAL)
    K.block("F2Crate", 1900, 2050, -440 - 110, -440, K.METAL)
    K.catwalk("F2Catwalk", 1200, 1600, -440 - 170)
    K.block("F3Crate", 1300, 1460, -880 - 110, -880, K.METAL)
    K.catwalk("F3Catwalk", 600, 1000, -880 - 180)
    door(K, "BossDoor", 180, -880, "GUARDIÁN →")
    camera(K, "CameraFlood", 1400, -372, 90, 45, 4.4)
    camera(K, "CameraEntrance", 3200, -372, 120, 25, 3.8)
    camera(K, "CameraF2", 2400, -812, 90, 45, 4.0)
    camera(K, "CameraF3", 1100, -1312, 90, 45, 4.4)
    camera(K, "CameraF3Door", 500, -1312, 70, 30, 3.6)


INDOOR_B_SPAWNS = [
    ("melee", 600, 0), ("shooter", 2300, 0), ("rifleman", 2900, 0),
    ("melee", 1100, -440), ("shooter", 2500, -440),
    ("melee", 2000, -880), ("rifleman", 1500, -880), ("shooter_high", 1380, -880 - 110),
    ("shield", 2750, 0, 2), ("hound", 2800, -440, 2), ("sentinel", 1400, -610, 2),
    ("stinger", 1400, -300, 3), ("stinger", 1480, -340, 3), ("shield", 700, -880, 3), ("restorer", 2200, -300, 3),
    ("melee", 3100, -440, 4), ("hound", 2600, -880, 4), ("flyer", 1400, -1100, 5),
]


# Variante C · la línea de montaje: parte de la losa del piso 2 es pasarela (atajos verticales) y
# contenedores en fila en el primer piso.
def build_indoor_c(K):
    tower = K.Tower(INDOOR_WIDTH, FLOOR)
    indoor_shell(K, "LA FÁBRICA · LÍNEA DE MONTAJE")
    K.block("Ground", 0, INDOOR_WIDTH, 0, 300, K.METAL)
    indoor_floors(K, tower, {2: (2980, 3340), 3: (260, 620)}, {2: True, 3: False}, [(1300, 2000, 2)])
    for index, x in enumerate((700, 1150, 1600, 2050)):
        K.block(f"F1Line{index + 1}", x, x + 120, -90, 0, K.METAL)
    K.catwalk("F1Walk", 2400, 2850, -200)
    K.catwalk("F2WalkHigh", 600, 1100, -440 - 180)
    K.block("F2Crate", 2300, 2450, -440 - 110, -440, K.METAL)
    K.catwalk("F3Walk", 1900, 2400, -880 - 170)
    K.block("F3Crate", 2700, 2860, -880 - 110, -880, K.METAL)
    door(K, "BossDoor", 3420, -880, "GUARDIÁN →")
    camera(K, "CameraEntrance", 420, -372, 60, 25, 3.8)
    camera(K, "CameraLine", 1600, -372, 90, 45, 4.2)
    camera(K, "CameraF2", 1650, -812, 90, 45, 4.0)
    camera(K, "CameraF2Stairs", 3100, -812, 90, 40, 3.6)
    camera(K, "CameraF3", 2150, -1312, 90, 45, 4.4)


INDOOR_C_SPAWNS = [
    ("melee", 950, 0), ("shooter", 1820, 0), ("rifleman", 2700, 0),
    ("melee", 2600, -440), ("shooter", 800, -440 - 180),
    ("melee", 1000, -880), ("rifleman", 2200, -880), ("shooter_high", 2780, -880 - 110),
    ("shield", 2200, 0, 2), ("hound", 900, -440, 2), ("sentinel", 2150, -880 - 170, 2),
    ("stinger", 1650, -600, 3), ("stinger", 1730, -640, 3), ("shield", 3000, -880, 3), ("restorer", 1600, -250, 3),
    ("melee", 2800, -440, 4), ("hound", 1500, -880, 4), ("flyer", 2400, -1100, 5),
]

# ---------------------------------------------------------------- Fase 3 · el guardián y la Torre
ARENA_WIDTH = 3800


def build_arena(K, tower_top):
    decor(K, "tower" if tower_top else "hall", (-200, -1700, ARENA_WIDTH + 400, 2100))
    style_ground = K.SLAB_STYLE if tower_top else K.METAL
    style_wall = K.CLIMB_WALL if tower_top else K.METAL
    K.block("BoundaryLeft", -60, 0, -1600, 360, style_wall)
    K.block("BoundaryRight", ARENA_WIDTH, ARENA_WIDTH + 60, -1600, 360, style_wall)
    K.block("BoundaryTop", -60, ARENA_WIDTH + 60, -1660, -1600, K.SLAB_STYLE if tower_top else K.METAL)
    K.block("Ground", 0, ARENA_WIDTH, 0, 300, style_ground)
    K.floor_title("TitleArena", 140, -460, "LA TORRE · LOS TRES GUARDIANES" if tower_top else "LA FÁBRICA · EL GUARDIÁN")
    # Plataformas flotantes como en el boceto: dos alturas y una alta al centro.
    for name, a, b, y in (("PlatLowL", 800, 1020, -190), ("PlatMidL", 1350, 1570, -350),
                          ("PlatTop", 1800, 2040, -520), ("PlatMidR", 2300, 2520, -350),
                          ("PlatLowR", 2850, 3070, -190)):
        if tower_top:
            K.platform(name, a, b, y)
        else:
            K.block(name, a, b, y, y + 20, K.METAL)


def spawner_props(K, forced, trio_chance):
    return {
        "script": f'ExtResource("{K.SPAWNER}")',
        "spawn_point": K.vec(2500, 0),
        "arena_min_x": "300",
        "arena_max_x": f"{ARENA_WIDTH - 200}",
        "forced_boss": str(forced),
        "trio_chance": f"{trio_chance:g}",
        "auto_spawn": "false",
        "entry_from_left": "true",
    }


def build_boss(K):
    build_arena(K, False)
    K.S.node("BossSpawner", "Node2D", spawner_props(K, 4, 0.0))


def build_tower(K):
    build_arena(K, True)
    K.S.node("BossSpawner", "Node2D", spawner_props(K, 5, 0.0))


def main():
    jobs = [
        ("factory_outdoor.tscn", build_outdoor, OUTDOOR_SPAWNS, {"stage": "0", "exit_path": 'NodePath("../FactoryDoor")'}, 200, 0.0),
        ("factory_outdoor_b.tscn", build_outdoor_b, OUTDOOR_B_SPAWNS, {"stage": "0", "exit_path": 'NodePath("../FactoryDoor")'}, 200, 0.0),
        ("factory_outdoor_c.tscn", build_outdoor_c, OUTDOOR_C_SPAWNS, {"stage": "0", "exit_path": 'NodePath("../FactoryDoor")'}, 200, 0.0),
        ("factory_indoor.tscn", build_indoor, INDOOR_SPAWNS, {"stage": "1", "exit_path": 'NodePath("../BossDoor")'}, 160, None),
        ("factory_indoor_b.tscn", build_indoor_b, INDOOR_B_SPAWNS, {"stage": "1", "exit_path": 'NodePath("../BossDoor")'}, 3300, None),
        ("factory_indoor_c.tscn", build_indoor_c, INDOOR_C_SPAWNS, {"stage": "1", "exit_path": 'NodePath("../BossDoor")'}, 160, None),
        ("factory_boss.tscn", build_boss, [], {"stage": "2", "spawner_path": 'NodePath("../BossSpawner")', "right_portal_x": f"{ARENA_WIDTH - 250}"}, 200, None),
        ("tower_finale.tscn", build_tower, [], {"stage": "3", "spawner_path": 'NodePath("../BossSpawner")', "sun_position": K_vec(ARENA_WIDTH - 450, 0)}, 200, None),
    ]
    for filename, build, spawns, props, player_x, background in jobs:
        K = importlib.reload(level_kit)
        scene(K, props, spawns, build, player_x, background=background)
        K.S.write(K.PROJECT / filename)
        print(filename, "generado con", len(K.S.nodes), "nodos")


def K_vec(x, y):
    return f"Vector2({x:g}, {y:g})"


if __name__ == "__main__":
    main()
