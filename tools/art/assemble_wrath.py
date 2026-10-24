#!/usr/bin/env python3
"""Empaqueta las cuatro poses de Wrath conservando el ancla de las fauces."""
import argparse
from pathlib import Path
from PIL import Image
from assemble_viridy import split_sheet

ROOT = Path(__file__).resolve().parents[2]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    args = parser.parse_args()
    pieces = split_sheet(args.source, 2, 2)
    factor = min(672 / max(p.width for p in pieces), 416 / max(p.height for p in pieces))
    atlas = Image.new("RGBA", (3072, 512))
    for i, piece in enumerate(pieces):
        piece = piece.resize((round(piece.width * factor), round(piece.height * factor)), Image.Resampling.NEAREST)
        atlas.alpha_composite(piece, (i * 768 + 720 - piece.width, (512 - piece.height) // 2))
    destination = ROOT / "assets/sprites/player/viridy/viridy_wrath_nature_v1.png"
    atlas.save(destination)
    print(destination)

if __name__ == "__main__":
    main()
