#!/usr/bin/env python3
"""Prueba de tools/normalize_sheet.py con hojas "como las de la IA" armadas a partir de los sprites del repo.

Uso (desde la raíz del proyecto): python3 tests/tools/test_normalize_sheet.py
"""
import os
import subprocess
import sys
import tempfile

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from normalize_sheet import BASELINE, CELL, HEIGHTS, MARGIN, OPAQUE, label_components  # noqa: E402

checks = 0
fails = 0


def check(condition, label):
    global checks, fails
    checks += 1
    print("  OK  " if condition else "  FAIL", label)
    if not condition:
        fails += 1


def run(*args):
    return subprocess.run([sys.executable, os.path.join(ROOT, "tools", "normalize_sheet.py"), *args],
                          capture_output=True, text=True)


def frames_of(sheet_path, cell_width, count):
    sheet = Image.open(os.path.join(ROOT, sheet_path)).convert("RGBA")
    frames = []
    for k in range(count):
        frame = sheet.crop((k * cell_width, 0, (k + 1) * cell_width, sheet.height))
        frames.append(frame.crop(frame.getchannel("A").point(lambda a: 255 if a > OPAQUE else 0).getbbox()))
    return frames


def check_output(path, count, target, label):
    image = Image.open(path).convert("RGBA")
    check(image.size == (CELL * count, CELL), f"{label}: hoja de {count} celdas de {CELL} ({image.size})")
    body_heights = []
    for k in range(count):
        cell = image.crop((k * CELL, 0, (k + 1) * CELL, CELL))
        alpha = cell.getchannel("A")
        visible = alpha.point(lambda a: 255 if a > OPAQUE else 0).getbbox()
        check(visible and visible[0] >= MARGIN and visible[2] <= CELL - MARGIN and visible[1] >= MARGIN,
              f"{label} frame {k + 1}: dentro de la celda con margen ({visible})")
        components = label_components(alpha, CELL, CELL)
        data = alpha.tobytes()
        body = max((c for c in components if max(data[i] for i in c) > OPAQUE), key=len)
        ys = [i // CELL for i in body]
        body_heights.append(max(ys) + 1 - min(ys))
        check(abs(max(ys) + 1 - BASELINE) <= 2, f"{label} frame {k + 1}: pies en la línea de suelo (y {max(ys) + 1})")
    check(abs(max(body_heights) - target) <= 3, f"{label}: cuerpo más alto {max(body_heights)} px (objetivo {target})")


with tempfile.TemporaryDirectory() as tmp:
    print("== Hoja tipo IA: fondo opaco, 1536x1024, frames mal espaciados que se pisan en horizontal")
    frames = frames_of("assets/sprites/player/rengar/reng_sprintingNEW.png", 810, 3)
    scale = 0.55
    frames = [f.resize((round(f.width * scale), round(f.height * scale)), Image.LANCZOS) for f in frames]
    sheet = Image.new("RGBA", (1536, 1024), (236, 240, 232, 255))
    # Cada frame más ancho que su tercio de lienzo, a alturas distintas para que se pisen sin tocarse.
    for frame, (x, y) in zip(frames, [(20, 520), (430, 120), (1010, 560)]):
        sheet.alpha_composite(frame, (x, y))
    source = os.path.join(tmp, "ia.png")
    sheet.convert("RGB").save(source)
    output = os.path.join(tmp, "sprint.png")
    result = run(source, output, "--frames", "3", "--animacion", "sprint")
    check(result.returncode != 0 and "transparencia" in result.stderr, "sin --quitar-fondo avisa de que no hay transparencia")
    result = run(source, output, "--frames", "3", "--animacion", "sprint", "--quitar-fondo")
    check(result.returncode == 0, "con --quitar-fondo se normaliza" + ("" if result.returncode == 0 else ": " + result.stderr))
    if result.returncode == 0:
        check_output(output, 3, HEIGHTS["sprint"], "sprint IA")
        check("Vector2(768, 768), 704" in result.stdout, "imprime la línea para movimiento.gd")

    print("== Hoja de 2 filas (caminar, 8 frames)")
    output = os.path.join(tmp, "walk.png")
    result = run(os.path.join(ROOT, "assets/sprites/player/rengar/reng_walkingNew.png"), output, "--frames", "8", "--filas", "2", "--alto", "384")
    check(result.returncode == 0, "se normaliza" + ("" if result.returncode == 0 else ": " + result.stderr))
    if result.returncode == 0:
        check_output(output, 8, 384, "walk")

    print("== Frames pegados entre sí")
    frames = frames_of("assets/sprites/player/rengar/rengar_standing.png", 543, 3)
    sheet = Image.new("RGBA", (1800, 724), (0, 0, 0, 0))
    for k, frame in enumerate(frames):
        sheet.alpha_composite(frame, (k * (frame.width - 60) + 10, 724 - frame.height - 10))
    source = os.path.join(tmp, "pegados.png")
    sheet.save(source)
    result = run(source, os.path.join(tmp, "x.png"), "--frames", "3", "--animacion", "idle")
    check(result.returncode != 0 and "pegados" in result.stderr, "da error claro en vez de una hoja rota")

    print("== Pose demasiado grande para la celda")
    result = run(os.path.join(ROOT, "assets/sprites/player/rengar/reng_walkingNew.png"), os.path.join(tmp, "x.png"),
                 "--frames", "8", "--filas", "2", "--alto", "900")
    check(result.returncode != 0 and "no cabe" in result.stderr, "da error y no guarda nada")

print(f"RESULTADO: {checks - fails}/{checks} OK")
sys.exit(1 if fails else 0)
