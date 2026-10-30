#!/usr/bin/env python3
"""Patadas 4 y 5 del combo ligero de Viridy (3 frames cada una: anticipación, golpe, recuperación).

Cada pose se dibuja como un esqueleto OpenPose de perfil mirando a la derecha; guía a ComfyUI con el
ControlNet union en modo openpose. El pixel art LoRA da el estilo y la identidad de Viridy llega por
IP-Adapter desde sus golpes actuales. Los crudos se guardan en ~/ruby1_referencias/patadas.

Uso:  python3 tools/art/kick_art.py [--semillas 31 32] [--solo kick_one_1]
      python3 tools/art/kick_art.py --elegir 31          (arma las hojas con esa semilla)
      python3 tools/art/kick_art.py --elegir 31 kick_two_1=32   (semilla por frame)
"""
from collections import deque
import argparse
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import viridy  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
VIRIDY_DIR = os.path.join(ROOT, "assets", "sprites", "player", "viridy")
FOLDER = os.path.expanduser("~/ruby1_referencias/patadas")
SIZE = 1024
GROUND = 940
# Celda del juego: 768 × 512, pies en y = 480 y el cuerpo centrado en x = 384 (la pierna sale hacia delante).
CELL = (768, 512)
CELL_FEET = 480
CELL_BODY_X = 384
SCALE = 0.54
TRAPPED_WHITE = 5000

PROMPT = ("pixel art, 16-bit fighting game sprite, full body, side view facing right, a muscular green lion humanoid "
          "warrior with a huge wild light green mane, lion face with fangs, jade green fur, dark brown leather shoulder "
          "pads and arm wraps, torn loincloth, long lion tail, digitigrade lion legs with big paws, {pose}, "
          "dynamic martial arts pose, plain white background")
NEGATIVE = ("weapon, sword, staff, human face, shoes, clothes on legs, text, watermark, signature, blurry, 3d render, "
            "photo, realistic, multiple characters, two heads, duplicate body, second lion, cropped, frame, border, extra limbs, red, blue, purple")

# Poses en coordenadas del lienzo de 1024 (cadera a unos 520, pies en 940). Puntos OpenPose COCO-18.
# El lado "frontal" es la pierna que patea.
def body(head, neck, near_arm, far_arm, hip, kick, support, lean=0.0):
    nose = (head[0] + 30, head[1])
    return {
        0: nose, 1: neck, 14: (head[0] + 14, head[1] - 14), 15: (head[0] + 10, head[1] - 12), 16: (head[0] - 22, head[1] - 6),
        2: (neck[0] - 10, neck[1] + 4), 3: near_arm[0], 4: near_arm[1],
        5: (neck[0] + 10, neck[1] + 4), 6: far_arm[0], 7: far_arm[1],
        8: (hip[0] - 14, hip[1]), 9: support[0], 10: support[1],
        11: (hip[0] + 14, hip[1]), 12: kick[0], 13: kick[1],
    }

POSES = {
    # Patada frontal: rodilla recogida, pierna extendida a la altura del pecho, vuelve a recoger.
    "kick_one_1": ("chambering a front kick, knee raised high to the chest, fists up in guard",
                   body((470, 230), (460, 300), [(430, 380), (470, 330)], [(510, 380), (560, 320)], (470, 540),
                        [(580, 470), (540, 600)], [(450, 740), (440, 930)])),
    "kick_one_2": ("snapping a powerful front kick, kicking leg fully extended straight forward at chest height, leaning back",
                   body((420, 240), (430, 310), [(380, 400), (350, 470)], [(500, 360), (560, 330)], (470, 550),
                        [(640, 470), (820, 440)], [(450, 740), (430, 930)])),
    "kick_one_3": ("retracting a front kick, knee still raised, leaning forward, ready to step",
                   body((500, 240), (480, 310), [(460, 390), (500, 340)], [(530, 380), (580, 330)], (470, 545),
                        [(570, 520), (560, 660)], [(440, 740), (430, 930)])),
    # Remate: patada alta circular a la altura de la cabeza, con recogida y caída.
    "kick_two_1": ("winding up a high roundhouse kick, pivoting on the standing leg, kicking knee raised to the side",
                   body((440, 250), (440, 320), [(390, 400), (410, 470)], [(500, 380), (560, 350)], (450, 560),
                        [(560, 450), (620, 560)], [(440, 750), (450, 930)])),
    "kick_two_2": ("high roundhouse kick at head height, kicking leg fully extended up and forward, torso leaning far back, "
                   "arms thrown back for balance",
                   body((360, 300), (390, 360), [(320, 420), (260, 460)], [(450, 330), (430, 260)], (460, 560),
                        [(600, 390), (770, 250)], [(460, 750), (470, 930)])),
    "kick_two_3": ("landing after a high kick, kicking leg coming down in front, crouched balanced stance, arms in guard",
                   body((470, 280), (460, 350), [(430, 430), (470, 390)], [(510, 420), (560, 370)], (450, 600),
                        [(580, 690), (660, 930)], [(380, 760), (330, 930)])),
}

