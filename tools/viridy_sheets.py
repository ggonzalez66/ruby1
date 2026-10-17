#!/usr/bin/env python3
"""Arma las hojas de Viridy: transforma con tools/viridy.py cada región que el juego usa de las hojas de Rengar
y la pega en una hoja nueva del mismo tamaño y con las mismas posiciones (assets/sprites/player/viridy/),
para que movimiento.gd solo tenga que cambiar la ruta.

Las regiones salen de Godot (una línea "R|animación|frame|res://hoja|x|y|ancho|alto" por frame). Cada frame
transformado se guarda en --trabajo; si ya existe se reutiliza, así que se puede cortar y volver a lanzar.

Uso (desde la raíz del proyecto):
  python3 tools/viridy_sheets.py regiones.txt --trabajo ~/ruby1_referencias/viridy/tanda
"""
import argparse
import os
import sys
import time
from types import SimpleNamespace

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import viridy  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT_DIR = os.path.join(ROOT, "assets", "sprites", "player", "viridy")
# Hojas viejas (sprites de antes de la renovación); van aparte con --viejas.
SKIP = {"reng_light_hits-sheet.png", "reng-heavy.png", "reng_aerial_spinning-sheet.png", "reng_uppercut-sheet.png", "reng_dash_1.png"}
BORDER = 2  # px que se dejan vacíos en el borde de cada región (que nada asome a la celda vecina)
# Blanco que sobra del fondo de SD dentro del dibujo (encerrado entre piernas, suelo, armadura...).
WHITE = 232
TRAPPED_BACKGROUND = 120  # manchas blancas de al menos este tamaño (px) son fondo: se vuelven transparentes
HIGHLIGHT = (205, 240, 170)  # las más pequeñas son brillos sueltos: se pintan de jade claro


def clean_white(sheet):
    """Quita el fondo blanco atrapado dentro del dibujo y suaviza los brillos blancos sueltos."""
    width, height = sheet.size
    pixels = sheet.load()
    seen = bytearray(width * height)
    removed = recolored = 0
    for start_y in range(height):
        for start_x in range(width):
            index = start_y * width + start_x
            if seen[index]:
                continue
            seen[index] = 1
            r, g, b, a = pixels[start_x, start_y]
            if a == 0 or min(r, g, b) < WHITE:
                continue
            blob = [(start_x, start_y)]
            stack = [(start_x, start_y)]
            while stack:
                x, y = stack.pop()
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < width and 0 <= ny < height and not seen[ny * width + nx]:
                        color = pixels[nx, ny]
                        if color[3] > 0 and min(color[:3]) >= WHITE:
                            seen[ny * width + nx] = 1
                            blob.append((nx, ny))
                            stack.append((nx, ny))
            if len(blob) >= TRAPPED_BACKGROUND:
                for x, y in blob:
                    pixels[x, y] = (0, 0, 0, 0)
                removed += len(blob)
            else:
                for x, y in blob:
                    pixels[x, y] = HIGHLIGHT + (pixels[x, y][3],)
                recolored += len(blob)
    return removed, recolored


def read_regions(path, old_only=False):
    sheets = {}
    for line in open(path):
        if not line.startswith("R|"):
            continue
        _, animation, index, resource, x, y, width, height = line.strip().split("|")
        name = resource.split("/")[-1]
        if (name in SKIP) != old_only:
            continue
        region = (int(x), int(y), int(width), int(height))
        sheets.setdefault(name, {}).setdefault(region, f"{animation}{index}")
    return sheets


def main():
    parser = argparse.ArgumentParser(description="Arma las hojas de Viridy a partir de las de Rengar.")
    parser.add_argument("regiones")
    parser.add_argument("--trabajo", required=True, help="carpeta para los frames transformados")
    parser.add_argument("--solo-limpiar", action="store_true", help="solo pasa la limpieza de blancos a las hojas ya hechas")
    parser.add_argument("--viejas", action="store_true", help="transforma solo las hojas viejas (golpes ligeros, heavy, giro, dash...)")
    parser.add_argument("--semilla", type=int, default=7)
    parser.add_argument("--cambio", type=float, default=0.65)
    parser.add_argument("--fuerza-referencia", type=float, default=1.0)
    args = parser.parse_args()

    if args.solo_limpiar:
        for name in sorted(os.listdir(OUTPUT_DIR)):
            if name.endswith(".png"):
                path = os.path.join(OUTPUT_DIR, name)
                sheet = Image.open(path).convert("RGBA")
                removed, recolored = clean_white(sheet)
                sheet.save(path)
                print(f"{name}: {removed} px de fondo quitados, {recolored} px de brillos repintados", flush=True)
        return

    settings = SimpleNamespace(cambio=args.cambio, fuerza_referencia=args.fuerza_referencia, solo_estilo=False,
                               fuerza_control=0.7, fin_control=0.8, fuerza_lora=0.8, pasos=30, cfg=6.0)
    sheets = read_regions(args.regiones, args.viejas)
    total = sum(len(regions) for regions in sheets.values())
    os.makedirs(args.trabajo, exist_ok=True)
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    reference_path = os.path.join(args.trabajo, "viridis_ref.png")
    viridy.viridis_reference(reference_path)
    reference_name = viridy.upload_image(reference_path)
    print(f"ComfyUI: {viridy.SERVER}; {total} frames en {len(sheets)} hojas", flush=True)

    done = 0
    started = time.time()
    for name, regions in sorted(sheets.items()):
        source = Image.open(os.path.join(ROOT, "assets", "sprites", "player", name)).convert("RGBA")
        sheet = Image.new("RGBA", source.size, (0, 0, 0, 0))
        stem = os.path.splitext(name)[0].replace(" ", "_")
        for (x, y, width, height), label in sorted(regions.items()):
            done += 1
            frame_path = os.path.join(args.trabajo, f"{stem}_{x}_{y}.png")
            if not os.path.exists(frame_path):
                frame = source.crop((x, y, x + width, y + height))
                canvas, transform = viridy.to_canvas(viridy.pre_recolor(frame))
                input_path = os.path.join(args.trabajo, f"{stem}_{x}_{y}_entrada.png")
                canvas.save(input_path)
                data = viridy.run(viridy.build_workflow(settings, viridy.upload_image(input_path), reference_name, args.semilla))
                raw_path = os.path.join(args.trabajo, f"{stem}_{x}_{y}_crudo.png")
                with open(raw_path, "wb") as file:
                    file.write(data)
                result = viridy.paste_back(Image.open(raw_path), frame.size, transform)
                # Borde vacío para que nada se meta en la región vecina.
                cleared = Image.new("RGBA", result.size, (0, 0, 0, 0))
                inner = (BORDER, BORDER, result.width - BORDER, result.height - BORDER)
                cleared.paste(result.crop(inner), inner[:2])
                cleared.save(frame_path)
            sheet.alpha_composite(Image.open(frame_path).convert("RGBA"), (x, y))
            elapsed = time.time() - started
            print(f"[{done}/{total}] {name} {label} ({elapsed / 60:.1f} min)", flush=True)
        removed, recolored = clean_white(sheet)
        sheet.save(os.path.join(OUTPUT_DIR, name))
        print(f"  limpieza: {removed} px de fondo blanco quitados, {recolored} px de brillos blancos repintados", flush=True)
        print(f"Hoja guardada: assets/sprites/player/viridy/{name}", flush=True)
    print("TERMINADO", flush=True)


if __name__ == "__main__":
    main()
