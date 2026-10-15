#!/usr/bin/env python3
"""Genera main.tscn: la torre de 6 pisos con tutoriales y el guardián aleatorio.

Uso: python3 tools/generate_level.py   (desde la raíz del proyecto)

Convenciones:
- El piso N tiene el suelo en y = -(N-1) * FLOOR_HEIGHT; los pisos superiores son losas de 60 px.
- Las coordenadas de los bloques se dan como rectángulos (x0, x1, y_arriba, y_abajo).
- Distancias de referencia de Rengar: salto 104 px, doble salto ~208, agarre +44 sobre los pies,
  salto largo ~415 de largo, salto largo + frontflip ~760, backflip ~173 de alto,
  ritmo de bunnyhop 415 (espinas de 180 + hueco de 235), entrada de pozo >= 140 de alto.
"""

from level_kit import *  # noqa: F401,F403 (escena S, recursos y helpers comunes)

WIDTH = 10200
FLOOR_HEIGHT = 1100
SLAB = 60
FLOORS = 6
TOP = -FLOOR_HEIGHT * FLOORS


T = Tower(WIDTH, FLOOR_HEIGHT, SLAB)
G, slab_with_gaps, thorn_pit, bunny_strips, shaft, stairs = T.G, T.slab_with_gaps, T.thorn_pit, T.bunny_strips, T.shaft, T.stairs


# ---------------------------------------------------------------- Escena base
background()

# Contorno de la torre.
block("BoundaryLeft", -60, 0, TOP - 60, 360, WALL)
block("BoundaryRight", WIDTH, WIDTH + 60, TOP - 60, 360, WALL)
block("BoundaryTop", -60, WIDTH + 60, TOP - 60, TOP + 60, SLAB_STYLE)

# ================================================================ PISO 1 · FUNDAMENTOS (→)
g = G(1)
floor_title("TitleF1", 60, g - 420, "PISO 1 · FUNDAMENTOS")
F1_PITS = [(4000, 4250), (4700, 5050)]
x = 0
for a, b in F1_PITS + [(WIDTH, WIDTH)]:
    block(unique("F1Ground"), x, a, g, g + 300)
    x = b
for a, b in F1_PITS:
    block(unique("F1PitFloor"), a, b, g + 110, g + 300)
    thorns(unique("F1PitThorns"), a, b, g + 110)

checkpoint("CheckpointStart", 120, g)
sign("SignMove", 340, g, "Moverse", "Usa {move} para moverte.\nAcércate a los carteles como este: cada uno enseña una técnica nueva.")
sign("SignJump", 640, g, "Saltar", "Pulsa {jump} para saltar.\nSi lo sueltas antes, el salto es más corto.")
block("F1Step", 820, 940, g - 60, g)
sign("SignDoubleJump", 1150, g, "Doble salto", "En el aire, pulsa {jump} otra vez: doble salto.")
block("F1DoubleBlock", 1340, 1520, g - 190, g)
sign("SignCombo", 1780, g, "Combo", "{attack} ataca con las garras.\nPulsa 3 veces seguidas: el tercer golpe es un remate más fuerte.")
dummy("DummyCombo1", 1990, g)
dummy("DummyCombo2", 2120, g)
sign("SignHeavy", 2820, g, "Ataque pesado", "{heavy_attack} da un golpe pesado.\nEn el aire cae en picado: si golpea a un enemigo, rebotas y recuperas el doble salto.")
dummy("DummyHeavy", 3000, g, max_health=8)
dummy("DummyHeavyAir", 3190, g - 150, aerial=True, max_health=10)
sign("SignUppercut", 3400, g, "Uppercut", "Mantén {move_up} y pulsa {heavy_attack}: uppercut que te lanza hacia arriba.")
dummy("DummyUppercut", 3600, g - 200, aerial=True, max_health=10)
sign("SignDash", 3800, g, "Dash", "{dash} hace un dash rápido, también en el aire.\nSalta y haz dash para cruzar el foso.")
sign("SignSprint", 4450, g, "Carrera y salto largo", "Mantén {dash} al terminar el dash para seguir corriendo a toda velocidad.\nSalta mientras corres: salto largo.")
sign("SignMantle", 5300, g, "Agarre", "Si llegas justo al borde de un saliente, Rengar se agarra y sube solo.")
block("F1MantleLow", 5500, 5650, g - 130, g)
block("F1MantleHigh", 5650, 5800, g - 240, g)
sign("SignWallJump", 6050, g, "Walljump", "Salta contra una pared y pulsa {jump} para rebotar hacia el otro lado.\nSube por la chimenea rebotando entre las dos paredes.")
block("F1ChimneyLeft", 6250, 6290, g - 520, g - 110, WALL)
block("F1ChimneyRight", 6490, 6550, g - 520, g, WALL)
sign("SignChasers", 6820, g, "Perseguidores", "Los enemigos avisan con un (!) antes de atacar.\nEsquiva con {dash} o aléjate, y castígalos justo después de su golpe.")
chaser("ChaserF1A", 7150, g)
chaser("ChaserF1B", 7480, g)
sign("SignSun", 7760, g, "Sol", "El sol quema al tocarlo y no se puede destruir.\nPasa por debajo sin saltar.")
S.node("SunEnemy", None, {"position": vec(8000, g - 180)}, instance=SUN)
checkpoint("CheckpointF1End", 8350, g)
sign("SignClimbF1", 8700, g, "Subida", "Encadena doble salto y agarre para subir al siguiente piso.")
stairs(1, 9780, WIDTH - 10, "right")

