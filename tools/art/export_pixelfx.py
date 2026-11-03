#!/usr/bin/env python3
"""Exporta los efectos de PixelFX (https://github.com/patch-gg/pixelfx, MIT) que usa el juego.

Uso (desde la raíz del proyecto, con Node 18+):
    python3 tools/art/export_pixelfx.py --pixelfx /ruta/a/pixelfx [nombre ...]

Por cada efecto de EFFECTS:
  1. `node tools/render.mjs <id> --sheet --no-actor` en la copia de PixelFX (a una carpeta temporal).
  2. Elige los fotogramas [start:end:step] (las colas de humo largas se cortan).
  3. Si `grey`, pasa el color a luminancia: el juego lo tiñe en vivo con la paleta del golpe
     (pixel_fx.gd, shader de mapa de degradado).
  4. Recorta todos los fotogramas al rectángulo común con contenido y los vuelve a empaquetar.
Escribe assets/fx/pixelfx/<nombre>.png y pixel_fx_data.gd (tamaño, columnas, fps y pivote de cada hoja).
"""

import argparse
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

PROJECT = Path(__file__).resolve().parents[2]
OUT_DIR = PROJECT / "assets" / "fx" / "pixelfx"
DATA_SCRIPT = PROJECT / "pixel_fx_data.gd"
MAX_SHEET_WIDTH = 2048

# nombre: (id de PixelFX, gris, inicio, fin, paso, opciones extra)
EFFECTS = {
    # Golpes: chispa ligera, golpe contundente y crítico (teñidos con la paleta del golpe).
    "hit_spark": ("impacts/hit-spark", True, 0, 16, 1, {}),
    "hit_heavy": ("impacts/blunt-hit", True, 0, 22, 1, {}),
    "crit": ("impacts/crit-hit", True, 0, 20, 1, {}),
    "parry": ("impacts/parry", False, 0, 26, 1, {}),
    "shield": ("impacts/shield-block", True, 0, 30, 1, {}),
    "bullet_impact": ("impacts/bullet-impact", True, 0, 20, 1, {}),
    # Polvo de aterrizaje, nube de desaparición y estallido de energía (teñidos).
    "dust": ("impacts/heavy-landing", True, 0, 34, 1, {}),
    "poof": ("spawn/poof", True, 0, 40, 1, {}),
    "burst": ("explosions/plasma-explosion", True, 0, 40, 1, {}),
    "collect": ("pickups/collect-burst", True, 0, 34, 1, {}),
    # Explosiones con sus colores de fuego.
    "explosion": ("explosions/small-explosion", False, 0, 72, 1, {}),
    "big_explosion": ("explosions/big-explosion", False, 0, 100, 2, {}),
    "zap": ("lightning/zap-hit", True, 0, 28, 1, {}),
    # Curación, aparición de refuerzos y carga de energía.
    "heal": ("holy/heal-aoe", True, 10, 72, 1, {}),
    "warp_in": ("spawn/spawn-portal", True, 0, 100, 2, {}),
    "charge": ("lightning/charge-up", True, 0, 64, 1, {}),
    # Mundo espiritual del sol: soles que laten (bucle) y columnas de lava que brotan.
    "sunburst": ("holy/sunburst", False, 0, 120, 2, {}),
    "flame_pillar": ("fire/flame-pillar", False, 20, 110, 2, {}),
}


def render(pixelfx, effect_id, extra, tmp):
    command = ["node", "tools/render.mjs", effect_id, "--sheet", "--no-actor", "--max", "2", "--out", str(tmp)]
    if extra:
        command += ["--opts", json.dumps(extra)]
    subprocess.run(command, cwd=pixelfx, check=True, stdout=subprocess.DEVNULL)
    name = effect_id.split("/")[1]
    folder = Path(tmp) / effect_id
    meta = json.loads((folder / f"{name}.json").read_text())
    return Image.open(folder / f"{name}.png").convert("RGBA"), meta


def to_grey(frame):
    # Luminancia en RGB y alfa intacto: el shader del juego la usa para elegir el color de la paleta.
    r, g, b, a = frame.split()
    luma = Image.merge("RGB", (r, g, b)).convert("L")
    return Image.merge("RGBA", (luma, luma, luma, a))


