#!/usr/bin/env python3
"""Sprites de armas (fase 2) a partir de las siluetas de los bocetos del usuario.

Cada arma se dibuja como silueta plana con su paleta (mango a la izquierda, cabeza a la derecha, agarre en
GRIP), ComfyUI la refina con img2img + ControlNet canny + LoRA de pixel art y el resultado se reduce a
1x, se limpia el fondo y se cuantiza la paleta. Salida: assets/weapons/<arma>.png.

Uso:  python3 tools/art/weapon_art.py [--armas sword axe] [--semilla 11] [--cambio 0.55] [--crudos DIR]
"""
import argparse
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
import viridy  # noqa: E402  (cliente de ComfyUI ya probado)

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "weapons")
SCALE = 4
# Lienzo a 1x y punto de agarre (pivote del sprite en el juego).
CANVAS = {"sword": (176, 80), "axe": (176, 120), "glaive": (196, 120), "hammer": (176, 120)}
GRIP = {"sword": (18, 40), "axe": (14, 60), "glaive": (14, 60), "hammer": (14, 60)}

STEEL = [(36, 58, 60), (92, 140, 136), (170, 210, 196), (228, 248, 236)]
WOOD = [(52, 34, 22), (98, 66, 40), (140, 100, 62)]
CLOTH = [(14, 18, 18), (44, 52, 50)]
BRONZE = [(92, 60, 24), (176, 124, 52), (226, 186, 104)]
JADE = [(22, 92, 62), (70, 190, 120), (170, 250, 190)]
OUTLINE = (12, 22, 20)

PROMPTS = {
    "sword": "a straight double-edged longsword, polished teal-tinted steel blade with a sharp point, bronze crossguard, "
             "dark cloth wrapped grip, bronze pommel with a small jade gem",
    "axe": "a heavy battle axe with one huge crescent moon shaped steel blade, the curved cutting edge parallel to the "
           "long wooden haft, bronze socket, dark cloth wrapped grip, jade gem",
    "glaive": "a long glaive polearm, a curved single-edged blade like a big cleaver point mounted on a long wooden pole, "
              "a small back hook, bronze collar, dark cloth wraps, jade gem",
    "hammer": "a massive war hammer with a big rectangular stone and steel block head, bronze bands, long wooden "
              "handle with dark cloth wraps and a pointed steel spike at the butt, jade gem",
}
STYLE = ("pixel art, 16-bit video game item sprite, side view, horizontal, handle on the left, single object, centered, "
         "clean dark outline, crisp shading, plain white background")
NEGATIVE = ("blurry, 3d render, photo, realistic, text, watermark, signature, hand, person, character, multiple objects, "
            "scenery, background, shadow, cropped, frame, border, purple, red")


def s(v):
    return v * SCALE


