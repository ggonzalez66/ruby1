#!/usr/bin/env python3
"""Transforma frames de Rengar en Viridy, el disolutor, con ComfyUI (SDXL) corriendo en Windows.

Por cada frame:
  1. lo centra sobre fondo blanco en 1024x1024 y lo sube a ComfyUI,
  2. lo recolorea a la paleta de Viridy y genera con img2img sobre ese frame + ControlNet Union (canny del frame, mantiene la pose) +
     IP-Adapter con una vista de perfil de Viridis.png (le da el aspecto de Viridy) + la LoRA pixel art,
  3. quita el fondo blanco y devuelve el resultado al tamaño y posición originales del frame.

ComfyUI: C:\\ComfyUI\\run_nvidia_gpu.bat (escucha en 0.0.0.0:8188). Desde WSL se llega por la IP de Windows
(la puerta de enlace por defecto), que el script detecta sola.

Uso (desde la raíz del proyecto):
  python3 tools/viridy.py --salida /tmp/viridy frame1.png frame2.png --variantes 3
"""
import argparse
import colorsys
import json
import os
import random
import subprocess
import time
import urllib.parse
import urllib.request
import uuid
from collections import deque

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VIRIDIS_SHEET = os.path.join(ROOT, "assets", "sprites", "player", "Viridis.png")
# Vista de perfil (mirando a la derecha) de la hoja de 8 perspectivas: fila 1, columna 3.
VIRIDIS_SIDE_CELL = (2, 0)
CANVAS = 1024
FILL = 0.8  # el frame ocupa el 80 % del lienzo
OPAQUE = 20

PROMPT = ("pixel art, full body video game sprite of Viridy the dissolver, a muscular anthropomorphic green lion "
          "warrior from an alchemical tale, pale jade green speckled mineral fur, huge spiky flowing green mane "
          "with a clearly defined shape, glowing light blue eyes, green lion tail, dark cloth bandage wraps on "
          "forearms and shins, bronze segmented shoulder armor, torn dark loincloth, side view facing right, "
          "plain white background")
NEGATIVE = ("blurry, 3d render, photo, realistic, text, watermark, signature, multiple characters, duplicate, "
            "scenery, background objects, ground shadow, cropped, out of frame, extra limbs, deformed, purple, "
            "white fur, white mane, red eyes, yellow eyes, green eyes, human skin")


def comfy_server():
    route = subprocess.run(["ip", "route", "show", "default"], capture_output=True, text=True).stdout.split()
    host = route[route.index("via") + 1] if "via" in route else "127.0.0.1"
    return f"http://{host}:8188"


SERVER = comfy_server()


def post_json(path, payload):
    request = urllib.request.Request(SERVER + path, data=json.dumps(payload).encode(), headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(request) as response:
        return json.loads(response.read())


def get_json(path):
    with urllib.request.urlopen(SERVER + path) as response:
        return json.loads(response.read())


def upload_image(path):
    boundary = uuid.uuid4().hex
    with open(path, "rb") as file:
        data = file.read()
    body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"image\"; filename=\"{os.path.basename(path)}\"\r\n"
            f"Content-Type: image/png\r\n\r\n").encode() + data + (
            f"\r\n--{boundary}\r\nContent-Disposition: form-data; name=\"overwrite\"\r\n\r\ntrue\r\n--{boundary}--\r\n").encode()
    request = urllib.request.Request(SERVER + "/upload/image", data=body,
                                     headers={"Content-Type": f"multipart/form-data; boundary={boundary}"})
    with urllib.request.urlopen(request) as response:
        return json.loads(response.read())["name"]


# Paleta de Viridis.png: pelaje jade (de sombra a luz) y vendas/armadura negro carbón.
FUR_STOPS = [(0.30, (52, 92, 68)), (0.50, (83, 135, 91)), (0.65, (110, 160, 104)), (0.80, (148, 188, 111)), (1.00, (190, 232, 138))]
CLOTH_DARK, CLOTH_LIGHT = (6, 8, 8), (58, 70, 64)


