#!/usr/bin/env python3
"""Normaliza una hoja de sprites de Rengar (por ejemplo, generada por IA) al formato estándar del juego.

Formato estándar: una fila de celdas de 768x768 px, fondo transparente, Rengar de pie mide 384 px, los
pies de cada frame en la línea y = 704 y al menos 48 px libres a los lados y arriba. Ningún frame se mete
en la celda del vecino.

Qué hace con la hoja de entrada (da igual su tamaño o cómo estén repartidos los frames):
  1. Quita el ruido invisible (píxeles casi transparentes) y, con --quitar-fondo, un fondo de color liso.
  2. Separa cada frame por sus manchones de píxeles (aunque se pisen las "celdas" de la IA) y le asigna
     el polvo, chispas y trozos sueltos al frame más cercano.
  3. Escala toda la hoja con un único factor para que Rengar quede del tamaño del juego (--animacion o --alto).
  4. Centra cada frame en su celda y apoya los pies en la línea de suelo.

Uso (desde la raíz del proyecto):
  python3 tools/normalize_sheet.py hoja_ia.png assets/sprites/player/reng_sprint.png --frames 3 --animacion sprint
  python3 tools/normalize_sheet.py hoja_ia.png salida.png --frames 8 --filas 2 --alto 330 --vista-previa vista.png

Al terminar imprime la línea para movimiento.gd.
"""
import argparse
import math
import sys
from collections import deque

from PIL import Image, ImageDraw

CELL = 768
STANDING_HEIGHT = 384
BASELINE = 704
MARGIN = 48
OPAQUE = 20  # alfa mínimo para contar un píxel como dibujo
CHARACTER_VISUAL_SCALE = 0.18  # el de movimiento.gd
# Escala en el juego de una hoja normalizada: Rengar de pie (384 px) mide lo mismo que la idle actual.
IN_GAME_SCALE = 68.25 / STANDING_HEIGHT

# Alto del cuerpo del frame más alto de cada animación, en px de la hoja normalizada, para que se vea
# del mismo tamaño que la animación actual (medido sobre las hojas y escalas de movimiento.gd).
HEIGHTS = {
    "idle": 384, "proud": 407, "walk": 381, "sprint": 353, "sprint_brake": 237, "jump_squat": 306,
    "jump": 359, "fall": 359, "frontflip": 359, "long_jump": 377, "wall_jump": 377, "wall_slide": 451,
    "wallride": 437, "mantle": 342, "spin": 268, "charge_idle": 237, "charge": 294, "dash": 174,
    "light_hit": 323, "light_hit_2": 323, "light_finisher": 323, "knife_throw": 323, "ground_heavy": 398,
    "heavy_aerial": 482, "uppercut": 538, "backflip": 414, "roar": 398,
}


def fail(message):
    print("ERROR:", message, file=sys.stderr)
    sys.exit(1)


def label_components(alpha, width, height):
    """Manchones de píxeles con alfa > 0 (vecindad de 8). Devuelve listas de índices planos."""
    data = alpha.tobytes()
    seen = bytearray(width * height)
    components = []
    for start in range(width * height):
        if not data[start] or seen[start]:
            continue
        seen[start] = 1
        stack = [start]
        pixels = []
        while stack:
            index = stack.pop()
            pixels.append(index)
            x = index % width
            for neighbor in (index - width, index + width):
                if 0 <= neighbor < width * height and data[neighbor] and not seen[neighbor]:
                    seen[neighbor] = 1
                    stack.append(neighbor)
            if x > 0:
                for neighbor in (index - 1, index - width - 1, index + width - 1):
                    if 0 <= neighbor < width * height and data[neighbor] and not seen[neighbor]:
                        seen[neighbor] = 1
                        stack.append(neighbor)
            if x < width - 1:
                for neighbor in (index + 1, index - width + 1, index + width + 1):
                    if 0 <= neighbor < width * height and data[neighbor] and not seen[neighbor]:
                        seen[neighbor] = 1
                        stack.append(neighbor)
        components.append(pixels)
    return components


def remove_background(image, tolerance):
    """Borra el fondo liso: todo lo parecido al color de las esquinas que se toca con el borde."""
    width, height = image.size
    pixels = image.load()
    corners = [pixels[0, 0], pixels[width - 1, 0], pixels[0, height - 1], pixels[width - 1, height - 1]]
    background = tuple(sorted(c[i] for c in corners)[1] for i in range(3))

    def is_background(color):
        return color[3] > 0 and max(abs(color[i] - background[i]) for i in range(3)) <= tolerance

    queue = deque()
    seen = set()
    for x in range(width):
        queue.extend([(x, 0), (x, height - 1)])
    for y in range(height):
        queue.extend([(0, y), (width - 1, y)])
    removed = 0
    while queue:
        point = queue.popleft()
        if point in seen:
            continue
        seen.add(point)
        x, y = point
        if not is_background(pixels[x, y]):
            continue
        pixels[x, y] = (0, 0, 0, 0)
        removed += 1
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < width and 0 <= ny < height and (nx, ny) not in seen:
                queue.append((nx, ny))
    return removed, background


