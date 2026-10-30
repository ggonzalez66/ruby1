#!/usr/bin/env python3
"""Hojas de las patadas 4 y 5 desde la hoja propuesta por el usuario (2 filas × 6 frames, fondo transparente).

Cada fila es una patada: guardia, recogida, recogida, golpe, recuperación, guardia. Los dibujos están en una
grilla de 1/6 del ancho; esa grilla es el ancla horizontal (el cuerpo no salta y la pierna sale hacia delante).
Se escala igual que los golpes ligeros y los pies más bajos de cada fila van a y = 480 en celdas de 768 × 512.

Uso:  python3 tools/art/assemble_kicks_user.py [~/ruby1_referencias/patadas/usuario_patadas_v1.png]
"""
from collections import deque
import os
import sys

from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUTPUT = os.path.join(ROOT, "assets", "sprites", "player", "viridy")
SOURCE = os.path.expanduser("~/ruby1_referencias/patadas/usuario_patadas_v1.png")
CELL = (768, 512)
FEET = 480
BODY_X = 384
# Alto de la guardia de la hoja (unos 285 px sin el halo) llevado al de la pose de golpe ligero 1 (294 px).
SCALE = 294 / 285
ALPHA = 40


def figures(row):
    """Máscaras de los 6 frames: componentes conectados del alfa. Las 6 piezas más grandes son las figuras;
    los trozos sueltos (llamas de la cola, puntas) van con la figura más cercana."""
    width, height = row.size
    alpha = row.getchannel("A").load()
    label = [[-1] * width for _ in range(height)]
    parts = []
    for y0 in range(height):
        for x0 in range(width):
            if label[y0][x0] != -1 or alpha[x0, y0] <= ALPHA:
                continue
            pixels, queue = [], deque([(x0, y0)])
            label[y0][x0] = len(parts)
            while queue:
                x, y = queue.popleft()
                pixels.append((x, y))
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < width and 0 <= ny < height and label[ny][nx] == -1 and alpha[nx, ny] > ALPHA:
                            label[ny][nx] = len(parts)
                            queue.append((nx, ny))
            parts.append(pixels)
    order = sorted(range(len(parts)), key=lambda i: -len(parts[i]))
    big = sorted(order[:6], key=lambda i: min(x for x, _ in parts[i]))
    centers = [sum(x for x, _ in parts[i]) / len(parts[i]) for i in big]
    owner = {index: frame for frame, index in enumerate(big)}
    for index in order[6:]:
        middle = sum(x for x, _ in parts[index]) / len(parts[index])
        owner[index] = min(range(6), key=lambda frame: abs(centers[frame] - middle))
    masks = [Image.new("L", row.size, 0) for _ in range(6)]
    for index, pixels in enumerate(parts):
        mask = masks[owner[index]].load()
        for x, y in pixels:
            mask[x, y] = 255
    # Se conserva el borde semitransparente (alfa bajo) alrededor de cada figura.
    return [mask.filter(ImageFilter.MaxFilter(7)) for mask in masks], row.width / 6


def main():
    source = Image.open(sys.argv[1] if len(sys.argv) > 1 else SOURCE).convert("RGBA")
    half = source.height // 2
    for index, name in enumerate(("viridy_kick1_v2_arcade.png", "viridy_kick2_v2_arcade.png")):
        row = source.crop((0, index * half, source.width, (index + 1) * half))
        masks, pitch = figures(row)
        # Pies: lo más bajo de las figuras (sin el halo tenue de alrededor).
        bottom = max(mask.getbbox()[3] for mask in masks) - 2
        sheet = Image.new("RGBA", (CELL[0] * 6, CELL[1]), (0, 0, 0, 0))
        for frame in range(6):
            piece = Image.new("RGBA", row.size, (0, 0, 0, 0))
            piece.paste(row, (0, 0), masks[frame])
            small = piece.resize((round(row.width * SCALE), round(row.height * SCALE)), Image.LANCZOS)
            center = (frame + 0.5) * pitch * SCALE
            offset = (round(BODY_X - center), round(FEET - bottom * SCALE))
            cell = Image.new("RGBA", CELL, (0, 0, 0, 0))
            cell.alpha_composite(small, dest=(max(offset[0], 0), max(offset[1], 0)),
                                 source=(max(-offset[0], 0), max(-offset[1], 0)))
            sheet.alpha_composite(cell, dest=(CELL[0] * frame, 0))
        sheet.save(os.path.join(OUTPUT, name))
        print(name, [sheet.crop((CELL[0] * f, 0, CELL[0] * (f + 1), CELL[1])).getbbox() for f in range(6)])


if __name__ == "__main__":
    main()
