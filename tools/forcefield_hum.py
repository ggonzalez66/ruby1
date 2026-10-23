"""Drones constantes de campo de fuerza. A/B derivan artísticamente de 852 Hz; C no tiene nota definida."""
import math
import random

RATE = 44100
DURATION = 4
SELECTED = 'B'


def build_hum(option=SELECTED):
    if option == 'A':
        partials = [(53.25, 1.0, 0), (106.5, 0.32, 0), (159.75, 0.09, 0), (213.0, 0.025, 0)]
    elif option == 'B':
        partials = [(106.5, 1.0, 0), (53.25, 0.25, 0), (213.0, 0.18, 0), (319.5, 0.035, 0)]
    elif option == 'C':
        rng = random.Random(5325)
        # Banco denso de parciales sin serie armónica; todas las frecuencias cierran en 4 s.
        bins = rng.sample(range(140, 881), 72)
        partials = [(frequency / 4, 1 / (1 + (frequency / 400) ** 4), rng.random() * math.tau) for frequency in bins]
    else:
        raise ValueError('Hum esperado: A, B o C')
    count = RATE * DURATION
    out = [0.0] * count
    for frequency, amplitude, phase in partials:
        step = math.tau * frequency / RATE
        for i in range(count):
            out[i] += amplitude * math.sin(step * i + phase)
    rms = math.sqrt(sum(x * x for x in out) / count)
    gain = min(0.19 / rms, 0.82 / max(abs(x) for x in out))
    return [x * gain for x in out]