LIMBS = [(1, 2), (1, 5), (2, 3), (3, 4), (5, 6), (6, 7), (1, 8), (8, 9), (9, 10), (1, 11), (11, 12), (12, 13),
         (1, 0), (0, 14), (14, 16), (0, 15)]
COLORS = [(255, 0, 0), (255, 85, 0), (255, 170, 0), (255, 255, 0), (170, 255, 0), (85, 255, 0), (0, 255, 0), (0, 255, 85),
          (0, 255, 170), (0, 255, 255), (0, 170, 255), (0, 85, 255), (0, 0, 255), (85, 0, 255), (170, 0, 255), (255, 0, 255),
          (255, 0, 170), (255, 0, 85)]


def skeleton(points, path):
    image = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    draw = ImageDraw.Draw(image)
    for index, (a, b) in enumerate(LIMBS):
        if a in points and b in points:
            color = tuple(int(c * 0.6) for c in COLORS[index])
            draw.line([points[a], points[b]], fill=color, width=14)
    for key, point in points.items():
        draw.ellipse([point[0] - 7, point[1] - 7, point[0] + 7, point[1] + 7], fill=COLORS[key])
    image.save(path)
    return path


def style_reference(path):
    # Viridy de pie en su golpe actual, sobre blanco.
    sheet = Image.open(os.path.join(VIRIDY_DIR, "viridy_light3_arcade.png")).convert("RGBA")
    pose = sheet.crop((512, 0, 1024, 512))
    canvas = Image.new("RGBA", pose.size, (255, 255, 255, 255))
    canvas.alpha_composite(pose)
    canvas.convert("RGB").save(path)
    return path


def workflow(pose_name, style_name, description, seed):
    return {
        "checkpoint": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": "sd_xl_base_1.0.safetensors"}},
        "vae": {"class_type": "VAELoader", "inputs": {"vae_name": "sdxl_vae_fp16_fix.safetensors"}},
        "lora": {"class_type": "LoraLoader", "inputs": {"model": ["checkpoint", 0], "clip": ["checkpoint", 1],
                                                       "lora_name": "pixel-art-xl.safetensors", "strength_model": 0.85, "strength_clip": 0.85}},
        "ipadapter_loader": {"class_type": "IPAdapterUnifiedLoader", "inputs": {"model": ["lora", 0], "preset": "PLUS (high strength)"}},
        "style": {"class_type": "LoadImage", "inputs": {"image": style_name}},
        "ipadapter": {"class_type": "IPAdapterAdvanced", "inputs": {
            "model": ["ipadapter_loader", 0], "ipadapter": ["ipadapter_loader", 1], "image": ["style", 0],
            "weight": 0.7, "weight_type": "style transfer", "combine_embeds": "concat", "start_at": 0.0, "end_at": 1.0,
            "embeds_scaling": "V only"}},
        "pose": {"class_type": "LoadImage", "inputs": {"image": pose_name}},
        "controlnet": {"class_type": "ControlNetLoader", "inputs": {"control_net_name": "controlnet-union-sdxl-promax.safetensors"}},
        "controlnet_type": {"class_type": "SetUnionControlNetType", "inputs": {"control_net": ["controlnet", 0], "type": "openpose"}},
        "positive": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["lora", 1], "text": PROMPT.format(pose=description)}},
        "negative": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["lora", 1], "text": NEGATIVE}},
        "apply_control": {"class_type": "ControlNetApplyAdvanced", "inputs": {
            "positive": ["positive", 0], "negative": ["negative", 0], "control_net": ["controlnet_type", 0],
            "image": ["pose", 0], "strength": 0.9, "start_percent": 0.0, "end_percent": 0.8, "vae": ["vae", 0]}},
        "latent": {"class_type": "EmptyLatentImage", "inputs": {"width": SIZE, "height": SIZE, "batch_size": 1}},
        "sampler": {"class_type": "KSampler", "inputs": {
            "model": ["ipadapter", 0], "seed": seed, "steps": 32, "cfg": 6.5, "sampler_name": "dpmpp_2m", "scheduler": "karras",
            "positive": ["apply_control", 0], "negative": ["apply_control", 1], "latent_image": ["latent", 0], "denoise": 1.0}},
        "decode": {"class_type": "VAEDecode", "inputs": {"samples": ["sampler", 0], "vae": ["vae", 0]}},
        "save": {"class_type": "SaveImage", "inputs": {"images": ["decode", 0], "filename_prefix": "ruby1_kick"}},
    }