def main():
    sys.stdout.reconfigure(line_buffering=True)
    parser = argparse.ArgumentParser(description="Normaliza una hoja de sprites de Rengar al formato del juego.")
    parser.add_argument("entrada")
    parser.add_argument("salida")
    parser.add_argument("--frames", type=int, required=True, help="cuántos frames tiene la hoja")
    parser.add_argument("--filas", type=int, default=1, help="filas de la hoja de entrada (los frames se leen por filas)")
    size = parser.add_mutually_exclusive_group(required=True)
    size.add_argument("--animacion", choices=sorted(HEIGHTS), help="toma el tamaño de la animación actual del juego")
    size.add_argument("--alto", type=float, help="alto en px del cuerpo del frame más alto (de pie = 384)")
    parser.add_argument("--quitar-fondo", action="store_true", help="borra un fondo de color liso (si la IA no dio transparencia)")
    parser.add_argument("--tolerancia-fondo", type=int, default=24)
    parser.add_argument("--conservar-altura", action="store_true",
                        help="mantiene la subida/bajada entre frames (saltos) en vez de apoyar cada frame en el suelo")
    parser.add_argument("--vista-previa", help="guarda también una imagen con las celdas y la línea de suelo")
    args = parser.parse_args()

    image = Image.open(args.entrada).convert("RGBA")
    width, height = image.size
    print(f"Entrada: {args.entrada} ({width}x{height}), {args.frames} frames en {args.filas} fila(s)")

    if args.quitar_fondo:
        removed, background = remove_background(image, args.tolerancia_fondo)
        print(f"Fondo {background} borrado: {removed} px")
    alpha = image.getchannel("A")
    if alpha.getextrema()[0] > OPAQUE:
        fail("la imagen no tiene transparencia (el fondo es opaco). Prueba con --quitar-fondo.")

    components = label_components(alpha, width, height)
    alpha_data = alpha.tobytes()
    components = [c for c in components if max(alpha_data[i] for i in c) > OPAQUE]
    components.sort(key=len, reverse=True)

    def span(pixels):
        xs = [i % width for i in pixels]
        return f"x {min(xs)}..{max(xs)}"

    stuck_hint = ("Seguramente hay frames pegados entre sí (se tocan y cuentan como una sola figura): sepáralos "
                  "unos píxeles en un editor o pide a la IA más espacio entre frames. Si no, revisa --frames.")
    if len(components) < args.frames:
        fail(f"solo hay {len(components)} figura(s) para {args.frames} frames; la más grande ocupa "
             f"{span(components[0])}.\n{stuck_hint}")

    # Cuerpos: los N manchones más grandes, uno por frame, ordenados por filas y luego de izquierda a derecha.
    bodies = components[:args.frames]
    if len(bodies[-1]) < len(bodies[0]) * 0.2:
        fail(f"una de las {args.frames} figuras principales es muy pequeña ({len(bodies[-1])} px frente a "
             f"{len(bodies[0])} px, que ocupa {span(bodies[0])}).\n{stuck_hint}")
    if len(components) > args.frames and len(components[args.frames]) > len(bodies[-1]) * 0.5:
        print(f"AVISO: hay una figura extra grande ({len(components[args.frames])} px); se toma como parte del "
              f"frame más cercano. Revisa la vista previa.")
    row_height = height / args.filas

    def centroid(pixels):
        return (sum(i % width for i in pixels) / len(pixels), sum(i // width for i in pixels) / len(pixels))

    bodies.sort(key=lambda b: (int(centroid(b)[1] // row_height), centroid(b)[0]))
    columns = math.ceil(args.frames / args.filas)
    rows_found = [int(centroid(b)[1] // row_height) for b in bodies]
    if any(rows_found.count(r) > columns for r in set(rows_found)):
        fail("los frames no están repartidos en las filas indicadas; revisa --filas.")

    # El resto (polvo, chispas, trozos sueltos) va con el frame cuyo cuerpo tenga más cerca.
    samples = []
    for body in bodies:
        step = max(1, len(body) // 1500)
        samples.append([(i % width, i // width) for i in body[::step]])
    groups = [list(body) for body in bodies]
    for component in components[args.frames:]:
        cx, cy = centroid(component)
        nearest = min(range(args.frames), key=lambda k: min((x - cx) ** 2 + (y - cy) ** 2 for x, y in samples[k]))
        groups[nearest].extend(component)

    def bounds(pixels):
        xs = [i % width for i in pixels]
        ys = [i // width for i in pixels]
        return min(xs), min(ys), max(xs) + 1, max(ys) + 1

    body_heights = [bounds(b)[3] - bounds(b)[1] for b in bodies]
    target = HEIGHTS[args.animacion] if args.animacion else args.alto
    scale = target / max(body_heights)
    print(f"Escala x{scale:.3f} (el cuerpo más alto pasa de {max(body_heights)} a {target:.0f} px)")

    # Lienzo con relleno alrededor para poder pegar aunque un frame se salga (luego se avisa y se recorta).
    pad = CELL
    canvas = Image.new("RGBA", (CELL * args.frames + 2 * pad, CELL + 2 * pad), (0, 0, 0, 0))
    problems = []
    lowest_in_row = {}
    for body in bodies:
        row = int(centroid(body)[1] // row_height)
        lowest_in_row[row] = max(lowest_in_row.get(row, 0), bounds(body)[3])
    for k, (group, body) in enumerate(zip(groups, bodies)):
        left, top, right, bottom = bounds(group)
        mask = bytearray((right - left) * (bottom - top))
        for i in group:
            mask[(i // width - top) * (right - left) + (i % width - left)] = 255
        frame = Image.new("RGBA", (right - left, bottom - top), (0, 0, 0, 0))
        frame.paste(image.crop((left, top, right, bottom)), (0, 0), Image.frombytes("L", frame.size, bytes(mask)))
        new_size = (max(1, round(frame.width * scale)), max(1, round(frame.height * scale)))
        frame = frame.convert("RGBa").resize(new_size, Image.LANCZOS).convert("RGBA")

        # Horizontal: el centro de masa del cuerpo al centro de la celda (el cuerpo no tiembla entre frames).
        body_x = sum(i % width for i in body) / len(body)
        x = k * CELL + CELL / 2 - (body_x - left) * scale
        # Vertical: lo más bajo del cuerpo (los pies, sin contar el polvo) en la línea de suelo.
        body_bottom = bounds(body)[3]
        if args.conservar_altura:
            body_bottom = lowest_in_row[int(centroid(body)[1] // row_height)]
        y = BASELINE - (body_bottom - top) * scale
        x, y = round(x), round(y)
        canvas.alpha_composite(frame, (x + pad, y + pad))

        visible = frame.getchannel("A").point(lambda a: 255 if a > OPAQUE else 0).getbbox()
        if visible:
            cell_left = x + visible[0] - k * CELL
            cell_right = x + visible[2] - k * CELL
            cell_top = y + visible[1]
            cell_bottom = y + visible[3]
            if cell_left < 0 or cell_right > CELL or cell_top < 0 or cell_bottom > CELL:
                problems.append(f"frame {k + 1}: se sale de su celda (x {cell_left}..{cell_right}, y {cell_top}..{cell_bottom})")
            elif cell_left < MARGIN or cell_right > CELL - MARGIN or cell_top < MARGIN:
                print(f"AVISO: frame {k + 1} queda a menos de {MARGIN} px del borde "
                      f"(x {cell_left}..{cell_right}, y desde {cell_top}); cabe, pero va justo.")
        print(f"  frame {k + 1}: cuerpo {body_heights[k]} px de alto -> {body_heights[k] * scale:.0f} px")

    if problems:
        fail("con este tamaño no cabe en las celdas de 768 px:\n  " + "\n  ".join(problems)
             + "\nUsa un --alto más pequeño o pide a la IA una pose más compacta.")

    output = canvas.crop((pad, pad, pad + CELL * args.frames, pad + CELL))
    output.save(args.salida)
    print(f"Guardado: {args.salida} ({output.width}x{output.height})")

    if args.vista_previa:
        preview = Image.new("RGBA", output.size, (40, 44, 60, 255))
        preview.alpha_composite(output)
        draw = ImageDraw.Draw(preview)
        for k in range(1, args.frames):
            draw.line([(k * CELL, 0), (k * CELL, CELL)], fill=(255, 60, 60, 255), width=3)
        draw.line([(0, BASELINE), (output.width, BASELINE)], fill=(255, 220, 0, 255), width=2)
        preview.convert("RGB").save(args.vista_previa)
        print(f"Vista previa: {args.vista_previa}")

    cells = ", ".join(f"Vector2i({k}, 0)" for k in range(args.frames))
    visual = IN_GAME_SCALE / CHARACTER_VISUAL_SCALE
    print("\nPara movimiento.gd:")
    print(f"  _add_grid_animation(frames, ANIMACION, TEXTURA, Vector2({CELL}, {CELL}), {BASELINE}, [{cells}], FPS, BUCLE)")
    print(f"  y en ANIMATION_VISUAL_SCALES:  ANIMACION: {visual:.3f},")


if __name__ == "__main__":
    main()
