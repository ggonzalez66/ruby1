#!/usr/bin/env python3
"""Empaqueta la jabalina de Viridy y cuatro llamas de lanza, conservando las hojas anteriores."""
import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw
from assemble_viridy import split_sheet

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "assets/sprites/player/viridy"
DOCS = ROOT / "docs/art/spirit_spear"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("refined", type=Path)
    args = parser.parse_args()
    poses = split_sheet(args.refined / "javelin_throw.png", 2, 2)
    factor = min(350 / max(p.height for p in poses[2:]), 704 / max(p.width for p in poses), 560 / max(p.height for p in poses))
    throw = Image.new("RGBA", (768 * 4, 640))
    for index, piece in enumerate(poses):
        piece = piece.resize((round(piece.width * factor), round(piece.height * factor)), Image.Resampling.NEAREST)
        throw.alpha_composite(piece, (index * 768 + (768 - piece.width) // 2, 608 - piece.height))
    throw.save(ASSETS / "viridy_javelin_throw_v1.png")

    pieces = split_sheet(args.refined / "spirit_spear.png", 2, 2)
    factor = min(680 / max(p.width for p in pieces), 160 / max(p.height for p in pieces))
    spear = Image.new("RGBA", (768 * 2, 192 * 2))
    for index, piece in enumerate(pieces):
        piece = piece.resize((round(piece.width * factor), round(piece.height * factor)), Image.Resampling.NEAREST)
        spear.alpha_composite(piece, ((index % 2) * 768 + 724 - piece.width, (index // 2) * 192 + (192 - piece.height) // 2))
    spear.save(ASSETS / "viridy_spirit_spear_v1.png")
    DOCS.mkdir(parents=True, exist_ok=True)
    metadata = {"throw": {"file": "viridy_javelin_throw_v1.png", "count": 4, "cell": [768, 640], "baseline": 608}, "spear": {"file": "viridy_spirit_spear_v1.png", "count": 4, "cell": [768, 192], "tip_x": 724}}
    (DOCS / "atlases.json").write_text(json.dumps(metadata, indent=2) + "\n")
    preview = Image.new("RGB", (1536, 500), (30, 42, 36))
    for sheet, area, at in [(throw, (1500, 340), (18, 24)), (spear, (1500, 130), (18, 366))]:
        sheet = sheet.copy()
        sheet.thumbnail(area, Image.Resampling.NEAREST)
        preview.paste(sheet, at, sheet)
    ImageDraw.Draw(preview).text((18, 6), "Viridy / spirit spear v1", fill="white")
    preview.save(DOCS / "contact.png")
    print(json.dumps(metadata, indent=2))


if __name__ == "__main__":
    main()
