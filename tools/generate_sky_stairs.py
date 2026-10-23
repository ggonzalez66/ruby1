#!/usr/bin/env python3
"""Genera la ruta de rebotes de Escalera al cielo; posiciones visibles en el editor."""
from pathlib import Path
import math

SEGMENTS = 18
FIRST_GAP = 3600
GAP_GROWTH = 150
RISE = 700
FLYER_SPACING = 310


def generate():
    path = Path(__file__).resolve().parents[1] / 'sky_stairs.tscn'
    old = path.read_text()
    header = old[:old.index('[node name="Main"')] + '[node name="Main" type="Node2D"]\n\n[node name="JungleBackground" type="ParallaxBackground" parent="."]\nscript = ExtResource("4_jungle")\naltitude_offset = 0.45\n\n'
    tail = old[old.index('[node name="Playerr"'):]
    blocks = [header]

    def node(name, kind, props, instance=None):
        decl = f'[node name="{name}" type="{kind}" parent="."]' if instance is None else f'[node name="{name}" parent="." instance=ExtResource("{instance}")]'
        blocks.append(decl + '\n' + props + '\n\n')

    def platform(name, x, top, width):
        height = 300 - top
        node(name, 'StaticBody2D', f'position = Vector2({x}, {top + height / 2:g})\ncollision_layer = 2\nscript = ExtResource("13_platform")\nsize = Vector2({width}, {height})\nstyle = 0')

    def checkpoint(name, x, y):
        node(name, 'Area2D', f'position = Vector2({x}, {y})\nscript = ExtResource("9_checkpoint")')

    platform('StartIsland', 225, 0, 450)
    checkpoint('CheckpointStart', 150, 0)
    node('TitleSky', 'Label', 'offset_left = 140\noffset_top = -460\noffset_right = 1040\noffset_bottom = -400\ntheme_override_font_sizes/font_size = 34\ntext = "ESCALERA AL CIELO"')
    node('SignSky', 'Node2D', 'position = Vector2(320, 0)\nscript = ExtResource("14_sign")\ntext = "Los fosos crecen en cada tramo. Encadena rebotes con {heavy_attack} en los voladores.\nMantén {dash} para avanzar; {move_down} en picado da más altura. Las espinas te devuelven al checkpoint.\nCompite contra tu mejor fantasma: el tiempo sigue al caer."\ntitle = "Hasta el sol"\npanel_width = 400')
    edge = 450
    previous_top = 0
    for segment in range(1, SEGMENTS + 1):
        gap = FIRST_GAP + (segment - 1) * GAP_GROWTH
        width = 300 if segment < 7 else 250 if segment < 13 else 220
        top = -segment * RISE
        center = edge + gap + width / 2
        platform(f'Seg{segment}Land', center, top, width)
        checkpoint(f'CheckpointSeg{segment}Land', center, top)
        node(f'Pit{segment}', 'Area2D', f'position = Vector2({edge + gap / 2:g}, {previous_top + 380})\nscript = ExtResource("8_hazard")\nsize = Vector2({gap}, 22)\ndamage = 20\nsend_to_checkpoint = true')
        # Pinchos en el frente bajo de la isla: llegar por debajo no permite trepar y saltarse
        # la cadena. El borde superior conserva 65 px libres para aterrizajes ajustados.
        wall_start = top + 65
        wall_end = previous_top + 380
        node(f'PitWall{segment}', 'Area2D', f'position = Vector2({edge + gap:g}, {(wall_start + wall_end) / 2:g})\nrotation = -1.57079632679\nscript = ExtResource("8_hazard")\nsize = Vector2({wall_end - wall_start:g}, 22)\ndamage = 20\nsend_to_checkpoint = true')
        count = math.ceil(gap / FLYER_SPACING) - 1
        for i in range(1, count + 1):
            t = i / (count + 1)
            x = edge + gap * t
            y = previous_top - RISE * t - 80
            props = f'position = Vector2({x:g}, {y:g})\naerial = true\nmax_health = 9999'
            # El tramo inicial enseña; luego mezcla oscilaciones previsibles con apoyos quietos.
            if segment >= 4 and i % 3 == 0:
                props += f'\nmove_offset = Vector2(0, {45 + segment * 2})\nmove_period = {4.8 - segment * 0.08:g}'
            elif segment >= 9 and i % 3 == 1:
                props += f'\nmove_offset = Vector2(60, 0)\nmove_period = {5.0 - segment * 0.07:g}'
            node(f'Seg{segment}F{i}', '', props, '2_dummy')
        edge = center + width / 2
        previous_top = top
    platform('Summit', edge + 400, previous_top, 800)
    checkpoint('CheckpointSummit', edge + 340, previous_top)
    node('Sun', 'Area2D', f'position = Vector2({edge + 450:g}, {previous_top})\nscript = ExtResource("15_goal")\ngoal_style = "sun"')
    total = edge + 800
    for name, x, y, width, height in [('BoundaryLeft', -30, -6450, 60, 13600), ('BoundaryRight', total + 30, -6450, 60, 13600), ('BoundaryTop', total / 2, -13400, total + 120, 60)]:
        node(name, 'StaticBody2D', f'position = Vector2({x:g}, {y:g})\ncollision_layer = 2\nscript = ExtResource("13_platform")\nsize = Vector2({width:g}, {height:g})\nstyle = 3')
    # Red de seguridad bajo el arranque y el límite inferior global.
    node('ThornsAll', 'Area2D', f'position = Vector2({total / 2:g}, 440)\nscript = ExtResource("8_hazard")\nsize = Vector2({total:g}, 22)\ndamage = 20\nsend_to_checkpoint = true')
    blocks.append(tail)
    path.write_text(''.join(blocks))
    print(f'{SEGMENTS} fosos, {FIRST_GAP}–{FIRST_GAP + (SEGMENTS - 1) * GAP_GROWTH} px; meta {total:g} px')


if __name__ == '__main__':
    generate()