def remove_floor_shadow(image):
    """Algunas semillas dibujan una sombra marrón clara bajo los pies: fuera (los pies son verdes, las vendas oscuras)."""
    pixels = image.load()
    for y in range(GROUND - 70, SIZE):
        for x in range(SIZE):
            r, g, b, a = pixels[x, y]
            if a and r >= g - 4 and (r + g + b) / 3 > 105:
                pixels[x, y] = (0, 0, 0, 0)


def clean(raw_path):
    image = viridy.remove_white(Image.open(raw_path).convert("RGBA"))
    remove_floor_shadow(image)
    # Fondo blanco encerrado (entre pierna y cuerpo): manchas grandes de blanco sin matiz. Los brillos sueltos
    # del pelaje son pequeños y se quedan.
    pixels = image.load()
    def white(x, y):
        r, g, b, a = pixels[x, y]
        return a and min(r, g, b) > 228 and max(r, g, b) - min(r, g, b) < 14
    seen = bytearray(SIZE * SIZE)
    for start_y in range(SIZE):
        for start_x in range(SIZE):
            if seen[start_y * SIZE + start_x] or not white(start_x, start_y):
                continue
            blob, queue = [], deque([(start_x, start_y)])
            seen[start_y * SIZE + start_x] = 1
            while queue:
                x, y = queue.popleft()
                blob.append((x, y))
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < SIZE and 0 <= ny < SIZE and not seen[ny * SIZE + nx] and white(nx, ny):
                        seen[ny * SIZE + nx] = 1
                        queue.append((nx, ny))
            if len(blob) > TRAPPED_WHITE:
                for x, y in blob:
                    pixels[x, y] = (0, 0, 0, 0)
    return image


def to_cell(image, points, scale):
    """Lleva el frame a la celda: el pie más bajo a la línea de pies y la pierna de apoyo centrada.
    SD no respeta exactamente el suelo del esqueleto, así que se alinea por el dibujo con una escala común."""
    small = image.resize((round(SIZE * scale), round(SIZE * scale)), Image.LANCZOS)
    box = small.getbbox()
    cell = Image.new("RGBA", CELL, (0, 0, 0, 0))
    offset = (round(CELL_BODY_X - points[10][0] * scale), CELL_FEET - box[3])
    cell.alpha_composite(small, dest=(max(offset[0], 0), max(offset[1], 0)), source=(max(-offset[0], 0), max(-offset[1], 0)))
    return cell


def generate(seeds, only):
    os.makedirs(FOLDER, exist_ok=True)
    style_name = viridy.upload_image(style_reference(os.path.join(FOLDER, "estilo_viridy.png")))
    for name, (description, points) in POSES.items():
        if only and name not in only:
            continue
        pose_name = viridy.upload_image(skeleton(points, os.path.join(FOLDER, f"{name}_pose.png")))
        for seed in seeds:
            raw = os.path.join(FOLDER, f"{name}_s{seed}_crudo.png")
            if os.path.exists(raw):
                continue
            with open(raw, "wb") as file:
                file.write(viridy.run(workflow(pose_name, style_name, description, seed)))
            print(f"{name} semilla {seed} listo", flush=True)


def assemble(default_seed, overrides):
    for kick, output in (("kick_one", "viridy_kick1_arcade.png"), ("kick_two", "viridy_kick2_arcade.png")):
        sheet = Image.new("RGBA", (CELL[0] * 3, CELL[1]), (0, 0, 0, 0))
        frames = []
        for index in range(3):
            name = f"{kick}_{index + 1}"
            seed = overrides.get(name, default_seed)
            frames.append((clean(os.path.join(FOLDER, f"{name}_s{seed}_crudo.png")), POSES[name][1]))
        # Escala común de la patada: el frame más alto cabe con margen sobre la línea de pies.
        tallest = max(image.getbbox()[3] - image.getbbox()[1] for image, _ in frames)
        scale = min(SCALE, (CELL_FEET - 16) / tallest)
        for index, (image, points) in enumerate(frames):
            sheet.alpha_composite(to_cell(image, points, scale), dest=(CELL[0] * index, 0))
        sheet.save(os.path.join(VIRIDY_DIR, output))
        print("hoja", output)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--semillas", type=int, nargs="+", default=[31, 32])
    parser.add_argument("--solo", nargs="*", default=[])
    parser.add_argument("--elegir", nargs="+", help="semilla por defecto y, opcionalmente, frame=semilla")
    args = parser.parse_args()
    if args.elegir:
        overrides = dict((item.split("=")[0], int(item.split("=")[1])) for item in args.elegir[1:])
        assemble(int(args.elegir[0]), overrides)
    else:
        generate(args.semillas, args.solo)


if __name__ == "__main__":
    main()
