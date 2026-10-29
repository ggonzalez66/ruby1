#!/usr/bin/env python3
"""Cabeza de la Liquid Beast (león espiritual, fauces abiertas y cerradas) desde el boceto del usuario.

El lineart del boceto guía a ComfyUI (ControlNet lineart), el pixel art LoRA da el estilo y la paleta jade de
la bestia actual llega por IP-Adapter en modo estilo. Los crudos se guardan en ~/ruby1_referencias/bestia.

Uso:  python3 tools/art/beast_head_art.py [--variantes 3] [--semilla 21] [--boceto PNG]
      python3 tools/art/beast_head_art.py --cerrar abierta_s21_crudo.png   (fauces cerradas de esa cabeza)
"""
from collections import deque
import argparse
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import viridy  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
STYLE_SOURCE = os.path.join(ROOT, "assets", "sprites", "player", "viridy", "viridy_liquid_beast_arcade.png")
WIDTH, HEIGHT = 1216, 832

BASE = ("pixel art, 16-bit video game sprite, the head of a ferocious spectral lion beast, side view facing right, "
        "glowing pale green eyes, heavy brow, short wild mane made of jade green spirit fire flames streaming backwards, "
        "dark emerald and jade colors with bright light green highlights, menacing demonic beast like the beast of "
        "darkness from berserk, compact head only, isolated, plain white background")
POSES = {
    "abierta": "wide open roaring jaws with long sharp ivory fangs",
    "cerrada": "jaws closed, snarling, bared clenched ivory fangs",
}
NEGATIVE = ("body, neck, legs, torso, full body, human, text, watermark, signature, blurry, 3d render, photo, realistic, "
            "red, purple, blue, slime, goo, dripping liquid, long tentacles, multiple heads, cropped, frame, border")


def prepare(sketch, folder):
    lines = Image.open(sketch).convert("L")
    canvas = Image.new("L", (WIDTH, HEIGHT), 255)
    factor = min(WIDTH * 0.86 / lines.width, HEIGHT * 0.86 / lines.height)
    big = lines.resize((round(lines.width * factor), round(lines.height * factor)), Image.LANCZOS)
    canvas.paste(big, ((WIDTH - big.width) // 2, (HEIGHT - big.height) // 2))
    control = os.path.join(folder, "boceto_control.png")
    canvas.convert("RGB").save(control)
    style = Image.open(STYLE_SOURCE).convert("RGBA").crop((0, 0, 768, 512))
    style_canvas = Image.new("RGBA", style.size, (255, 255, 255, 255))
    style_canvas.alpha_composite(style)
    style_path = os.path.join(folder, "estilo_bestia.png")
    style_canvas.convert("RGB").save(style_path)
    return viridy.upload_image(control), viridy.upload_image(style_path)


def workflow(control_name, style_name, pose, seed, control_strength):
    return {
        "checkpoint": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": "sd_xl_base_1.0.safetensors"}},
        "vae": {"class_type": "VAELoader", "inputs": {"vae_name": "sdxl_vae_fp16_fix.safetensors"}},
        "lora": {"class_type": "LoraLoader", "inputs": {"model": ["checkpoint", 0], "clip": ["checkpoint", 1],
                                                       "lora_name": "pixel-art-xl.safetensors", "strength_model": 0.85, "strength_clip": 0.85}},
        "ipadapter_loader": {"class_type": "IPAdapterUnifiedLoader", "inputs": {"model": ["lora", 0], "preset": "PLUS (high strength)"}},
        "style": {"class_type": "LoadImage", "inputs": {"image": style_name}},
        "ipadapter": {"class_type": "IPAdapterAdvanced", "inputs": {
            "model": ["ipadapter_loader", 0], "ipadapter": ["ipadapter_loader", 1], "image": ["style", 0],
            "weight": 0.55, "weight_type": "style transfer", "combine_embeds": "concat", "start_at": 0.0, "end_at": 1.0,
            "embeds_scaling": "V only"}},
        "control_image": {"class_type": "LoadImage", "inputs": {"image": control_name}},
        "invert": {"class_type": "ImageInvert", "inputs": {"image": ["control_image", 0]}},
        "controlnet": {"class_type": "ControlNetLoader", "inputs": {"control_net_name": "controlnet-union-sdxl-promax.safetensors"}},
        "controlnet_type": {"class_type": "SetUnionControlNetType", "inputs": {"control_net": ["controlnet", 0], "type": "canny/lineart/anime_lineart/mlsd"}},
        "positive": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["lora", 1], "text": BASE + ", " + POSES[pose]}},
        "negative": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["lora", 1], "text": NEGATIVE}},
        "apply_control": {"class_type": "ControlNetApplyAdvanced", "inputs": {
            "positive": ["positive", 0], "negative": ["negative", 0], "control_net": ["controlnet_type", 0],
            "image": ["invert", 0], "strength": control_strength, "start_percent": 0.0, "end_percent": 0.7, "vae": ["vae", 0]}},
        "latent": {"class_type": "EmptyLatentImage", "inputs": {"width": WIDTH, "height": HEIGHT, "batch_size": 1}},
        "sampler": {"class_type": "KSampler", "inputs": {
            "model": ["ipadapter", 0], "seed": seed, "steps": 32, "cfg": 6.5, "sampler_name": "dpmpp_2m", "scheduler": "karras",
            "positive": ["apply_control", 0], "negative": ["apply_control", 1], "latent_image": ["latent", 0], "denoise": 1.0}},
        "decode": {"class_type": "VAEDecode", "inputs": {"samples": ["sampler", 0], "vae": ["vae", 0]}},
        "save": {"class_type": "SaveImage", "inputs": {"images": ["decode", 0], "filename_prefix": "ruby1_beast"}},
    }


