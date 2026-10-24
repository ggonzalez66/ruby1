#!/usr/bin/env python3
"""Ensambla el screw frontal, dash de alcance, sprint y slashes en archivos nuevos.

Uso: python3 tools/art/assemble_feedback_v2.py /ruta/refined
"""
import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps

from assemble_viridy import split_sheet

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "assets/sprites/player/viridy"
DOCS = ROOT / "docs/art/viridy_feedback_v2"


def pack(pieces, path, cell, baseline, height):
    factor = min(height / pieces[0].height, (cell[0] - 48) / max(p.width for p in pieces), (baseline - 24) / max(p.height for p in pieces))
    sheet = Image.new("RGBA", (cell[0] * len(pieces), cell[1]))
    for i, piece in enumerate(pieces):
        piece = piece.resize((round(piece.width * factor), round(piece.height * factor)), Image.Resampling.NEAREST)
        sheet.alpha_composite(piece, (i * cell[0] + (cell[0] - piece.width) // 2, baseline - piece.height))
    sheet.save(path)
    return sheet


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("refined", type=Path)
    args = parser.parse_args()
    source = lambda name, cols, rows: split_sheet(args.refined / (name + ".png"), cols, rows)
    outputs = {}
    metadata = {}

    def save(name, pieces, cell=(512, 512), baseline=480, height=335):
        file = "viridy_" + name + "_v2.png"
        outputs[name] = pack(pieces, ASSETS / file, cell, baseline, height)
        metadata[name] = {"file": file, "count": len(pieces), "cell": list(cell), "crop_height": baseline}

    a = source("run", 4, 2)
    b = source("run_opposite", 4, 1)
    # Cuatro claves con brazo cercano atrás y cuatro con él delante del pecho.
    # La segunda generación se revisó y solo aporta su cuarta pose al ciclo final.
    back = [a[i] for i in [0, 1, 2, 6]]
    forward = [a[i] for i in [4, 7, 3]]
    last = b[3]
    # Igualar resolución entre generaciones usando la pose equivalente de vuelo.
    ratio = a[3].height / last.height
    last = last.resize((round(last.width * ratio), round(last.height * ratio)), Image.Resampling.NEAREST)
    save("sprint_wolverine", back + forward + [last], height=335)
    save("dash_reach", source("dash", 4, 1), cell=(768, 512), height=320)
    save("screw_front", source("screw", 3, 2), cell=(768, 768), baseline=704, height=440)
    metadata["screw_front"]["crop_height"] = 768

    image = Image.open(args.refined / "slash.png").convert("RGBA")
    slash = Image.new("RGBA", (512 * 8, 512))
    for index in range(8):
        col, row = index % 4, index // 4
        frame = image.crop((round(col * image.width / 4), round(row * image.height / 2), round((col + 1) * image.width / 4), round((row + 1) * image.height / 2)))
        alpha = frame.getchannel("A").point(lambda a: a if a >= 200 else 0)
        # Neutralizar la saturación del halo, conservando el núcleo plateado/azul claro.
        gray = ImageOps.grayscale(frame)
        frame = ImageOps.colorize(gray, (16, 20, 28), (240, 249, 255)).convert("RGBA")
        frame.putalpha(alpha)
        frame = frame.resize((448, 448), Image.Resampling.NEAREST)
        slash.alpha_composite(frame, (index * 512 + 32, 32))
    slash.save(ASSETS / "viridy_claw_slashes_v2.png")
    outputs["claw_slashes"] = slash
    metadata["claw_slashes"] = {"file": "viridy_claw_slashes_v2.png", "count": 8, "cell": [512, 512], "crop_height": 512}

    DOCS.mkdir(parents=True, exist_ok=True)
    (DOCS / "atlases.json").write_text(json.dumps(metadata, indent=2) + "\n")
    preview = Image.new("RGB", (1500, 4 * 235), (35, 41, 43))
    draw = ImageDraw.Draw(preview)
    for row, (name, sheet) in enumerate(outputs.items()):
        draw.text((10, row * 235 + 5), name, fill="white")
        thumb = sheet.copy()
        thumb.thumbnail((1480, 200), Image.Resampling.NEAREST)
        preview.paste(thumb, (10, row * 235 + 28), thumb)
    preview.save(DOCS / "contact.png")
    print(json.dumps(metadata, indent=2))


if __name__ == "__main__":
    main()
