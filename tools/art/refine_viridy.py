#!/usr/bin/env python3
"""Acabado SDXL conservador de hojas OpenAI; nunca sobrescribe el arte de entrada.

Uso: python3 tools/art/refine_viridy.py manifest.json /ruta/de/trabajo
Conserva alfa y mezcla solo 18% del RGB refinado para mantener los clusters originales.
Guarda el grafo y la salida SDXL íntegra junto al resultado para poder comparar.
"""
import argparse
import io
import json
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import viridy


def workflow(image_name, seed, kind="character"):
    positive = "arcade pixel art sprite animation sheet, consistent jade green lion warrior, pale celadon highlights, bronze armor, charcoal wraps, crisp dark outlines, preserve exact poses and silhouettes, plain white background"
    negative = "extra limbs, altered pose, text, scenery, blur, blue fur, purple, neon, watermark"
    if kind == "effect":
        positive = "arcade pixel art claw slash visual effects, thin sharp silver white light blades, pale icy blue highlights, restrained gray tails, preserve exact line shapes and spacing, plain white background"
        negative = "character, face, body, hands, scenery, text, watermark, thick blobs, smoke, neon magenta, noise"
    return {
        "checkpoint": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": "sd_xl_base_1.0.safetensors"}},
        "vae": {"class_type": "VAELoader", "inputs": {"vae_name": "sdxl_vae_fp16_fix.safetensors"}},
        "source": {"class_type": "LoadImage", "inputs": {"image": image_name}},
        "positive": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["checkpoint", 1], "text": positive}},
        "negative": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["checkpoint", 1], "text": negative}},
        "latent": {"class_type": "VAEEncode", "inputs": {"pixels": ["source", 0], "vae": ["vae", 0]}},
        "sampler": {"class_type": "KSampler", "inputs": {"model": ["checkpoint", 0], "seed": seed, "steps": 12, "cfg": 3.0, "sampler_name": "dpmpp_2m", "scheduler": "karras", "positive": ["positive", 0], "negative": ["negative", 0], "latent_image": ["latent", 0], "denoise": 0.12}},
        "decode": {"class_type": "VAEDecode", "inputs": {"samples": ["sampler", 0], "vae": ["vae", 0]}},
        "save": {"class_type": "SaveImage", "inputs": {"images": ["decode", 0], "filename_prefix": "ruby1_refresh"}},
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    entries = json.loads(args.manifest.read_text())
    for index, entry in enumerate(entries):
        name = entry["name"]
        destination = args.output / (name + ".png")
        if destination.exists():
            print("EXISTE", name, flush=True)
            continue
        source = Image.open(entry["source"]).convert("RGBA")
        # El generador puede incluir un halo con alfa muy bajo: solo se limpia ese ruido.
        alpha = source.getchannel("A").point(lambda a: a if a >= 160 else 0)
        source.putalpha(alpha)
        rgb = Image.new("RGBA", source.size, "white")
        rgb.alpha_composite(source)
        ratio = min(1.0, 1024 / max(source.size))
        size = tuple(max(64, round(side * ratio / 64) * 64) for side in source.size)
        prepared = args.output / (name + "_input.png")
        rgb.convert("RGB").resize(size, Image.Resampling.NEAREST).save(prepared)
        graph = workflow(viridy.upload_image(str(prepared)), 801 + index, entry.get("kind", "character"))
        (args.output / (name + "_workflow.json")).write_text(json.dumps(graph, indent=2))
        print("SDXL", name, size, flush=True)
        data = viridy.run(graph)
        (args.output / (name + "_sdxl.png")).write_bytes(data)
        refined = Image.open(io.BytesIO(data)).convert("RGB").resize(source.size, Image.Resampling.NEAREST)
        finished = Image.blend(source.convert("RGB"), refined, 0.18).convert("RGBA")
        finished.putalpha(alpha)
        finished.save(destination)
        print("LISTO", name, flush=True)


if __name__ == "__main__":
    main()
