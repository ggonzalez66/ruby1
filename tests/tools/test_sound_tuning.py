"""Comprueba los WAV finales, no las constantes de la receta de síntesis."""
import math
from pathlib import Path
import struct
import wave

checks = 0
fails = 0


def check(ok, label):
    global checks, fails
    checks += 1
    fails += not ok
    print(('OK ' if ok else 'FAIL ') + label)


def samples(name):
    with wave.open(str(Path(__file__).resolve().parents[2] / 'assets/sounds/sfx' / (name + '.wav'))) as wav:
        rate = wav.getframerate()
        assert wav.getsampwidth() == 2 and wav.getnchannels() == 1
        data = struct.unpack('<' + 'h' * wav.getnframes(), wav.readframes(wav.getnframes()))
        return rate, [x / 32768 for x in data]


rate, hum = samples('shine_hold')
check(len(hum) == rate, 'Metatrón tiene un bucle periódico de un segundo')


def amplitude(frequency):
    re = sum(x * math.cos(2 * math.pi * frequency * i / rate) for i, x in enumerate(hum))
    im = sum(x * math.sin(2 * math.pi * frequency * i / rate) for i, x in enumerate(hum))
    return math.hypot(re, im) * 2 / len(hum)


check(amplitude(852) > 0.2 and amplitude(852) > amplitude(426) > amplitude(213), '852 Hz domina con subarmónicos audibles de 426 y 213 Hz')
check(amplitude(852) > 20 * max(amplitude(840), amplitude(864)), 'el pico tonal está afinado a 852 Hz')
check(abs(hum[-1] - hum[0]) <= max(abs(b - a) for a, b in zip(hum, hum[1:])) * 1.01, 'la unión del loop no introduce salto audible')
rate, roar = samples('roar_parry')
check(0.25 < len(roar) / rate < 0.6 and max(abs(x) for x in roar) < 0.99, 'rugido corto sin clipping para superponer al parry')
print(f'RESULTADO: {checks - fails}/{checks} OK')
raise SystemExit(bool(fails))
