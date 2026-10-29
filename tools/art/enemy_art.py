#!/usr/bin/env python3
"""Sprites de cuerpo para los enemigos pequeños (autómatas de la jungla) con ComfyUI.

txt2img + LoRA de pixel art sobre fondo blanco; cada variante se guarda limpia en ~/ruby1_referencias/enemigos.
Con --elegir <enemigo>=<semilla> se recorta, se escala a SCALE veces la altura del cuerpo en el juego y se
escribe assets/sprites/enemies/<enemigo>.png (el juego lo dibuja a 1/SCALE).

Uso:  python3 tools/art/enemy_art.py [--enemigos chaser hawk] [--variantes 3] [--semilla 41]
      python3 tools/art/enemy_art.py --elegir chaser=41 shield_bearer=42 hawk=43
"""
import argparse
import os
import sys
from collections import deque

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import viridy  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "sprites", "enemies")
RAW = os.path.expanduser("~/ruby1_referencias/enemigos")
SCALE = 3
# Caja del cuerpo en el juego (px, ancho x alto) por enemigo: el sprite cabe en ella apoyado abajo.
BODY_BOX = {"chaser": (36, 54), "shield_bearer": (56, 74), "hawk": (60, 52)}

PROMPTS = {
    "chaser": "a lean jungle automaton soldier made of carved mossy grey stone and bronze plates, one glowing red eye slit, "
              "small head, short stubby arms, sturdy legs, standing upright",
    "shield_bearer": "a bulky armored jungle automaton guard made of dark bronze plates and mossy stone, heavy rounded "
                     "helmet with a glowing red visor slit, broad shoulders, short thick legs, standing upright",
    "hawk": "a mechanical bird of prey automaton made of bronze plates and green jade stone, glowing red eye, sharp "
            "hooked beak, wings folded tight against the body, tail feathers of bronze, gliding",
}
STYLE = ("pixel art, 16-bit video game enemy sprite, single character, side view facing right, full body, centered, "
         "clean dark outline, plain white background")
NEGATIVE = ("blurry, 3d render, photo, realistic, text, watermark, signature, multiple characters, human, weapon, "
            "sword, shield, scenery, background, ground shadow, cropped, frame, border, purple")


def workflow(enemy, seed):
    return {
        "checkpoint": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": "sd_xl_base_1.0.safetensors"}},
        "vae": {"class_type": "VAELoader", "inputs": {"vae_name": "sdxl_vae_fp16_fix.safetensors"}},
        "lora": {"class_type": "LoraLoader", "inputs": {"model": ["checkpoint", 0], "clip": ["checkpoint", 1],
                                                       "lora_name": "pixel-art-xl.safetensors", "strength_model": 0.9, "strength_clip": 0.9}},
        "positive": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["lora", 1], "text": PROMPTS[enemy] + ", " + STYLE}},
        "negative": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["lora", 1], "text": NEGATIVE}},
        "latent": {"class_type": "EmptyLatentImage", "inputs": {"width": 1024, "height": 1024, "batch_size": 1}},
        "sampler": {"class_type": "KSampler", "inputs": {
            "model": ["lora", 0], "seed": seed, "steps": 30, "cfg": 7.0, "sampler_name": "dpmpp_2m", "scheduler": "karras",
            "positive": ["positive", 0], "negative": ["negative", 0], "latent_image": ["latent", 0], "denoise": 1.0}},
        "decode": {"class_type": "VAEDecode", "inputs": {"samples": ["sampler", 0], "vae": ["vae", 0]}},
        "save": {"class_type": "SaveImage", "inputs": {"images": ["decode", 0], "filename_prefix": "ruby1_enemy"}},
    }


def clear_pale(image):
    """Quita huecos blancos encerrados y la sombra del suelo: crece desde lo transparente hacia píxeles claros y
    poco saturados (el borde blanco ya lo quitó remove_white)."""
    width, height = image.size
    pixels = image.load()

    def pale(color):
        top, low = max(color[:3]), min(color[:3])
        return color[3] > 0 and low >= 170 and top - low <= 28

    queue = deque((x, y) for y in range(height) for x in range(width) if pixels[x, y][3] == 0)
    while queue:
        x, y = queue.popleft()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < width and 0 <= ny < height and pale(pixels[nx, ny]):
                pixels[nx, ny] = (0, 0, 0, 0)
                queue.append((nx, ny))
    # Blanco puro aislado (huecos sin contacto con el exterior).
    for y in range(height):
        for x in range(width):
            if pixels[x, y][3] and min(pixels[x, y][:3]) >= 238:
                pixels[x, y] = (0, 0, 0, 0)
    return image


def pick(enemy, seed):
    clean = clear_pale(Image.open(os.path.join(RAW, f"{enemy}_s{seed}.png")).convert("RGBA"))
    alpha = clean.getchannel("A").point(lambda a: 255 if a > 120 else 0)
    clean.putalpha(alpha)
    sprite = clean.crop(alpha.getbbox())
    # Sombra gris del suelo: solo en la franja inferior, para no comerse la piedra gris del cuerpo.
    pixels = sprite.load()
    for y in range(int(sprite.height * 0.93), sprite.height):
        for x in range(sprite.width):
            color = pixels[x, y]
            if color[3] and min(color[:3]) >= 110 and max(color[:3]) - min(color[:3]) <= 22:
                pixels[x, y] = (0, 0, 0, 0)
    sprite = sprite.crop(sprite.getchannel("A").getbbox())
    box_w, box_h = (v * SCALE for v in BODY_BOX[enemy])
    factor = min(box_w / sprite.width, box_h / sprite.height)
    sprite = sprite.resize((round(sprite.width * factor), round(sprite.height * factor)), Image.LANCZOS)
    sprite.putalpha(sprite.getchannel("A").point(lambda a: 255 if a > 110 else 0))
    os.makedirs(OUT, exist_ok=True)
    sprite.save(os.path.join(OUT, f"{enemy}.png"))
    print(f"{enemy}: {sprite.size}")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--enemigos", nargs="+", default=list(PROMPTS))
    parser.add_argument("--variantes", type=int, default=3)
    parser.add_argument("--semilla", type=int, default=41)
    parser.add_argument("--elegir", nargs="+", help="enemigo=semilla para escribir el sprite final")
    args = parser.parse_args()
    os.makedirs(RAW, exist_ok=True)
    if args.elegir:
        for choice in args.elegir:
            enemy, seed = choice.split("=")
            pick(enemy, int(seed))
        return
    for enemy in args.enemigos:
        for k in range(args.variantes):
            seed = args.semilla + k
            raw = os.path.join(RAW, f"{enemy}_s{seed}_crudo.png")
            with open(raw, "wb") as file:
                file.write(viridy.run(workflow(enemy, seed)))
            viridy.remove_white(Image.open(raw), tolerance=26).save(os.path.join(RAW, f"{enemy}_s{seed}.png"))
            print(f"{enemy} semilla {seed} listo", flush=True)


if __name__ == "__main__":
    main()