# ================================================================ PISO 2 · CARRERA (←)
g = G(2)
floor_title("TitleF2", 8600, g - 480, "PISO 2 · CARRERA")
F2_PITS = [(5740, 6300), (1540, 2100)]
slab_with_gaps(2, [(9750, WIDTH)] + F2_PITS)
for a, b in F2_PITS:
    thorn_pit(2, a, b)
checkpoint("CheckpointF2", 9500, g)
sign("SignBackflip", 9250, g, "Backflip", "Corriendo, pulsa la dirección contraria y salta mientras frenas: backflip.\nSale hacia atrás y muy alto; en el aire aún te queda otro salto.", 340)
block("F2BackflipLedge", 8850, 9000, g - 270, g, WALL)
sign("SignBunnyhop", 8560, g, "Bunnyhop", "Salta corriendo y, justo al aterrizar, vuelve a pulsar {jump}: encadenas saltos largos sin perder velocidad.\nCruza las espinas sin tocarlas.", 340)
bunny_strips(2, 8250, 4, -1)
sign("SignFrontflip", 6600, g, "Frontflip", "Durante un salto largo pulsa {jump} en el aire: frontflip, llega mucho más lejos.")
sign("SignWallride", 5300, g, "Wallride", "Corriendo, salta contra la pared con enredaderas: Rengar corre por ella hacia arriba y se agarra al borde sin frenar.", 340)
block("F2WallrideWall", 4700, 4900, g - 180, g, CLIMB_WALL)
sign("SignRunAttack", 4450, g, "Ataque en carrera", "Corriendo, pulsa {attack}: estocada que avanza sin perder la carrera.\nSi frenas con la dirección contraria, sale hacia ese lado. Pulsa {jump} durante la estocada para girar en el aire.", 380)
dummy("DummyRunAttack", 4250, g, max_health=8)
chaser("ChaserF2A", 4000, g)
chaser("ChaserF2B", 3600, g)
sign("SignPracticeF2", 3300, g, "Práctica", "Combina lo aprendido: bunnyhop sobre las espinas y frontflip sobre el foso.")
bunny_strips(2, 2950, 2, -1)
checkpoint("CheckpointF2Shaft", 1250, g)
sign("SignRunningWallJump", 760, g, "Running walljump", "Corriendo, salta contra una pared: Rengar se engancha un instante.\nPulsa {jump} para saltar a la pared contraria con impulso y encadénalos para subir el pozo.", 360)
shaft(2, "left")

# ================================================================ PISO 3 · CUCHILLO (→)
g = G(3)
floor_title("TitleF3", 460, g - 480, "PISO 3 · CUCHILLO")
F3_PITS = [(1100, 1400), (7900, 8400)]
slab_with_gaps(3, [(0, 386)] + F3_PITS)
for a, b in F3_PITS:
    thorn_pit(3, a, b)