def poly(draw, points, fill, outline=OUTLINE, width=2):
    pts = [(s(x), s(y)) for x, y in points]
    draw.polygon(pts, fill=fill)
    draw.line(pts + [pts[0]], fill=outline, width=s(width) // 2 + 1, joint="curve")


def shaded_bar(draw, x0, x1, y_center, half, colors):
    # Barra horizontal con banda de luz arriba y sombra abajo.
    poly(draw, [(x0, y_center - half), (x1, y_center - half), (x1, y_center + half), (x0, y_center + half)], colors[1])
    draw.rectangle([s(x0) + 2, s(y_center - half) + 2, s(x1) - 2, s(y_center - half * 0.25)], fill=colors[-1])
    draw.rectangle([s(x0) + 2, s(y_center + half * 0.35), s(x1) - 2, s(y_center + half) - 2], fill=colors[0])


def wraps(draw, x0, x1, y_center, half, step=6):
    for x in range(int(x0), int(x1), step):
        poly(draw, [(x, y_center - half - 1), (x + step - 2, y_center - half - 1), (x + step - 3, y_center + half + 1), (x - 1, y_center + half + 1)], CLOTH[1], width=1)


def gem(draw, x, y, r):
    poly(draw, [(x, y - r), (x + r * 0.8, y), (x, y + r), (x - r * 0.8, y)], JADE[1])
    poly(draw, [(x, y - r * 0.6), (x + r * 0.35, y - r * 0.1), (x, y + r * 0.1)], JADE[2], outline=JADE[2], width=1)


def crescent(cx, cy, r_out, r_in, offset, start, end, steps=28):
    """Media luna: arco exterior de radio r_out y arco interior desplazado `offset` hacia el centro."""
    outer = [(cx + math.cos(a) * r_out, cy + math.sin(a) * r_out) for a in [start + (end - start) * i / steps for i in range(steps + 1)]]
    inner = [(cx + offset[0] + math.cos(a) * r_in, cy + offset[1] + math.sin(a) * r_in) for a in [end + (start - end) * i / steps for i in range(steps + 1)]]
    return outer + inner


def draw_sword(draw, w, h):
    y = GRIP["sword"][1]
    poly(draw, [(4, y - 6), (12, y - 7), (14, y + 7), (4, y + 6)], BRONZE[1])
    gem(draw, 8, y, 3)
    shaded_bar(draw, 13, 42, y, 4, WOOD)
    wraps(draw, 15, 40, y, 4)
    poly(draw, [(42, y - 17), (49, y - 15), (49, y + 15), (42, y + 17)], BRONZE[1])
    poly(draw, [(49, y - 7), (150, y - 6), (172, y), (150, y + 6), (49, y + 7)], STEEL[1])
    poly(draw, [(52, y - 5), (150, y - 4), (166, y - 0.5), (52, y - 0.5)], STEEL[2], outline=STEEL[2], width=1)
    draw.line([(s(54), s(y)), (s(160), s(y))], fill=STEEL[3], width=3)
    poly(draw, [(52, y + 1.5), (150, y + 2), (166, y + 0.5), (52, y + 5)], STEEL[0], outline=STEEL[0], width=1)


def draw_axe(draw, w, h):
    y = GRIP["axe"][1]
    shaded_bar(draw, 6, 158, y, 4, WOOD)
    wraps(draw, 10, 46, y, 4)
    # Media luna grande hacia abajo (el filo mira adelante al levantar el arma), filo convexo paralelo al mango.
    def blade_outline(radius, inset):
        arc = [(134 + math.cos(a) * radius, y + 8 + math.sin(a) * radius) for a in [math.radians(160 - 140 * i / 24) for i in range(25)]]
        right_horn, left_horn = arc[-1], arc[0]
        neck_r, neck_l = (146 - inset, y + 6), (122 + inset, y + 6)
        curve_r = [(right_horn[0] + (neck_r[0] - right_horn[0]) * t + 6 * math.sin(math.pi * t), right_horn[1] + (neck_r[1] - right_horn[1]) * t) for t in (0.33, 0.66)]
        curve_l = [(neck_l[0] + (left_horn[0] - neck_l[0]) * t - 6 * math.sin(math.pi * t), neck_l[1] + (left_horn[1] - neck_l[1]) * t) for t in (0.33, 0.66)]
        return arc + curve_r + [neck_r, neck_l] + curve_l
    poly(draw, blade_outline(42, 0), STEEL[1])
    poly(draw, blade_outline(33, 7), STEEL[2], outline=STEEL[2], width=1)
    rim = [(134 + math.cos(math.radians(150 - 120 * i / 20)) * 41, y + 8 + math.sin(math.radians(150 - 120 * i / 20)) * 41) for i in range(21)]
    rim += [(134 + math.cos(math.radians(30 + 120 * i / 20)) * 37, y + 8 + math.sin(math.radians(30 + 120 * i / 20)) * 37) for i in range(21)]
    poly(draw, rim, STEEL[3], outline=STEEL[3], width=1)
    # Lomo corto hacia arriba y casquillo de bronce.
    poly(draw, [(126, y - 5), (142, y - 5), (138, y - 22), (130, y - 22)], STEEL[0])
    poly(draw, [(120, y - 8), (146, y - 8), (146, y + 10), (120, y + 10)], BRONZE[1])
    gem(draw, 133, y + 1, 4)
    poly(draw, [(156, y - 5), (166, y - 3), (166, y + 3), (156, y + 5)], BRONZE[0])


def draw_glaive(draw, w, h):
    y = GRIP["glaive"][1]
    shaded_bar(draw, 4, 128, y, 3.5, WOOD)
    wraps(draw, 8, 40, y, 3.5)
    wraps(draw, 96, 112, y, 3.5)
    poly(draw, [(118, y - 7), (132, y - 7), (132, y + 7), (118, y + 7)], BRONZE[1])
    gem(draw, 125, y, 3.5)
    # Hoja curva tipo cuchilla: el filo convexo hacia abajo (adelante al levantar), punta arriba-delante.
    blade = [(132, y - 6), (150, y - 10), (170, y - 14), (190, y - 22), (186, y - 6), (178, y + 8), (162, y + 20), (146, y + 22), (138, y + 14), (132, y + 6)]
    poly(draw, blade, STEEL[1])
    poly(draw, [(136, y - 3), (168, y - 11), (184, y - 18), (176, y - 4), (150, y + 2)], STEEL[2], outline=STEEL[2], width=1)
    draw.line([(s(140), s(y + 18)), (s(162), s(y + 18)), (s(178), s(y + 6)), (s(186), s(y - 8))], fill=STEEL[3], width=5)
    # Gancho trasero pequeño.
    poly(draw, [(134, y - 6), (140, y - 18), (146, y - 16), (142, y - 7)], STEEL[0])


def draw_hammer(draw, w, h):
    y = GRIP["hammer"][1]
    poly(draw, [(0, y), (10, y - 4), (10, y + 4)], STEEL[1])
    shaded_bar(draw, 9, 134, y, 4, WOOD)
    wraps(draw, 12, 48, y, 4)
    poly(draw, [(128, y - 9), (136, y - 9), (136, y + 9), (128, y + 9)], BRONZE[1])
    # Cabeza rectangular grande con bandas de bronce.
    poly(draw, [(136, y - 44), (172, y - 40), (172, y + 40), (136, y + 44)], STEEL[1])
    poly(draw, [(138, y - 41), (150, y - 40), (150, y + 40), (138, y + 41)], STEEL[2], outline=STEEL[2], width=1)
    poly(draw, [(162, y - 38), (170, y - 37), (170, y + 37), (162, y + 38)], STEEL[0], outline=STEEL[0], width=1)
    for band in (-30, 24):
        poly(draw, [(135, y + band), (173, y + band), (173, y + band + 7), (135, y + band + 7)], BRONZE[1])
    gem(draw, 154, y, 6)


DRAWERS = {"sword": draw_sword, "axe": draw_axe, "glaive": draw_glaive, "hammer": draw_hammer}


def base_image(weapon):
    w, h = CANVAS[weapon]
    image = Image.new("RGBA", (s(w), s(h)), (0, 0, 0, 0))
    DRAWERS[weapon](ImageDraw.Draw(image), w, h)
    return image


def to_square(image, size=1024):
    square = Image.new("RGB", (size, size), (255, 255, 255))
    factor = size * 0.9 / max(image.size)
    big = image.resize((round(image.width * factor), round(image.height * factor)), Image.LANCZOS)
    offset = ((size - big.width) // 2, (size - big.height) // 2)
    square.paste(big, offset, big)
    return square, factor, offset


def workflow(weapon, input_name, seed, change):
    return {
        "checkpoint": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": "sd_xl_base_1.0.safetensors"}},
        "vae": {"class_type": "VAELoader", "inputs": {"vae_name": "sdxl_vae_fp16_fix.safetensors"}},
        "lora": {"class_type": "LoraLoader", "inputs": {"model": ["checkpoint", 0], "clip": ["checkpoint", 1],
                                                       "lora_name": "pixel-art-xl.safetensors", "strength_model": 0.9, "strength_clip": 0.9}},
        "source": {"class_type": "LoadImage", "inputs": {"image": input_name}},
        "edges": {"class_type": "Canny", "inputs": {"image": ["source", 0], "low_threshold": 0.15, "high_threshold": 0.4}},
        "controlnet": {"class_type": "ControlNetLoader", "inputs": {"control_net_name": "controlnet-union-sdxl-promax.safetensors"}},
        "controlnet_type": {"class_type": "SetUnionControlNetType", "inputs": {"control_net": ["controlnet", 0], "type": "canny/lineart/anime_lineart/mlsd"}},
        "positive": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["lora", 1], "text": PROMPTS[weapon] + ", " + STYLE}},
        "negative": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["lora", 1], "text": NEGATIVE}},
        "apply_control": {"class_type": "ControlNetApplyAdvanced", "inputs": {
            "positive": ["positive", 0], "negative": ["negative", 0], "control_net": ["controlnet_type", 0],
            "image": ["edges", 0], "strength": 0.85, "start_percent": 0.0, "end_percent": 0.85, "vae": ["vae", 0]}},
        "latent": {"class_type": "VAEEncode", "inputs": {"pixels": ["source", 0], "vae": ["vae", 0]}},
        "sampler": {"class_type": "KSampler", "inputs": {
            "model": ["lora", 0], "seed": seed, "steps": 30, "cfg": 6.5, "sampler_name": "dpmpp_2m", "scheduler": "karras",
            "positive": ["apply_control", 0], "negative": ["apply_control", 1], "latent_image": ["latent", 0], "denoise": change}},
        "decode": {"class_type": "VAEDecode", "inputs": {"samples": ["sampler", 0], "vae": ["vae", 0]}},
        "save": {"class_type": "SaveImage", "inputs": {"images": ["decode", 0], "filename_prefix": "ruby1_weapon"}},
    }