def _smooth(edge0, edge1, x):
    t = min(max((x - edge0) / (edge1 - edge0), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def _fur_color(lum):
    for (l0, c0), (l1, c1) in zip(FUR_STOPS, FUR_STOPS[1:]):
        if lum <= l1:
            t = max(0.0, (lum - l0) / (l1 - l0))
            return tuple(a + (b - a) * t for a, b in zip(c0, c1))
    return FUR_STOPS[-1][1]


def pre_recolor(frame):
    """Pasa los colores de Rengar a los de Viridy (pelaje crema -> jade, morado oscuro -> negro carbón),
    para que SD parta de la paleta correcta y solo tenga que cambiar la textura y la forma."""
    out = []
    for r, g, b, a in frame.getdata():
        if a == 0:
            out.append((r, g, b, a))
            continue
        h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
        hue_distance = min(abs(h * 360 - 45), 360 - abs(h * 360 - 45))
        fur = _smooth(0.32, 0.5, l) * (1 - _smooth(45, 75, hue_distance))
        lum = 0.299 * r / 255 + 0.587 * g / 255 + 0.114 * b / 255
        fur_rgb = _fur_color(lum)
        t = min(lum / 0.45, 1.0)
        cloth_rgb = tuple(c0 + (c1 - c0) * t for c0, c1 in zip(CLOTH_DARK, CLOTH_LIGHT))
        out.append(tuple(round(fr * fur + cr * (1 - fur)) for fr, cr in zip(fur_rgb, cloth_rgb)) + (a,))
    recolored = Image.new("RGBA", frame.size)
    recolored.putdata(out)
    return recolored


def visible_box(image):
    return image.getchannel("A").point(lambda a: 255 if a > OPAQUE else 0).getbbox()


def to_canvas(frame):
    """Centra lo visible del frame en un lienzo blanco. Devuelve el lienzo y cómo deshacerlo."""
    box = visible_box(frame)
    sprite = frame.crop(box)
    scale = CANVAS * FILL / max(sprite.size)
    sprite = sprite.resize((round(sprite.width * scale), round(sprite.height * scale)), Image.LANCZOS)
    offset = ((CANVAS - sprite.width) // 2, (CANVAS - sprite.height) // 2)
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (255, 255, 255, 255))
    canvas.alpha_composite(sprite, offset)
    return canvas.convert("RGB"), (box, scale, offset)


def remove_white(image, tolerance=28):
    """Borra el fondo blanco que toca el borde (relleno por inundación desde los bordes)."""
    image = image.convert("RGBA")
    width, height = image.size
    pixels = image.load()

    def is_background(color):
        return min(color[0], color[1], color[2]) >= 255 - tolerance

    seen = bytearray(width * height)
    queue = deque()
    for x in range(width):
        queue.extend([(x, 0), (x, height - 1)])
    for y in range(height):
        queue.extend([(0, y), (width - 1, y)])
    while queue:
        x, y = queue.popleft()
        index = y * width + x
        if seen[index]:
            continue
        seen[index] = 1
        if not is_background(pixels[x, y]):
            continue
        pixels[x, y] = (0, 0, 0, 0)
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < width and 0 <= ny < height and not seen[ny * width + nx]:
                queue.append((nx, ny))
    return image


def paste_back(generated, frame_size, transform):
    box, scale, offset = transform
    clean = remove_white(generated)
    small = clean.resize((round(CANVAS / scale), round(CANVAS / scale)), Image.LANCZOS)
    frame = Image.new("RGBA", frame_size, (0, 0, 0, 0))
    position = (round(box[0] - offset[0] / scale), round(box[1] - offset[1] / scale))
    # Recorta lo que caiga fuera del frame.
    left, top = max(0, -position[0]), max(0, -position[1])
    region = small.crop((left, top, min(small.width, frame_size[0] - position[0]), min(small.height, frame_size[1] - position[1])))
    frame.alpha_composite(region, (position[0] + left, position[1] + top))
    return frame


def viridis_reference(path):
    sheet = Image.open(VIRIDIS_SHEET).convert("RGBA")
    columns, rows = 4, 2
    cell_w, cell_h = sheet.width // columns, sheet.height // rows
    col, row = VIRIDIS_SIDE_CELL
    cell = sheet.crop((col * cell_w, row * cell_h, (col + 1) * cell_w, (row + 1) * cell_h))
    canvas, _ = to_canvas(cell)
    canvas.save(path)


def build_workflow(args, input_name, reference_name, seed):
    return {
        "checkpoint": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": "sd_xl_base_1.0.safetensors"}},
        "vae": {"class_type": "VAELoader", "inputs": {"vae_name": "sdxl_vae_fp16_fix.safetensors"}},
        "lora": {"class_type": "LoraLoader", "inputs": {
            "model": ["checkpoint", 0], "clip": ["checkpoint", 1], "lora_name": "pixel-art-xl.safetensors",
            "strength_model": args.fuerza_lora, "strength_clip": args.fuerza_lora}},
        "ipadapter_loader": {"class_type": "IPAdapterUnifiedLoader", "inputs": {"model": ["lora", 0], "preset": "PLUS (high strength)"}},
        "reference": {"class_type": "LoadImage", "inputs": {"image": reference_name}},
        "ipadapter": {"class_type": "IPAdapterAdvanced", "inputs": {
            "model": ["ipadapter_loader", 0], "ipadapter": ["ipadapter_loader", 1], "image": ["reference", 0],
            "weight": args.fuerza_referencia, "weight_type": "style transfer" if args.solo_estilo else "linear",
            "combine_embeds": "concat", "start_at": 0.0, "end_at": 1.0, "embeds_scaling": "V only"}},
        "source": {"class_type": "LoadImage", "inputs": {"image": input_name}},
        "edges": {"class_type": "Canny", "inputs": {"image": ["source", 0], "low_threshold": 0.15, "high_threshold": 0.4}},
        "controlnet": {"class_type": "ControlNetLoader", "inputs": {"control_net_name": "controlnet-union-sdxl-promax.safetensors"}},
        "controlnet_type": {"class_type": "SetUnionControlNetType", "inputs": {"control_net": ["controlnet", 0], "type": "canny/lineart/anime_lineart/mlsd"}},
        "positive": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["lora", 1], "text": PROMPT}},
        "negative": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["lora", 1], "text": NEGATIVE}},
        "apply_control": {"class_type": "ControlNetApplyAdvanced", "inputs": {
            "positive": ["positive", 0], "negative": ["negative", 0], "control_net": ["controlnet_type", 0],
            "image": ["edges", 0], "strength": args.fuerza_control, "start_percent": 0.0, "end_percent": args.fin_control,
            "vae": ["vae", 0]}},
        "latent": {"class_type": "VAEEncode", "inputs": {"pixels": ["source", 0], "vae": ["vae", 0]}},
        "sampler": {"class_type": "KSampler", "inputs": {
            "model": ["ipadapter", 0], "seed": seed, "steps": args.pasos, "cfg": args.cfg,
            "sampler_name": "dpmpp_2m", "scheduler": "karras",
            "positive": ["apply_control", 0], "negative": ["apply_control", 1], "latent_image": ["latent", 0],
            "denoise": args.cambio}},
        "decode": {"class_type": "VAEDecode", "inputs": {"samples": ["sampler", 0], "vae": ["vae", 0]}},
        "save": {"class_type": "SaveImage", "inputs": {"images": ["decode", 0], "filename_prefix": "viridy"}},
    }