checkpoint("CheckpointF3", 560, g)
sign("SignKnife", 820, g, "Cuchillo", "{throw_knife} lanza el cuchillo: se clava en enemigos y paredes.\nPulsa {throw_knife} otra vez para que vuelva a tu mano.")
dummy("DummyKnifeTarget", 1700, g, max_health=8)
sign("SignKnifeAim", 2000, g, "Apuntar", "Mantén {move_up} al lanzar para tirar hacia arriba, o en diagonal si además te mueves.")
dummy("DummyKnifeHigh", 2250, g - 360, aerial=True, max_health=6)
sign("SignKnifePull", 2600, g, "Atraer", "Si el cuchillo está clavado en un enemigo, al recuperarlo lo arrastras hacia ti.\nBaja al dummy de la plataforma alta: la caída lo destruye.", 340)
platform("F3PullPlatform", 2850, 3050, g - 320)
dummy("DummyKnifePull", 2950, g - 320, max_health=30)
sign("SignEmbed", 3300, g, "Clavarse", "En el aire, {heavy_attack} contra una pared: Rengar se clava y explota, dañando a los enemigos cerca.\nDesde ahí puedes volver a saltar.", 360)
block("F3ChimneyLeft", 3500, 3540, g - 620, g - 140, WALL)
block("F3ChimneyRight", 3740, 3800, g - 620, g, WALL)
dummy("DummyEmbed", 3640, g - 420, aerial=True, max_health=4)
thorns("F3PillarThorns", 3800, 4000, g)
sign("SignBounce", 4300, g, "Rebote pesado", "Golpe pesado en el aire sobre un enemigo: rebotas y recuperas el doble salto.\nCruza las espinas rebotando de dummy en dummy.", 340)
thorns("F3BounceThornsA", 4500, 5100, g)
block("F3IslandA", 5100, 5180, g - 30, g)
thorns("F3BounceThornsB", 5180, 5700, g)
block("F3IslandB", 5700, 5780, g - 30, g)
thorns("F3BounceThornsC", 5780, 6300, g)
for index, bx in enumerate([4700, 4930, 5400, 5560, 6000, 6180]):
    dummy(f"DummyBounce{index + 1}", bx, g - 130 - (index % 2) * 40, aerial=True, max_health=60)
checkpoint("CheckpointF3Mid", 6700, g)
sign("SignKnifeChaser", 6950, g, "Cuchillo y perseguidores", "Clávale el cuchillo a un perseguidor y recupéralo: lo atraes hacia ti fuera de su guardia.", 340)
chaser("ChaserF3A", 7350, g)
chaser("ChaserF3B", 7650, g)
dummy("DummyPitBounce", 8150, g - 140, aerial=True, max_health=60)
chaser("ChaserF3C", 8900, g)
sign("SignShaftF3", 9500, g, "Pozo", "Otra vez running walljumps: corre hacia la pared y encadena saltos.")
shaft(3, "right")

# ================================================================ PISO 4 · RUGIDO (←)
g = G(4)
floor_title("TitleF4", 8600, g - 480, "PISO 4 · RUGIDO")
F4_PITS = [(3600, 4100)]
slab_with_gaps(4, [(WIDTH - 386, WIDTH)] + F4_PITS)
for a, b in F4_PITS:
    thorn_pit(4, a, b)
checkpoint("CheckpointF4", 9600, g)
sign("SignRoar", 9350, g, "Rugido", "{roar} ruge: al principio desvías ataques (parry) y proyectiles. En el aire te deja suspendido; cancélalo saltando o con {dash}.\nMantenido, bloquea golpes (te empuja) y devuelve proyectiles, pero gasta la durabilidad del shine (barra vertical junto a la vida). Si se rompe, espera a que se recargue.", 400)
sign("SignReflect", 8900, g, "Devolver", "Ruge justo cuando un proyectil te alcance: vuelve hacia quien lo disparó.\nDevolverlo abre el riposte: lanza el cuchillo enseguida, pega el doble y te cura al sacarlo.\nOjo: a veces el tirador te lo devuelve, cada vez más fuerte.", 360)
shooter("ShooterF4A", 8300, g, (1, 0), 2.2)
shooter("ShooterF4B", 7950, g - 260, (1, 0.35), 2.6, True)
sign("SignShineKnife", 7700, g, "Shine knife", "Ruge mientras el cuchillo vuelve hacia ti: sale disparado otra vez contra el enemigo en que estaba clavado.\nEncadénalo: recupera, ruge, recupera...", 340)
sign("SignParry", 7350, g, "Parry y contraataque", "Ruge justo antes de que un perseguidor te golpee: queda aturdido.\nRiposte: tu siguiente {heavy_attack} o cuchillo hace el doble de daño y te cura.", 340)
chaser("ChaserF4A", 7000, g)
chaser("ChaserF4B", 6650, g)
checkpoint("CheckpointF4Mid", 6200, g)
sign("SignMixF4", 5950, g, "Todo junto", "Tiradores y perseguidores a la vez: ruge en el momento justo.")
shooter("ShooterF4C", 5400, g, (1, 0), 2.4)
platform("F4ShooterPlatform", 4800, 5000, g - 200)
shooter("ShooterF4D", 4900, g - 200, (1, 0.25), 2.8)
chaser("ChaserF4C", 4450, g)
shooter("ShooterF4E", 3300, g - 220, (1, 0), 2.6, True)
chaser("ChaserF4D", 2600, g)
sign("SignClimbF4", 900, g, "Subida", "Sube por las plataformas. El tirador de arriba te dispara: ruge para devolverle sus disparos.", 340)
shooter("ShooterF4Climb", 760, g - 620, (-1, 0), 2.8, True)
stairs(4, 10, 440, "left")

