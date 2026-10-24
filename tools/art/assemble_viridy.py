#!/usr/bin/env python3
"""Recorta y alinea las hojas revisadas sin pintar poses ni interpolar fotogramas.

Uso: python3 tools/art/assemble_viridy.py /ruta/refined
Los PNG anteriores se conservan; esta tanda usa el sufijo _arcade.
"""
import argparse
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "assets/sprites/player/viridy"
DOCS = ROOT / "docs/art/viridy_refresh"
sys.path.insert(0, str(ROOT / "tools"))
from normalize_sheet import label_components


def split_sheet(path, columns, rows):
    image = Image.open(path).convert("RGBA")
    alpha = image.getchannel("A").point(lambda a: 255 if a >= 160 else 0)
    components = sorted(label_components(alpha, image.width, image.height), key=len, reverse=True)

    def bounds(points):
        xs, ys = [p % image.width for p in points], [p // image.width for p in points]
        return min(xs), min(ys), max(xs) + 1, max(ys) + 1

    if path.stem == "heavy":
        # En la separación hay DOS cuerpos grandes en la tercera celda.
        primary_count = 5
    else:
        primary_count = columns * rows
    primary = components[:primary_count]
    boxes = [bounds(c) for c in primary]
    owned = [list(c) for c in primary]
    for component in components[primary_count:]:
        if len(component) < 8:
            continue
        b = bounds(component)
        x, y = (b[0] + b[2]) / 2, (b[1] + b[3]) / 2
        def distance(box):
            dx, dy = max(box[0] - x, 0, x - box[2]), max(box[1] - y, 0, y - box[3])
            return dx * dx + dy * dy + 0.001 * ((x - (box[0] + box[2]) / 2) ** 2 + (y - (box[1] + box[3]) / 2) ** 2)
        owned[min(range(len(boxes)), key=lambda i: distance(boxes[i]))].extend(component)
    groups = [[] for _ in range(columns * rows)]
    if path.stem == "heavy":
        for pixels, b in zip(owned, boxes):
            col = min(columns - 1, int((b[0] + b[2]) * 0.5 / image.width * columns))
            row = min(rows - 1, int((b[1] + b[3]) * 0.5 / image.height * rows))
            groups[row * columns + col].extend(pixels)
    else:
        ordered = sorted(range(len(boxes)), key=lambda i: (int((boxes[i][1] + boxes[i][3]) * 0.5 / image.height * rows), boxes[i][0]))
        groups = [owned[i] for i in ordered]
    result = []
    original_alpha = image.getchannel("A").tobytes()
    for pixels in groups:
        if not pixels:
            raise ValueError(f"Celda vacía en {path}")
        mask = bytearray(image.width * image.height)
        for index in pixels:
            mask[index] = original_alpha[index]
        piece = image.copy()
        piece.putalpha(Image.frombytes("L", image.size, bytes(mask)))
        result.append(piece.crop(piece.getbbox()))
    return result


def pack(name, pieces, cell=(512, 512), baseline=480, height=350, center=False, scale=None):
    width, canvas_height = cell
    if scale is None:
        scale = min(height / pieces[0].height, (width - 48) / max(p.width for p in pieces), (baseline - 24) / max(p.height for p in pieces))
    sheet = Image.new("RGBA", (width * len(pieces), canvas_height))
    for i, piece in enumerate(pieces):
        piece = piece.resize((max(1, round(piece.width * scale)), max(1, round(piece.height * scale))), Image.Resampling.NEAREST)
        x = i * width + (width - piece.width) // 2
        y = (canvas_height - piece.height) // 2 if center else baseline - piece.height
        sheet.alpha_composite(piece, (x, y))
    path = ASSETS / f"viridy_{name}_arcade.png"
    sheet.save(path)
    print(path.name, sheet.size, "scale", round(scale, 3))
    return sheet, {"file": path.name, "count": len(pieces), "cell": list(cell), "crop_height": canvas_height if center else baseline}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("refined", type=Path)
    args = parser.parse_args()
    source = lambda name, cols, rows: split_sheet(args.refined / (name + ".png"), cols, rows)
    prepared = {}
    metadata = {}

    def save(name, pieces, **options):
        prepared[name], metadata[name] = pack(name, pieces, **options)

    run_a = source("run", 3, 2)[:3]
    run_b = source("run_opposite", 3, 1)
    # Las dos generaciones tienen distinta resolución: igualar altura por mitad de ciclo.
    ratio = run_a[0].height / run_b[0].height
    run_b = [p.resize((round(p.width * ratio), round(p.height * ratio)), Image.Resampling.NEAREST) for p in run_b]
    save("run", run_a + run_b, height=335)
    save("walk", source("walk", 4, 2), height=365)
    save("dash_claw", source("dash", 2, 2), height=320)
    save("hurt", source("hurt", 3, 1), height=360)
    save("light1", source("light1", 4, 1), height=340)
    save("light2", source("light2", 4, 1), height=340)
    save("light3", source("light3", 3, 1), height=450)
    save("liquid_beast", source("beast", 2, 2), cell=(768, 512), baseline=488, height=400, center=True)
    save("screw", source("screw", 3, 2), cell=(768, 768), baseline=704, height=440)
    metadata["screw"]["crop_height"] = 768
    heavy = source("heavy", 2, 2)
    # El tercer frame contiene el cuerpo ya abandonado, a la izquierda de la bestia.
    remnant = heavy[2].crop((0, 0, round(heavy[2].width * 0.49), heavy[2].height))
    remnant = remnant.crop(remnant.getbbox())
    detached = heavy[2].crop((round(heavy[2].width * 0.49), 0, heavy[2].width, heavy[2].height))
    # Las cajas del pie y de la cabeza se solapan: excluir restos del pie bajo la bestia.
    detached_alpha = detached.getchannel("A").point(lambda a: 255 if a >= 160 else 0)
    main_head = max(label_components(detached_alpha, detached.width, detached.height), key=len)
    head_bottom = max(index // detached.width for index in main_head) + 1
    detached = detached.crop((0, 0, detached.width, head_bottom))
    heavy[2] = detached.crop(detached.getbbox())
    save("ground_heavy", heavy, cell=(1024, 640), baseline=608, height=350)
    save("heavy_remnant", [remnant], height=230)

    DOCS.mkdir(parents=True, exist_ok=True)
    (DOCS / "atlases.json").write_text(json.dumps(metadata, indent=2) + "\n")
    preview = Image.new("RGB", (1200, len(prepared) * 150), (38, 42, 45))
    draw = ImageDraw.Draw(preview)
    for row, (name, sheet) in enumerate(prepared.items()):
        draw.text((8, row * 150 + 4), name, fill="white")
        thumb = sheet.copy()
        thumb.thumbnail((1180, 120), Image.Resampling.NEAREST)
        preview.paste(thumb, (10, row * 150 + 24), thumb)
    preview.save(DOCS / "contact.png")


if __name__ == "__main__":
    main()
