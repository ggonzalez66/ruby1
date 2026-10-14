"""Piezas comunes para generar los escenarios (.tscn) del juego: la escena, los recursos externos
y los helpers de bloques, carteles, enemigos, checkpoints y la interfaz.

Cada generador (generate_level.py, generate_gauntlet.py) corre en su propio proceso y usa la escena
global S de este módulo.
"""

from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent

GROUND, SLAB_STYLE, PLATFORM, WALL, CLIMB_WALL = range(5)


def esc(text):
    return text.replace("\\", "\\\\").replace('"', '\\"')


class Scene:
    def __init__(self):
        self.ext = []
        self.nodes = []
        self.names = set()

    def ext_res(self, kind, path, rid, uid=None):
        uid_part = f' uid="{uid}"' if uid else ""
        self.ext.append(f'[ext_resource type="{kind}"{uid_part} path="{path}" id="{rid}"]')
        return rid

    def node(self, name, kind=None, props=None, instance=None, parent="."):
        assert name not in self.names, name
        self.names.add(name)
        header = f'[node name="{name}"'
        if kind:
            header += f' type="{kind}"'
        header += f' parent="{parent}"'
        if instance:
            header += f' instance=ExtResource("{instance}")'
        header += "]"
        lines = [header]
        for key, value in (props or {}).items():
            lines.append(f"{key} = {value}")
        self.nodes.append("\n".join(lines))

    def write(self, path, uid=None):
        uid_part = f' uid="{uid}"' if uid else ""
        out = [f"[gd_scene load_steps={len(self.ext) + 1} format=3{uid_part}]", ""]
        out += self.ext
        out.append("")
        out.append('[node name="Main" type="Node2D"]')
        out.append("")
        for node in self.nodes:
            out.append(node)
            out.append("")
        Path(path).write_text("\n".join(out))


def vec(x, y):
    return f"Vector2({x:g}, {y:g})"


def color(r, g, b, a=1.0):
    return f"Color({r:g}, {g:g}, {b:g}, {a:g})"


S = Scene()
PLAYER = S.ext_res("PackedScene", "res://playerr.tscn", "1_player", "uid://b50evv40bm1pk")
DUMMY = S.ext_res("PackedScene", "res://training_dummy.tscn", "2_dummy", "uid://dhdb26xjccjmn")
SUN = S.ext_res("PackedScene", "res://sun_enemy.tscn", "3_sun")
JUNGLE = S.ext_res("Script", "res://jungle_background.gd", "4_jungle")
HUD = S.ext_res("Script", "res://hud.gd", "5_hud")
MUSIC = S.ext_res("Script", "res://music_player.gd", "6_music")
PAUSE = S.ext_res("Script", "res://pause_menu.gd", "7_pause")
HAZARD = S.ext_res("Script", "res://hazard.gd", "8_hazard")
CHECKPOINT = S.ext_res("Script", "res://checkpoint.gd", "9_checkpoint")
SPAWNER = S.ext_res("Script", "res://boss_spawner.gd", "10_spawner")
DEMO = S.ext_res("Script", "res://demo_complete.gd", "11_demo")
CHASER = S.ext_res("Script", "res://chaser_dummy.gd", "12_chaser")
PLATFORM_SCRIPT = S.ext_res("Script", "res://platform.gd", "13_platform")
SIGN = S.ext_res("Script", "res://tutorial_sign.gd", "14_sign")

counters = {}


def unique(prefix):
    counters[prefix] = counters.get(prefix, 0) + 1
    return f"{prefix}{counters[prefix]}"


def block(name, x0, x1, y_top, y_bottom, style=GROUND):
    S.node(name or unique("Block"), "StaticBody2D", {
        "position": vec((x0 + x1) / 2, (y_top + y_bottom) / 2),
        "collision_layer": 2,
        "script": f'ExtResource("{PLATFORM_SCRIPT}")',
        "size": vec(x1 - x0, y_bottom - y_top),
        "style": style,
    })


def platform(name, x0, x1, y_top, thickness=20):
    block(name, x0, x1, y_top, y_top + thickness, PLATFORM)


def thorns(name, x0, x1, y, damage=10):
    S.node(name or unique("Thorns"), "Area2D", {
        "position": vec((x0 + x1) / 2, y),
        "script": f'ExtResource("{HAZARD}")',
        "size": vec(x1 - x0, 18),
        "damage": damage,
    })


def sign(name, x, y, title, text, width=320):
    S.node(name, "Node2D", {
        "position": vec(x, y),
        "script": f'ExtResource("{SIGN}")',
        "text": f'"{esc(text)}"',
        "title": f'"{esc(title)}"',
        "panel_width": f"{width:g}",
    })


def checkpoint(name, x, y):
    S.node(name, "Area2D", {"position": vec(x, y), "script": f'ExtResource("{CHECKPOINT}")'})


def dummy(name, x, y, **props):
    values = {"position": vec(x, y)}
    for key, value in props.items():
        if isinstance(value, bool):
            values[key] = "true" if value else "false"
        elif isinstance(value, tuple):
            values[key] = vec(*value)
        else:
            values[key] = f"{value:g}" if isinstance(value, float) else str(value)
    S.node(name or unique("Dummy"), None, values, instance=DUMMY)


def shooter(name, x, y, direction, interval=2.2, is_aerial=False, **props):
    dummy(name, x, y, aerial=is_aerial, shoot_interval=interval, shoot_direction=direction, **props)


def chaser(name, x, y, **props):
    values = {"position": vec(x, y), "script": f'ExtResource("{CHASER}")'}
    values.update({key: f"{value:g}" if isinstance(value, float) else str(value) for key, value in props.items()})
    S.node(name or unique("Chaser"), "Area2D", values)


def floor_title(name, x, y, text):
    S.node(name, "Label", {
        "offset_left": f"{x:g}", "offset_top": f"{y:g}",
        "offset_right": f"{x + 900:g}", "offset_bottom": f"{y + 60:g}",
        "theme_override_colors/font_color": color(1, 0.88, 0.55, 0.55),
        "theme_override_colors/font_outline_color": color(0.05, 0.08, 0.05, 0.6),
        "theme_override_constants/outline_size": 8,
        "theme_override_font_sizes/font_size": 34,
        "text": f'"{esc(text)}"',
    })


def background(**props):
    values = {"script": f'ExtResource("{JUNGLE}")'}
    values.update({key: f"{value:g}" for key, value in props.items()})
    S.node("JungleBackground", "ParallaxBackground", values)


def player_and_ui(x, y, demo_props=None):
    """Rengar, HUD, música, menú de pausa y pantalla final (siempre al final de la escena)."""
    S.node("Playerr", None, {"position": vec(x, y)}, instance=PLAYER)
    S.node("HUD", "CanvasLayer", {"script": f'ExtResource("{HUD}")'})
    S.node("Music", "AudioStreamPlayer", {
        "process_mode": 3, "script": f'ExtResource("{MUSIC}")', "volume_db": "-6.0",
        "bus": '&"Music"',
    })
    S.node("PauseMenu", "CanvasLayer", {"script": f'ExtResource("{PAUSE}")'})
    props = {"script": f'ExtResource("{DEMO}")'}
    props.update(demo_props or {})
    S.node("DemoComplete", "CanvasLayer", props)