# ================================================================ PISO 5 · PRUEBA FINAL (→)
g = G(5)
floor_title("TitleF5", 560, g - 480, "PISO 5 · PRUEBA FINAL")
F5_PITS = [(3200, 3800)]
slab_with_gaps(5, [(0, 520)] + F5_PITS)
for a, b in F5_PITS:
    thorn_pit(5, a, b)
checkpoint("CheckpointF5", 650, g)
sign("SignFinalTrial", 900, g, "Prueba final", "Todo lo aprendido, sin más carteles.\n¡Suerte!")
block("F5WallrideWall", 1300, 1500, g - 180, g, CLIMB_WALL)
bunny_strips(5, 1900, 3, 1)
S.node("SunEnemyF5", None, {"position": vec(3500, g - 260)}, instance=SUN)
chaser("ChaserF5A", 4200, g)
chaser("ChaserF5B", 4450, g)
platform("F5ShooterPlatform", 4700, 4900, g - 220)
shooter("ShooterF5A", 4800, g - 220, (-1, 0.2), 2.6)
block("F5BackflipLedge", 5300, 5450, g - 270, g, WALL)
thorns("F5BounceThorns", 5800, 6800, g)
for index, bx in enumerate([5950, 6200, 6450, 6650]):
    dummy(f"DummyF5Bounce{index + 1}", bx, g - 130 - (index % 2) * 40, aerial=True, max_health=60)
checkpoint("CheckpointF5Mid", 7100, g)
block("F5ChimneyLeft", 7600, 7640, g - 560, g - 140, WALL)
block("F5ChimneyRight", 7840, 7900, g - 560, g, WALL)
chaser("ChaserF5C", 8300, g)
chaser("ChaserF5D", 8600, g)
shooter("ShooterF5B", 9000, g, (-1, 0), 2.4)
shaft(5, "right")

# ================================================================ PISO 6 · GUARDIÁN (←)
g = G(6)
floor_title("TitleF6", 8400, g - 520, "PISO 6 · GUARDIÁN DE LA TORRE")
slab_with_gaps(6, [(0, 4800), (WIDTH - 386, WIDTH)])
block("F6EndWall", 0, 4860, TOP + 60, g + SLAB, WALL)
checkpoint("CheckpointBoss", 9400, g)
sign("SignBoss", 9150, g, "Guardián", "El guardián cambia en cada partida: pesado, ágil o arquero. Los otros dos esperan en las etapas siguientes.\nObserva sus avisos (!), ruge para desviar y castiga tras sus ataques.", 360)
platform("F6ArenaPlatformLeft", 5800, 6100, g - 170)
platform("F6ArenaPlatformRight", 7500, 7800, g - 170)
S.node("BossSpawner", "Node2D", {
    "script": f'ExtResource("{SPAWNER}")',
    "spawn_point": vec(6800, g),
    "arena_min_x": "5000",
    "arena_max_x": "8800",
    # Partida de tres etapas: aquí siempre un solo guardián (el trío puede salir al final de la etapa 3).
    "trio_chance": "0",
})

# ---------------------------------------------------------------- Rengar, HUD y menús
player_and_ui(220, G(1) - 2, {"title_text": '"ETAPA 1 COMPLETADA"', "next_scene": '"res://stage2.tscn"'})

S.write(PROJECT / "main.tscn", "uid://bsjw318ojxwhy")
print("main.tscn generado con", len(S.nodes), "nodos")
