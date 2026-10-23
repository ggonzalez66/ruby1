#!/usr/bin/env python3
"""Genera tres muestras comparables del hum y una página de escucha local."""
from pathlib import Path
import struct
import wave
from forcefield_hum import RATE, build_hum

OUT = Path(__file__).resolve().parents[1] / 'docs/audio_previews'
OUT.mkdir(parents=True, exist_ok=True)
(OUT / '.gdignore').write_text('')
names = {'A': 'a_subgrave_53_25', 'B': 'b_grave_106_5', 'C': 'c_campo_sin_nota'}
labels = {'A': 'A · Subgrave constante · 53,25 Hz', 'B': 'B · Grave cálido · 106,5 Hz', 'C': 'C · Campo de fuerza · sin nota definida'}
for option, name in names.items():
    with wave.open(str(OUT / (name + '.wav')), 'wb') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(b''.join(struct.pack('<h', round(x * 32767)) for x in build_hum(option)))
    print(name + '.wav')
html = '''<!doctype html><html lang="es"><meta charset="utf-8"><title>Ruby1 · Hum del campo de fuerza</title>
<style>body{background:#10241d;color:#e0f1dc;font:17px system-ui;max-width:680px;margin:50px auto;padding:24px}article{padding:18px 0;border-top:1px solid #53715d}audio{width:100%}p{color:#a8c6b4}</style>
<h1>Hum del campo de fuerza</h1><p>Las tres opciones mantienen volumen y tono estables, sin pulsación añadida. A y B son transposiciones artísticas de 852 Hz; C es una textura grave sin afinación definida. Usa auriculares para comparar los graves.</p>'''
for option, name in names.items():
    html += f'<article><h2>{labels[option]}</h2><audio controls loop src="{name}.wav"></audio></article>'
(OUT / 'index.html').write_text(html + '</html>')
