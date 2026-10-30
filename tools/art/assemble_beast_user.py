#!/usr/bin/env python3
"""Hojas de la bestia desde la hoja propuesta por el usuario (fondo magenta, 4 filas).

Fila 1: 5 cabezas con la llama creciendo (pesados, picada y ejecuciones) -> viridy_beast_head_v2.png.
Filas 2-4: bestia completa (2 y 3 arremetiendo, 4 agachada al frenar) -> viridy_wrath_beast_v2.png.
Se quita el magenta (con su halo rosado), cada figura se separa por componentes conectados y los trozos de
llama sueltos van con la figura más cercana. Celdas de 768 × 512 en una fila. Anclas: el frente de la cabeza
(las fauces) queda fijo y la llama crece hacia atrás.

Uso:  python3 tools/art/assemble_beast_user.py [~/ruby1_referencias/bestia/usuario_bestia_v1.png]
"""
from collections import deque
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUTPUT = os.path.join(ROOT, "assets", "sprites", "player", "viridy")
SOURCE = os.path.expanduser("~/ruby1_referencias/bestia/usuario_bestia_v1.png")
CELL = (768, 512)
KEY = (235, 3, 225)
# Cabezas: casi el tamaño de la cabeza anterior, con margen para la llama más larga; frente en x = 610, centrada en y = 256.
HEAD_SCALE = 1.4
HEAD_FRONT = 610
# Bestia completa: la boca de Wrath está 60 px por delante del centro (unos 250 px de celda).
BEAST_SCALE = 1.05
BEAST_FRONT = 660
MIDDLE = 256
ALPHA = 40


def unkey(image):
    """Magenta fuera: alfa por distancia al color clave y sin el tinte rosado del borde."""
    image = image.convert("RGBA")
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, _ = pixels[x, y]
            distance = max(abs(r - KEY[0]), abs(g - KEY[1]), abs(b - KEY[2]))
            magenta = min(r, b) - g
            if distance < 70:
                pixels[x, y] = (0, 0, 0, 0)
            elif magenta > 8:
                # Borde mezclado con el fondo: el magenta se vuelve el verde oscuro del contorno, más transparente.
                alpha = max(0, min(255, 255 - magenta * 3))
                pixels[x, y] = (round(g * 0.45), g, round(g * 0.5), alpha)
    return image


def figures(band, count):
    width, height = band.size
    alpha = band.getchannel("A").load()
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
    big = sorted(order[:count], key=lambda i: min(x for x, _ in parts[i]))
    spans = [(min(x for x, _ in parts[i]), max(x for x, _ in parts[i])) for i in big]
    owner = {index: frame for frame, index in enumerate(big)}
    for index in order[count:]:
        middle = sum(x for x, _ in parts[index]) / len(parts[index])
        # La llama suelta pertenece al frame cuyo tramo la contiene (o el más cercano).
        owner[index] = min(range(count), key=lambda f: 0 if spans[f][0] <= middle <= spans[f][1] else min(abs(middle - spans[f][0]), abs(middle - spans[f][1])))
    pieces = [Image.new("RGBA", band.size, (0, 0, 0, 0)) for _ in range(count)]
    source = band.load()
    for index, pixels in enumerate(parts):
        target = pieces[owner[index]].load()
        for x, y in pixels:
            target[x, y] = source[x, y]
    # Halo tenue (alfa bajo) junto a cada figura.
    for y in range(height):
        for x in range(width):
            if label[y][x] == -1 and source[x, y][3] > 0:
                frame = min(range(count), key=lambda f: 0 if spans[f][0] <= x <= spans[f][1] else min(abs(x - spans[f][0]), abs(x - spans[f][1])))
                pieces[frame].load()[x, y] = source[x, y]
    return pieces


def place(piece, scale, front, middle_of):
    """Escala y coloca: el borde delantero en `front` y el centro vertical de `middle_of` en MIDDLE."""
    small = piece.resize((round(piece.width * scale), round(piece.height * scale)), Image.LANCZOS)
    box = small.getbbox()
    head = small.crop((max(box[2] - middle_of, box[0]), box[1], box[2], box[3])).getbbox()
    center_y = box[1] + (head[1] + head[3]) / 2 if head else (box[1] + box[3]) / 2
    offset = (round(front - box[2]), round(MIDDLE - center_y))
    cell = Image.new("RGBA", CELL, (0, 0, 0, 0))
    cell.alpha_composite(small, dest=(max(offset[0], 0), max(offset[1], 0)), source=(max(-offset[0], 0), max(-offset[1], 0)))
    return cell


def sheet(cells):
    result = Image.new("RGBA", (CELL[0] * len(cells), CELL[1]), (0, 0, 0, 0))
    for index, cell in enumerate(cells):
        result.alpha_composite(cell, dest=(CELL[0] * index, 0))
    return result


def main():
    source = unkey(Image.open(sys.argv[1] if len(sys.argv) > 1 else SOURCE))
    band = source.height / 4
    rows = [source.crop((0, round(i * band), source.width, round((i + 1) * band))) for i in range(4)]
    heads = [place(piece, HEAD_SCALE, HEAD_FRONT, 150) for piece in figures(rows[0], 5)]
    sheet(heads).save(os.path.join(OUTPUT, "viridy_beast_head_v2.png"))
    beasts = []
    for row, count in ((rows[1], 4), (rows[2], 3), (rows[3], 4)):
        # La cabeza (lo delantero de la bestia) fija la altura: el cuerpo corre detrás.
        beasts += [place(piece, BEAST_SCALE, BEAST_FRONT, 170) for piece in figures(row, count)]
    sheet(beasts).save(os.path.join(OUTPUT, "viridy_wrath_beast_v2.png"))
    for name, cells in (("cabezas", heads), ("bestia", beasts)):
        print(name, [cell.getbbox() for cell in cells])


if __name__ == "__main__":
    main()