def run(workflow):
    prompt_id = post_json("/prompt", {"prompt": workflow, "client_id": uuid.uuid4().hex})["prompt_id"]
    while True:
        history = get_json(f"/history/{prompt_id}")
        if prompt_id in history:
            break
        time.sleep(1)
    entry = history[prompt_id]
    if entry.get("status", {}).get("status_str") == "error":
        raise RuntimeError(json.dumps(entry["status"].get("messages", []))[:2000])
    image = entry["outputs"]["save"]["images"][0]
    query = urllib.parse.urlencode({"filename": image["filename"], "subfolder": image["subfolder"], "type": image["type"]})
    with urllib.request.urlopen(f"{SERVER}/view?{query}") as response:
        return response.read()


def main():
    parser = argparse.ArgumentParser(description="Transforma frames de Rengar en Viridy con ComfyUI.")
    parser.add_argument("frames", nargs="+", help="PNG de frames sueltos (con transparencia)")
    parser.add_argument("--salida", required=True)
    parser.add_argument("--variantes", type=int, default=2, help="semillas distintas por frame")
    parser.add_argument("--semilla", type=int)
    parser.add_argument("--cambio", type=float, default=0.65, help="cuánto se aleja del frame original (denoise, 0-1)")
    parser.add_argument("--fuerza-referencia", type=float, default=0.8)
    parser.add_argument("--solo-estilo", action="store_true", help="IP-Adapter copia solo el estilo de Viridy")
    parser.add_argument("--fuerza-control", type=float, default=0.7)
    parser.add_argument("--fin-control", type=float, default=0.8)
    parser.add_argument("--fuerza-lora", type=float, default=0.8)
    parser.add_argument("--sin-recolorear", action="store_true", help="no pasar antes el frame a la paleta de Viridy")
    parser.add_argument("--pasos", type=int, default=30)
    parser.add_argument("--cfg", type=float, default=6.0)
    args = parser.parse_args()

    os.makedirs(args.salida, exist_ok=True)
    reference_path = os.path.join(args.salida, "viridis_ref.png")
    viridis_reference(reference_path)
    reference_name = upload_image(reference_path)
    first_seed = args.semilla if args.semilla is not None else random.randrange(1 << 31)
    print(f"ComfyUI: {SERVER}  semillas desde {first_seed}")
    started = time.time()
    for frame_path in args.frames:
        name = os.path.splitext(os.path.basename(frame_path))[0]
        frame = Image.open(frame_path).convert("RGBA")
        canvas, transform = to_canvas(frame if args.sin_recolorear else pre_recolor(frame))
        input_path = os.path.join(args.salida, f"{name}_entrada.png")
        canvas.save(input_path)
        input_name = upload_image(input_path)
        for k in range(args.variantes):
            seed = first_seed + k
            data = run(build_workflow(args, input_name, reference_name, seed))
            raw_path = os.path.join(args.salida, f"{name}_s{seed}_crudo.png")
            with open(raw_path, "wb") as file:
                file.write(data)
            result = paste_back(Image.open(raw_path), frame.size, transform)
            result.save(os.path.join(args.salida, f"{name}_s{seed}.png"))
            print(f"  {name} semilla {seed} ({time.time() - started:.0f} s)")


if __name__ == "__main__":
    main()
