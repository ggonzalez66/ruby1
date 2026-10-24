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
check(len(hum) == rate * 4, 'el campo de fuerza tiene un bucle periódico de cuatro segundos')
energy = sum(x * x for x in hum)
roughness = sum((b - a) ** 2 for a, b in zip(hum, hum[1:])) / energy
check(roughness < 0.0025, 'el hum concentra energía grave y evita el zumbido agudo anterior')
# Comprueba la opción B elegida contra el WAV realmente empaquetado.
def amplitude(frequency):
    signal = hum[::4]
    step = 2 * math.pi * frequency / (rate / 4)
    real = sum(x * math.cos(i * step) for i, x in enumerate(signal))
    imag = sum(x * math.sin(i * step) for i, x in enumerate(signal))
    return math.hypot(real, imag) * 2 / len(signal)


check(amplitude(106.5) > 3 * amplitude(53.25) and amplitude(106.5) > 0.1 and amplitude(852) < 0.01,
      'la opción B mantiene 106,5 Hz como tono dominante sin recuperar el zumbido de 852 Hz')

window = rate // 4
levels = [math.sqrt(sum(x * x for x in hum[i:i + window]) / window) for i in range(0, len(hum), window)]
check(max(levels) / min(levels) < 1.7, 'el nivel permanece estable sin pulsaciones marcadas')
check(abs(hum[-1] - hum[0]) <= max(abs(b - a) for a, b in zip(hum, hum[1:])) * 1.01, 'la unión del loop no introduce salto audible')
rate, roar = samples('roar_parry')
check(0.25 < len(roar) / rate < 0.6 and max(abs(x) for x in roar) < 0.99, 'rugido corto sin clipping para superponer al parry')
for name, duration in [('wrath_charge', 1.0), ('wrath_ready', 0.42), ('wrath_aim', 0.25),
                       ('wrath_launch', 0.65), ('wrath_impact', 0.42), ('wrath_shatter', 0.62)]:
    rate, effect = samples(name)
    rms = math.sqrt(sum(x * x for x in effect) / len(effect))
    check(abs(len(effect) / rate - duration) < 0.001 and 0.02 < rms < 0.65
          and 0.5 < max(abs(x) for x in effect) < 0.9,
          f'{name}: duración de su fase, señal audible y margen sin clipping')
rate, charge = samples('wrath_charge')
check(abs(charge[-1] - charge[0]) < 0.04, 'el bucle de carga de Wrath no introduce un salto al repetirse')
print(f'RESULTADO: {checks - fails}/{checks} OK')
raise SystemExit(bool(fails))
