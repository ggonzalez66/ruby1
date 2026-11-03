#!/usr/bin/env python3
"""Genera las escenas de combate de la run del mapa (RunState):

  factory_outdoor.tscn  Fase 1 · afueras de la fábrica: reja, fachada y la puerta (se abre al limpiar).
  factory_indoor.tscn   Fase 2 · dentro: tres pisos con enemigos y la puerta del guardián arriba a la derecha.
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
    K.block("CatwalkLow", 2700, 3100, -300, -280, K.METAL)
    K.block("CatwalkHigh", 3300, 3800, -520, -500, K.METAL)
    K.block("CatwalkRight", 3950, 4450, -300, -280, K.METAL)
    door(K, "FactoryDoor", 3550, 0, "ENTRAR")


OUTDOOR_SPAWNS = [
    ("bush", 520, 0), ("bush", 1880, 0),
    ("melee", 1150, 0), ("shooter", 1700, 0), ("melee", 2450, 0),
    ("shooter_high", 2900, -300), ("rifleman", 3250, 0),
    ("hound", 2000, 0, 2), ("sentinel", 3550, -520, 2), ("shield", 3900, 0, 2),
    ("flyer", 2500, -260, 3), ("stinger", 3000, -250, 3), ("stinger", 3080, -290, 3),
    ("restorer", 3300, -200, 4), ("melee", 4250, 0, 4), ("rifleman", 4200, -300, 5),
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
    K.block("F2Catwalk", 1500, 1900, -440 - 170, -440 - 150, K.METAL)
    K.block("F3Crate", 1600, 1760, -880 - 110, -880, K.METAL)
    door(K, "BossDoor", 3420, -880, "GUARDIÁN →")


INDOOR_SPAWNS = [
    ("melee", 900, 0), ("shooter", 1700, 0), ("rifleman", 2700, 0),
    ("melee", 2500, -440), ("shooter", 1200, -440),
    ("melee", 1000, -880), ("rifleman", 2000, -880), ("shooter_high", 1700, -880 - 110),
    ("shield", 2100, 0, 2), ("hound", 600, -440, 2), ("sentinel", 1700, -610, 2),
    ("stinger", 2200, -640, 3), ("stinger", 2280, -680, 3), ("shield", 2900, -880, 3), ("restorer", 1400, -300, 3),
    ("melee", 3100, -440, 4), ("hound", 2500, -880, 4), ("flyer", 2600, -1100, 5),
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
        ("factory_indoor.tscn", build_indoor, INDOOR_SPAWNS, {"stage": "1", "exit_path": 'NodePath("../BossDoor")'}, 160, None),
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