def export(name, spec, pixelfx, tmp):
    effect_id, grey, start, end, step, extra = spec
    sheet, meta = render(pixelfx, effect_id, extra, tmp)
    info = meta["meta"]["pixelfx"]
    w, h = info["frameSize"]
    frames = []
    for entry in meta["frames"][start:end:step]:
        rect = entry["frame"]
        frame = sheet.crop((rect["x"], rect["y"], rect["x"] + rect["w"], rect["y"] + rect["h"]))
        frames.append(to_grey(frame) if grey else frame)
    # Rectángulo común con contenido (+2 px de margen) para no guardar espacio vacío.
    box = None
    for frame in frames:
        bbox = frame.getchannel("A").getbbox()
        if bbox:
            box = bbox if box is None else (min(box[0], bbox[0]), min(box[1], bbox[1]), max(box[2], bbox[2]), max(box[3], bbox[3]))
    box = box or (0, 0, w, h)
    box = (max(box[0] - 2, 0), max(box[1] - 2, 0), min(box[2] + 2, w), min(box[3] + 2, h))
    cw, ch = box[2] - box[0], box[3] - box[1]
    columns = max(1, min(len(frames), MAX_SHEET_WIDTH // cw))
    rows = (len(frames) + columns - 1) // columns
    out = Image.new("RGBA", (columns * cw, rows * ch), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        out.paste(frame.crop(box), ((index % columns) * cw, (index // columns) * ch))
    out.save(OUT_DIR / f"{name}.png", optimize=True)
    pivot = (info["pivot"][0] - box[0], info["pivot"][1] - box[1])
    fps = info["fps"] / step
    print(f"{name:14s} {effect_id:28s} {len(frames):3d} fotogramas {cw}x{ch}  {columns * cw}x{rows * ch}")
    return {"frame": (cw, ch), "columns": columns, "count": len(frames), "fps": fps, "pivot": pivot, "grey": grey, "source": effect_id}


def write_data(data):
    lines = [
        "extends RefCounted",
        "",
        "# Generado por tools/art/export_pixelfx.py: hojas de PixelFX (MIT, patch-gg/pixelfx) en assets/fx/pixelfx.",
        "# frame = tamaño de cada fotograma, pivot = origen del efecto dentro del fotograma (los pies o el centro).",
        "",
        "const SHEETS := {",
    ]
    for name, d in sorted(data.items()):
        lines.append(
            f'\t"{name}": {{"frame": Vector2({d["frame"][0]}, {d["frame"][1]}), "columns": {d["columns"]}, "count": {d["count"]}, '
            f'"fps": {d["fps"]:g}, "pivot": Vector2({d["pivot"][0]}, {d["pivot"][1]}), "grey": {"true" if d["grey"] else "false"}}},  # {d["source"]}'
        )
    lines.append("}")
    DATA_SCRIPT.write_text("\n".join(lines) + "\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--pixelfx", required=True, help="copia local de github.com/patch-gg/pixelfx")
    parser.add_argument("names", nargs="*", help="solo estos efectos (por defecto, todos)")
    args = parser.parse_args()
    pixelfx = Path(args.pixelfx).resolve()
    if not (pixelfx / "tools" / "render.mjs").exists():
        sys.exit(f"No es una copia de PixelFX: {pixelfx}")
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    shutil.copy(pixelfx / "LICENSE", OUT_DIR / "LICENSE-pixelfx.txt")
    names = args.names or list(EFFECTS)
    data = {}
    # Las hojas que no se regeneran conservan sus datos actuales.
    if DATA_SCRIPT.exists() and args.names:
        import re
        for line in DATA_SCRIPT.read_text().splitlines():
            match = re.match(r'\t"(\w+)": \{"frame": Vector2\((\d+), (\d+)\), "columns": (\d+), "count": (\d+), "fps": ([\d.]+), "pivot": Vector2\((-?\d+), (-?\d+)\), "grey": (\w+)\},  # (\S+)', line)
            if match and match.group(1) not in names:
                g = match.groups()
                data[g[0]] = {"frame": (int(g[1]), int(g[2])), "columns": int(g[3]), "count": int(g[4]), "fps": float(g[5]),
                              "pivot": (int(g[6]), int(g[7])), "grey": g[8] == "true", "source": g[9]}
    with tempfile.TemporaryDirectory() as tmp:
        for name in names:
            data[name] = export(name, EFFECTS[name], pixelfx, tmp)
    write_data(data)


if __name__ == "__main__":
    main()
