#!/usr/bin/env python3
"""Empaqueta las seis poses radiales sin recortar ni realinear por sus tentáculos.

Uso: python3 tools/art/assemble_screw_radial.py /ruta/refined/screw_radial.png
"""
import argparse
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "assets/sprites/player/viridy"
DOCS = ROOT / "docs/art/screw_radial_v3"
sys.path.insert(0, str(ROOT / "tools"))
from normalize_sheet import label_components


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    args = parser.parse_args()
    source = Image.open(args.source).convert("RGBA")
    assert source.size == (1536, 1024), "Se esperan seis celdas de 512 px en una cuadrícula 3 × 2."
    alpha = source.getchannel("A")
    components = label_components(alpha.point(lambda a: 255 if a >= 160 else 0), *source.size)
    components = sorted(components, key=len, reverse=True)[:6]
    assert len(components) == 6
    # Asignar cada silueta completa antes de cortar: una punta puede cruzar la cuadrícula.
    def slot(points):
        xs, ys = [p % source.width for p in points], [p // source.width for p in points]
        return (int((min(ys) + max(ys)) / source.height), min(xs))
    components.sort(key=slot)
    original_alpha = alpha.tobytes()
    sheet = Image.new("RGBA", (768 * 6, 768))
    for i in range(6):
        x, y = i % 3, i // 3
        mask = bytearray(source.width * source.height)
        for pixel in components[i]:
            mask[pixel] = original_alpha[pixel]
        owned = source.copy()
        owned.putalpha(Image.frombytes("L", source.size, bytes(mask)))
        # Mantener origen y escala de la cuadrícula; 16 px extra protegen las puntas.
        frame = owned.crop((x * 512 - 16, y * 512 - 16, (x + 1) * 512 + 16, (y + 1) * 512 + 16))
        frame = frame.resize((765, 765), Image.Resampling.NEAREST)
        sheet.alpha_composite(frame, (i * 768 + 1, 1))
    sheet.save(ASSETS / "viridy_screw_radial_v3.png")

    DOCS.mkdir(parents=True, exist_ok=True)
    old = Image.open(ASSETS / "viridy_screw_front_v2.png").convert("RGBA")
    preview = Image.new("RGB", (1536, 560), (28, 43, 35))
    draw = ImageDraw.Draw(preview)
    for row, (label, atlas) in enumerate([("v2 - conservada", old), ("v3 - tentaculos inferiores", sheet)]):
        draw.text((12, row * 280 + 8), label, fill="white")
        thumb = atlas.resize((1536, 256), Image.Resampling.NEAREST)
        preview.paste(thumb, (0, row * 280 + 24), thumb)
    preview.save(DOCS / "comparison.png")
    print(ASSETS / "viridy_screw_radial_v3.png")


if __name__ == "__main__":
    main()