# Boca de la cabeza elegida (crudo de 1216 x 832): se repinta cerrada con el resto intacto.
MOUTH = [(590, 430), (1095, 395), (1100, 705), (590, 705)]


def close_workflow(source_name, mask_name, style_name, seed):
    flow = workflow(source_name, style_name, "cerrada", seed, 0.0)
    for key in ("control_image", "invert", "controlnet", "controlnet_type", "apply_control"):
        flow.pop(key)
    flow["source"] = {"class_type": "LoadImage", "inputs": {"image": source_name}}
    flow["mask_image"] = {"class_type": "LoadImage", "inputs": {"image": mask_name}}
    flow["mask"] = {"class_type": "ImageToMask", "inputs": {"image": ["mask_image", 0], "channel": "red"}}
    flow["encode"] = {"class_type": "VAEEncode", "inputs": {"pixels": ["source", 0], "vae": ["vae", 0]}}
    flow["latent"] = {"class_type": "SetLatentNoiseMask", "inputs": {"samples": ["encode", 0], "mask": ["mask", 0]}}
    flow["sampler"]["inputs"].update({"positive": ["positive", 0], "negative": ["negative", 0], "denoise": 0.82})
    return flow


def remove_flat_background(image, tolerance=34):
    """Quita el fondo liso (el color del borde) por inundación desde los bordes."""
    image = image.convert("RGBA")
    width, height = image.size
    pixels = image.load()
    reference = pixels[2, 2]
    seen = bytearray(width * height)
    queue = deque([(x, y) for x in range(width) for y in (0, height - 1)] + [(x, y) for y in range(height) for x in (0, width - 1)])
    while queue:
        x, y = queue.popleft()
        index = y * width + x
        if seen[index]:
            continue
        seen[index] = 1
        color = pixels[x, y]
        if max(abs(color[i] - reference[i]) for i in range(3)) > tolerance:
            continue
        pixels[x, y] = (0, 0, 0, 0)
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < width and 0 <= ny < height and not seen[ny * width + nx]:
                queue.append((nx, ny))
    return image


def close_jaws(source, folder, seeds):
    _, style_name = prepare(os.path.expanduser("~/ruby1_referencias/bocetos/beast_head_lineart.png"), folder)
    mask = Image.new("L", Image.open(source).size, 0)
    ImageDraw.Draw(mask).polygon(MOUTH, fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(14)).convert("RGB")
    mask_path = os.path.join(folder, "mascara_boca.png")
    mask.save(mask_path)
    source_name, mask_name = viridy.upload_image(source), viridy.upload_image(mask_path)
    for seed in seeds:
        raw = os.path.join(folder, f"cerrada_s{seed}_crudo.png")
        with open(raw, "wb") as file:
            file.write(viridy.run(close_workflow(source_name, mask_name, style_name, seed)))
        print(f"cerrada semilla {seed} listo", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--boceto", default=os.path.expanduser("~/ruby1_referencias/bocetos/beast_head_lineart.png"))
    parser.add_argument("--salida", default=os.path.expanduser("~/ruby1_referencias/bestia"))
    parser.add_argument("--variantes", type=int, default=3)
    parser.add_argument("--semilla", type=int, default=21)
    parser.add_argument("--cerrar", help="crudo de una cabeza abierta: genera sus fauces cerradas")
    args = parser.parse_args()
    os.makedirs(args.salida, exist_ok=True)
    if args.cerrar:
        source = args.cerrar if os.path.isabs(args.cerrar) else os.path.join(args.salida, args.cerrar)
        close_jaws(source, args.salida, [args.semilla + k for k in range(args.variantes)])
        return
    control_name, style_name = prepare(args.boceto, args.salida)
    for pose, strength in (("abierta", 0.75), ("cerrada", 0.45)):
        for k in range(args.variantes):
            seed = args.semilla + k
            data = viridy.run(workflow(control_name, style_name, pose, seed, strength))
            raw = os.path.join(args.salida, f"{pose}_s{seed}_crudo.png")
            with open(raw, "wb") as file:
                file.write(data)
            viridy.remove_white(Image.open(raw), tolerance=26).save(os.path.join(args.salida, f"{pose}_s{seed}.png"))
            print(f"{pose} semilla {seed} listo", flush=True)


if __name__ == "__main__":
    main()