def finalize(generated, weapon, base, factor, offset):
    """Fondo fuera, vuelta al lienzo de 1x, máscara de la silueta original y paleta reducida."""
    w, h = CANVAS[weapon]
    clean = viridy.remove_white(generated, tolerance=24)
    box = (offset[0], offset[1], offset[0] + round(base.width * factor), offset[1] + round(base.height * factor))
    clean = clean.crop(box).resize((w, h), Image.LANCZOS)
    # La silueta del boceto manda: lo que SD añada fuera (o agujeree dentro) se corrige con la máscara.
    mask = base.getchannel("A").resize((w, h), Image.LANCZOS).point(lambda a: 255 if a > 90 else 0)
    mask = mask.filter(ImageFilter.MaxFilter(3)).point(lambda a: 255 if a else 0)
    rgb = clean.convert("RGB")
    fallback = base.resize((w, h), Image.LANCZOS).convert("RGB")
    alpha = clean.getchannel("A")
    rgb.paste(fallback, (0, 0), Image.eval(alpha, lambda a: 255 if a < 60 else 0))
    quantized = rgb.quantize(colors=20, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGBA")
    quantized.putalpha(mask)
    # Contorno oscuro de 1 px alrededor de la silueta.
    outline = mask.filter(ImageFilter.MaxFilter(3))
    result = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    result.paste(Image.new("RGBA", (w, h), OUTLINE + (255,)), (0, 0), outline)
    result.alpha_composite(quantized)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--armas", nargs="+", default=list(DRAWERS))
    parser.add_argument("--semilla", type=int, default=11)
    parser.add_argument("--variantes", type=int, default=1)
    parser.add_argument("--cambio", type=float, default=0.55)
    parser.add_argument("--crudos", default=os.path.expanduser("~/ruby1_referencias/armas"))
    parser.add_argument("--solo-base", action="store_true", help="solo dibuja las siluetas (sin ComfyUI)")
    args = parser.parse_args()
    os.makedirs(args.crudos, exist_ok=True)
    for weapon in args.armas:
        base = base_image(weapon)
        base.save(os.path.join(args.crudos, f"{weapon}_base.png"))
        square, factor, offset = to_square(base)
        square_path = os.path.join(args.crudos, f"{weapon}_entrada.png")
        square.save(square_path)
        if args.solo_base:
            continue
        name = viridy.upload_image(square_path)
        for k in range(args.variantes):
            seed = args.semilla + k
            raw_path = os.path.join(args.crudos, f"{weapon}_s{seed}_crudo.png")
            with open(raw_path, "wb") as file:
                file.write(viridy.run(workflow(weapon, name, seed, args.cambio)))
            sprite = finalize(Image.open(raw_path), weapon, base, factor, offset)
            sprite.save(os.path.join(args.crudos, f"{weapon}_s{seed}.png"))
            if k == 0:
                sprite.save(os.path.join(OUT, f"{weapon}.png"))
            print(f"{weapon} semilla {seed} listo", flush=True)


if __name__ == "__main__":
    main()
