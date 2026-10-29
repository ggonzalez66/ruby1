#!/usr/bin/env python3
"""Genera los efectos de sonido del juego (assets/sounds/sfx/*.wav) sintetizándolos desde cero:
osciladores, ruido filtrado, envolventes y un poco de saturación, al estilo de los juegos retro.
Todo es original y reproducible (semillas fijas): para retocar un sonido se cambia su receta y se vuelve
a lanzar.

Uso (desde la raíz del proyecto):  python3 tools/generate_sfx.py           (todos)
                                   python3 tools/generate_sfx.py hit_light  (solo esos)
"""
import math
import os
import random
import struct
import sys
import wave
from forcefield_hum import build_hum

RATE = 44100
OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "sounds", "sfx")


# ---------- Piezas

def n_samples(duration):
    return int(duration * RATE)


def lerp(a, b, t):
    return a + (b - a) * t


def env(duration, attack=0.004, decay=None, curve=4.0):
    """Envolvente: sube en `attack` y cae exponencialmente durante el resto (o `decay` segundos)."""
    total = n_samples(duration)
    decay = decay if decay is not None else duration - attack
    out = []
    for i in range(total):
        t = i / RATE
        if t < attack:
            out.append(t / attack)
        else:
            out.append(math.exp(-curve * (t - attack) / max(decay, 1e-4)))
    return out


def osc(duration, freq, kind="sine", vibrato=0.0, vibrato_rate=6.0):
    """Oscilador con frecuencia constante o función de t (barridos)."""
    total = n_samples(duration)
    phase = 0.0
    out = []
    for i in range(total):
        t = i / RATE
        f = freq(t) if callable(freq) else freq
        f *= 1.0 + vibrato * math.sin(2 * math.pi * vibrato_rate * t)
        phase = (phase + f / RATE) % 1.0
        if kind == "sine":
            out.append(math.sin(2 * math.pi * phase))
        elif kind == "square":
            out.append(1.0 if phase < 0.5 else -1.0)
        elif kind == "saw":
            out.append(2.0 * phase - 1.0)
        elif kind == "triangle":
            out.append(4.0 * abs(phase - 0.5) - 1.0)
    return out


def noise(duration, seed):
    rng = random.Random(seed)
    return [rng.uniform(-1.0, 1.0) for _ in range(n_samples(duration))]


def crackle(duration, seed, density=0.02):
    """Chasquidos sueltos (fuego, chispas)."""
    rng = random.Random(seed)
    out = []
    level = 0.0
    for _ in range(n_samples(duration)):
        if rng.random() < density:
            level = rng.uniform(0.5, 1.0) * rng.choice((-1, 1))
        out.append(level)
        level *= 0.82
    return out


def lowpass(signal, cutoff):
    """Filtro de un polo; `cutoff` puede ser número o función de t."""
    out = []
    y = 0.0
    for i, x in enumerate(signal):
        c = cutoff(i / RATE) if callable(cutoff) else cutoff
        a = 1.0 - math.exp(-2 * math.pi * c / RATE)
        y += a * (x - y)
        out.append(y)
    return out


def highpass(signal, cutoff):
    low = lowpass(signal, cutoff)
    return [x - l for x, l in zip(signal, low)]


def bandpass(signal, low_cut, high_cut):
    return highpass(lowpass(signal, high_cut), low_cut)


def mul(*signals):
    length = min(len(s) for s in signals)
    out = []
    for i in range(length):
        v = 1.0
        for s in signals:
            v *= s[i]
        out.append(v)
    return out


def gain(signal, g):
    return [x * g for x in signal]


def mix(*signals):
    length = max(len(s) for s in signals)
    out = [0.0] * length
    for s in signals:
        for i, x in enumerate(s):
            out[i] += x
    return out


def delay(signal, seconds):
    return [0.0] * n_samples(seconds) + signal


def drive(signal, amount):
    return [math.tanh(x * amount) / math.tanh(amount) for x in signal]


def tremolo(signal, rate, depth):
    return [x * (1.0 - depth * 0.5 * (1.0 + math.sin(2 * math.pi * rate * i / RATE))) for i, x in enumerate(signal)]


def partials(duration, freqs, decays, seed=0):
    """Campana/metal: parciales inarmónicos con caídas propias."""
    rng = random.Random(seed)
    layers = []
    for f, d in zip(freqs, decays):
        phase = rng.random()
        layers.append(mul(osc(duration, f * (1 + phase * 0.002)), env(duration, 0.001, d)))
    return gain(mix(*layers), 1.0 / len(freqs))


def make_loop(signal, crossfade):
    """Bucle sin costura: el final se funde con el principio (la señal pierde `crossfade` segundos)."""
    fade = n_samples(crossfade)
    body = signal[:-fade]
    tail = signal[-fade:]
    for i in range(fade):
        t = i / fade
        body[i] = body[i] * t + tail[i] * (1.0 - t)
    return body


def pluck(duration, freq, seed, brightness=0.5):
    """Cuerda pulsada (Karplus-Strong)."""
    rng = random.Random(seed)
    period = max(2, int(RATE / freq))
    buffer = [rng.uniform(-1.0, 1.0) for _ in range(period)]
    out = []
    for i in range(n_samples(duration)):
        a = buffer[i % period]
        b = buffer[(i + 1) % period]
        buffer[i % period] = (a * brightness + b * (1.0 - brightness)) * 0.996
        out.append(a)
    return out


def ring(signal, freq):
    return [x * math.sin(2 * math.pi * freq * i / RATE) for i, x in enumerate(signal)]


def sweep(f0, f1, duration, shape=1.0):
    return lambda t: lerp(f0, f1, min(t / duration, 1.0) ** shape)


def finish(signal, peak=0.89, fade_out=True):
    """Normaliza, quita el clic del final (salvo en los bucles) y deja un margen."""
    top = max(1e-6, max(abs(x) for x in signal))
    out = [x / top * peak for x in signal]
    fade = min(n_samples(0.006), len(out)) if fade_out else 0
    for i in range(fade):
        out[-1 - i] *= i / fade
    return out


# ---------- Recetas

def swing_light():
    d = 0.12
    whoosh = mul(bandpass(noise(d, 1), 700, sweep(7000, 1400, d)), env(d, 0.01, 0.07))
    return finish(whoosh)


def swing_heavy():
    d = 0.26
    whoosh = mul(bandpass(noise(d, 2), 300, sweep(3800, 500, d)), env(d, 0.02, 0.18))
    ring = gain(partials(d, [1180, 1735, 2560], [0.12, 0.09, 0.06], 3), 0.35)
    return finish(mix(whoosh, ring))


def hit_light():
    d = 0.14
    thump = mul(osc(d, sweep(190, 80, 0.09)), env(d, 0.002, 0.07))
    crack = mul(lowpass(noise(d, 4), 3200), env(d, 0.001, 0.025))
    return finish(drive(mix(thump, gain(crack, 0.8)), 2.2))


def hit_heavy():
    d = 0.36
    boom = mul(osc(d, sweep(130, 45, 0.22)), env(d, 0.002, 0.2))
    crack = mul(lowpass(noise(d, 5), 2400), env(d, 0.001, 0.05))
    clang = gain(partials(d, [520, 870, 1315, 1990], [0.22, 0.17, 0.12, 0.08], 6), 0.5)
    return finish(drive(mix(boom, gain(crack, 0.9), clang), 2.6))


def heavy_land():
    d = 0.5
    boom = mul(osc(d, sweep(95, 38, 0.3)), env(d, 0.002, 0.3))
    rumble = mul(lowpass(noise(d, 7), 700), env(d, 0.003, 0.22))
    scrape = mul(tremolo(highpass(noise(d, 8), 2200), 32, 0.7), env(d, 0.01, 0.25))
    return finish(drive(mix(boom, gain(rumble, 0.9), gain(scrape, 0.35)), 2.0))


def uppercut():
    d = 0.2
    whoosh = mul(bandpass(noise(d, 9), 500, sweep(900, 7000, d, 0.6)), env(d, 0.02, 0.14, 3.0))
    rise = gain(mul(osc(d, sweep(220, 900, d)), env(d, 0.01, 0.12)), 0.25)
    return finish(mix(whoosh, rise))


def spin():
    d = 0.38
    whirl = mul(tremolo(lowpass(noise(d, 10), 2600), 17, 0.85), env(d, 0.06, 0.32, 2.5))
    fire = mul(highpass(crackle(d, 11, 0.03), 1500), env(d, 0.04, 0.3, 2.5))
    roar = gain(mul(osc(d, sweep(160, 260, d), "saw"), env(d, 0.05, 0.3, 3.0)), 0.18)
    return finish(mix(whirl, gain(fire, 0.5), lowpass(roar, 1200)))


def dash_attack():
    d = 0.16
    whoosh = mul(bandpass(noise(d, 12), 400, sweep(5000, 1100, d)), env(d, 0.008, 0.1))
    zing = gain(mul(osc(d, sweep(1400, 700, d)), env(d, 0.002, 0.06)), 0.2)
    return finish(mix(whoosh, zing))


def dash():
    d = 0.17
    return finish(mul(bandpass(noise(d, 13), 300, sweep(4200, 1200, d)), env(d, 0.012, 0.12)))


def jump():
    d = 0.1
    tone = lowpass(mul(osc(d, sweep(260, 620, d), "square"), env(d, 0.003, 0.07)), 2400)
    puff = mul(lowpass(noise(d, 14), 1200), env(d, 0.001, 0.03))
    return finish(mix(gain(tone, 0.5), puff))


def air_jump():
    d = 0.16
    whoosh = mul(bandpass(noise(d, 15), 600, sweep(1500, 6000, d)), env(d, 0.01, 0.1))
    tone = gain(lowpass(mul(osc(d, sweep(480, 980, d), "square"), env(d, 0.003, 0.08)), 3000), 0.35)
    return finish(mix(whoosh, tone))


def land():
    d = 0.1
    thud = mul(osc(d, sweep(110, 55, 0.06)), env(d, 0.002, 0.05))
    dust = mul(lowpass(noise(d, 16), 700), env(d, 0.002, 0.05))
    return finish(mix(thud, dust))


def step():
    d = 0.05
    tick = mul(lowpass(noise(d, 17), 1400), env(d, 0.001, 0.02))
    knock = gain(mul(osc(d, 150), env(d, 0.001, 0.02)), 0.6)
    return finish(mix(tick, knock), 0.7)


def skid():
    d = 0.24
    return finish(mul(tremolo(bandpass(noise(d, 18), 1200, 4200), 40, 0.6), env(d, 0.01, 0.2, 3.0)), 0.75)


def wall_jump():
    d = 0.16
    thud = mul(osc(d, sweep(160, 70, 0.08)), env(d, 0.002, 0.06))
    whoosh = mul(bandpass(noise(d, 19), 500, sweep(2000, 5000, d)), env(d, 0.02, 0.1))
    return finish(mix(thud, gain(whoosh, 0.8)))


def wallride():
    d = 0.3
    return finish(mul(tremolo(highpass(noise(d, 20), 1400), 24, 0.75), env(d, 0.02, 0.26, 2.5)), 0.7)


def bounce():
    d = 0.2
    boing = mul(osc(d, sweep(190, 560, 0.12), "triangle", 0.04, 22), env(d, 0.002, 0.15))
    thud = mul(lowpass(noise(d, 21), 900), env(d, 0.001, 0.03))
    return finish(mix(boing, thud))


def shine():
    # Chasquido de plasma: el tono sube de golpe (zip), zumbido eléctrico de ruido modulado, un acorde
    # dorado que titila y un golpe grave de cuerpo.
    d = 0.42
    zip_up = mul(osc(d, sweep(500, 3400, 0.045, 0.5), "saw"), env(d, 0.001, 0.09))
    zip_up = lowpass(highpass(zip_up, 400), 7000)
    plasma = mul(ring(bandpass(noise(d, 22), 1800, 6500), 95), env(d, 0.002, 0.22, 3.0))
    gold = tremolo(gain(mix(*[mul(osc(d, f), env(d, 0.004, 0.32, 3.0)) for f in (1047, 1568, 2093, 3136)]), 0.35), 26, 0.55)
    body = mul(osc(d, sweep(220, 95, 0.08)), env(d, 0.001, 0.07))
    return finish(drive(mix(gain(zip_up, 0.55), plasma, gold, gain(body, 0.7)), 1.6))


def shine_hold():
    # Campo de fuerza constante. La opción se elige en tools/forcefield_hum.py.
    return build_hum()


def roar_parry():
    # Capa vocal original sintetizada: grave áspero con formantes de rugido y ataque corto.
    d = 0.46
    throat = osc(d, sweep(135, 72, d), "saw")
    body = lowpass(throat, 1100)
    rasp = bandpass(mix(throat, gain(noise(d, 852), 0.45)), 580, 2200)
    voice = mix(gain(body, 0.7), gain(rasp, 1.4), gain(osc(d, sweep(78, 46, d)), 0.6))
    return finish(mul(drive(tremolo(voice, 33, 0.4), 2.5), env(d, 0.012, 0.4)), 0.85)


def parry():
    d = 0.8
    bell = partials(d, [1567, 2349, 3920, 5230], [0.6, 0.45, 0.3, 0.18], 23)
    click = mul(highpass(noise(d, 24), 3000), env(d, 0.0005, 0.01))
    return finish(mix(bell, gain(click, 0.6)))


def block():
    d = 0.2
    clank = partials(d, [690, 1130, 1660, 2410], [0.12, 0.1, 0.07, 0.05], 25)
    knock = mul(lowpass(noise(d, 26), 2500), env(d, 0.001, 0.03))
    return finish(drive(mix(clank, knock), 1.8))


def shine_break():
    d = 0.55
    rng = random.Random(27)
    shards = [delay(partials(0.25, [rng.uniform(2500, 7000)], [rng.uniform(0.05, 0.15)], i), rng.uniform(0.0, 0.18)) for i in range(9)]
    burst = mul(highpass(noise(d, 28), 1500), env(d, 0.001, 0.12))
    fall = gain(mul(osc(d, sweep(1400, 300, d)), env(d, 0.01, 0.35)), 0.3)
    return finish(mix(*shards, burst, fall))


def hurt():
    d = 0.26
    buzz = lowpass(mul(osc(d, sweep(240, 110, d), "square", 0.05, 30), env(d, 0.002, 0.18)), 1800)
    hit = mul(lowpass(noise(d, 29), 2000), env(d, 0.001, 0.04))
    return finish(drive(mix(buzz, hit), 1.6))


def death():
    d = 0.85
    fall = lowpass(mul(osc(d, sweep(340, 50, d, 0.7), "saw"), env(d, 0.005, 0.7, 2.5)), 1500)
    rumble = mul(lowpass(noise(d, 30), 500), env(d, 0.005, 0.6, 3.0))
    return finish(mix(fall, gain(rumble, 0.6)))


def enemy_die():
    d = 0.42
    boom = mul(osc(d, sweep(160, 40, 0.3)), env(d, 0.002, 0.28))
    burst = mul(lowpass(noise(d, 31), sweep(4000, 600, d)), env(d, 0.002, 0.25))
    return finish(drive(mix(boom, burst), 2.0))


def enemy_swing():
    d = 0.17
    return finish(mul(bandpass(noise(d, 32), 250, sweep(2500, 700, d)), env(d, 0.015, 0.12)), 0.8)


def knife_throw():
    d = 0.18
    whoosh = mul(bandpass(noise(d, 33), 180, sweep(3600, 1100, d)), env(d, 0.006, 0.12))
    flame = gain(mul(lowpass(crackle(d, 34, 0.06), 3200), env(d, 0.005, 0.13)), 0.45)
    return finish(mix(whoosh, flame))


def knife_hit():
    d = 0.17
    burst = mul(lowpass(noise(d, 35), 2800), env(d, 0.001, 0.08))
    flame = gain(mul(crackle(d, 36, 0.07), env(d, 0.001, 0.12)), 0.35)
    return finish(mix(burst, flame))


def knife_catch():
    d = 0.12
    air = mul(bandpass(noise(d, 37), 300, 2100), env(d, 0.012, 0.08))
    tone = gain(mul(osc(d, sweep(420, 740, d)), env(d, 0.005, 0.07)), 0.3)
    return finish(mix(air, tone), 0.7)


def rank_up():
    note = 0.055
    notes = [1047, 1319, 1568, 2093]
    parts = [delay(lowpass(mul(osc(note * 2, f, "square"), env(note * 2, 0.002, note * 1.6)), 4000), i * note) for i, f in enumerate(notes)]
    return finish(gain(mix(*parts), 0.7), 0.75)


def growl():
    # Rugido de pose/taunt en registro medio: sube y cae sin notas graves (antes 105-80 Hz, molestas).
    d = 0.62
    shape = env(d, 0.06, 0.5, 3.5)
    pitch = lambda t: 190.0 + 70.0 * math.sin(math.pi * min(t / d, 1.0)) - 30.0 * t / d
    voice = bandpass(mul(osc(d, pitch, "saw", 0.03, 9), shape), 260, 2400)
    formant = bandpass(mul(osc(d, lambda t: pitch(t) * 2.0, "square"), shape), 700, 1800)
    rasp = mul(bandpass(noise(d, 38), 900, 3200), tremolo(shape, 41, 0.55))
    return finish(highpass(drive(mix(voice, gain(formant, 0.25), gain(rasp, 0.6)), 1.8), 180), 0.8)


def grab():
    d = 0.1
    thud = mul(osc(d, sweep(140, 80, 0.06)), env(d, 0.002, 0.04))
    cloth = mul(bandpass(noise(d, 39), 800, 3000), env(d, 0.005, 0.05))
    return finish(mix(thud, gain(cloth, 0.7)), 0.75)


# ---------- Enemigos

def enemy_alert():
    d = 0.12
    a = mul(osc(0.05, 1250, "square"), env(0.05, 0.001, 0.035))
    b = delay(mul(osc(0.06, 1660, "square"), env(0.06, 0.001, 0.045)), 0.055)
    return finish(lowpass(mix(a, b), 4500), 0.6)


def boss_alert():
    # Destello agudo antes de un ataque avisado: dos notas brillantes que suben (Mi y Si muy agudos, una
    # quinta: consonante) con un brillo de metal encima. Corto y limpio, se oye por encima de la pelea.
    d = 0.32
    first = mul(osc(d, 2637), env(d, 0.002, 0.12, 3.0))
    second = delay(mul(osc(d - 0.06, 3951), env(d - 0.06, 0.002, 0.2, 3.0)), 0.06)
    shimmer = delay(gain(partials(d - 0.06, [5274, 7902], [0.12, 0.08], 41), 0.5), 0.06)
    return finish(mix(gain(first, 0.7), second, shimmer), 0.7)


def enemy_hurt():
    d = 0.12
    grunt = lowpass(mul(osc(d, sweep(210, 130, d), "square"), env(d, 0.002, 0.07)), 1600)
    burst = mul(bandpass(noise(d, 42), 400, 2500), env(d, 0.001, 0.03))
    return finish(mix(grunt, burst), 0.75)


def boss_hurt():
    d = 0.22
    grunt = lowpass(mul(osc(d, sweep(130, 80, d), "saw", 0.03, 25), env(d, 0.003, 0.15)), 1100)
    armor = gain(partials(d, [430, 690, 1020], [0.12, 0.09, 0.06], 43), 0.5)
    return finish(drive(mix(grunt, armor), 1.8))


def enemy_charge():
    d = 0.36
    whine = mul(osc(d, sweep(300, 1100, d, 1.5)), env(d, 0.02, 0.3, 1.0))
    fizz = mul(highpass(noise(d, 44), 4000), [i / n_samples(d) for i in range(n_samples(d))])
    return finish(mix(gain(whine, 0.7), gain(fizz, 0.25)), 0.6)


def enemy_shoot():
    d = 0.13
    pew = lowpass(mul(osc(d, sweep(1500, 380, d, 0.6), "square"), env(d, 0.001, 0.09)), 4000)
    puff = mul(lowpass(noise(d, 45), 2200), env(d, 0.001, 0.025))
    return finish(mix(pew, puff), 0.75)


def projectile_pop():
    d = 0.08
    pop = mul(osc(d, sweep(700, 180, 0.05)), env(d, 0.001, 0.04))
    fizz = mul(highpass(noise(d, 46), 2500), env(d, 0.001, 0.025))
    return finish(mix(pop, gain(fizz, 0.6)), 0.65)


def zap():
    d = 0.22
    arc = mul(ring(highpass(noise(d, 47), 1500), 140), env(d, 0.001, 0.15, 3.0))
    crackles = highpass(crackle(d, 48, 0.08), 2000)
    tone = gain(mul(osc(d, 2400, "square"), env(d, 0.001, 0.05)), 0.2)
    return finish(mix(arc, gain(crackles, 0.6), tone), 0.75)


def boss_swing():
    d = 0.3
    return finish(mul(bandpass(noise(d, 49), 150, sweep(1800, 300, d)), env(d, 0.04, 0.2, 3.0)))


def shockwave():
    d = 0.55
    boom = mul(osc(d, sweep(85, 40, 0.3)), env(d, 0.002, 0.3))
    surge = mul(bandpass(noise(d, 50), 300, sweep(800, 3500, d, 0.7)), env(d, 0.03, 0.45, 2.5))
    energy = gain(mul(osc(d, sweep(220, 440, d), "saw"), env(d, 0.02, 0.4, 3.0)), 0.25)
    return finish(drive(mix(boom, surge, lowpass(energy, 1800)), 1.8))


def boss_charge():
    d = 0.9
    drone = lowpass(mul(osc(d, sweep(70, 160, d, 1.4), "saw"), [min(1.0, i / n_samples(d) * 1.2) for i in range(n_samples(d))]), 1200)
    whine = gain(mul(osc(d, sweep(500, 1600, d, 1.5)), [i / n_samples(d) for i in range(n_samples(d))]), 0.4)
    return finish(tremolo(mix(drone, whine), 9, 0.4), 0.8)


def boss_spin():
    d = 0.6
    whirl = mul(tremolo(lowpass(noise(d, 51), 1400), 11, 0.85), env(d, 0.05, 0.5, 2.0))
    hum = gain(lowpass(mul(osc(d, 90, "saw"), env(d, 0.05, 0.5, 2.0)), 700), 0.5)
    return finish(mix(whirl, hum))


def boss_dash():
    d = 0.22
    return finish(mul(bandpass(noise(d, 52), 200, sweep(3000, 700, d)), env(d, 0.01, 0.16)), 0.85)


def rapier():
    d = 0.11
    swish = mul(bandpass(noise(d, 53), 2000, sweep(9000, 3500, d)), env(d, 0.004, 0.06))
    ting = gain(partials(d, [3800, 5200], [0.04, 0.03], 54), 0.35)
    return finish(mix(swish, ting), 0.8)


def dagger_throw():
    d = 0.4
    whirr = mul(tremolo(bandpass(noise(d, 55), 1500, 6000), 24, 0.8), env(d, 0.01, 0.35, 2.0))
    ring_tone = gain(partials(d, [2900, 4100], [0.2, 0.15], 56), 0.3)
    return finish(mix(whirr, ring_tone), 0.8)


def bow_draw():
    # Cuerda que se tensa: un silbido fino que sube y se aclara, sin el crujido grave de antes.
    d = 0.35
    rise = [min(1.0, i / n_samples(d) * 1.3) for i in range(n_samples(d))]
    string = mul(osc(d, sweep(1700, 2500, d, 0.8), "triangle", 0.01, 30), rise)
    air = mul(bandpass(noise(d, 57), 3000, 8000), rise)
    return finish(mix(gain(string, 0.45), gain(air, 0.3)), 0.45)


def arrow_shot():
    d = 0.3
    twang = mul(pluck(d, 196, 58, 0.45), env(d, 0.001, 0.25, 3.0))
    whoosh = mul(bandpass(noise(d, 59), 1500, sweep(7000, 2500, d)), env(d, 0.01, 0.08))
    return finish(mix(twang, gain(whoosh, 0.6)), 0.85)


def rain_mark():
    d = 0.18
    return finish(partials(d, [2093, 3136], [0.12, 0.08], 60), 0.5)


def arrow_rain():
    d = 0.6
    rng = random.Random(61)
    whistles = [delay(mul(osc(0.25, sweep(rng.uniform(2600, 3600), rng.uniform(1200, 1800), 0.25)), env(0.25, 0.02, 0.2)), rng.uniform(0, 0.35)) for _ in range(6)]
    return finish(gain(mix(*whistles), 0.5), 0.7)


def teleport():
    d = 0.35
    sweep_up = mul(osc(d, sweep(300, 2400, d, 0.7), "triangle", 0.08, 30), env(d, 0.01, 0.3, 3.0))
    sparkle = mul(highpass(noise(d, 62), 6000), env(d, 0.01, 0.2))
    return finish(mix(sweep_up, gain(sparkle, 0.5)), 0.7)


def sun_hit():
    d = 0.6
    gong = partials(d, [196, 293, 415, 587], [0.5, 0.4, 0.3, 0.2], 63)
    hit = mul(lowpass(noise(d, 64), 1200), env(d, 0.001, 0.03))
    return finish(mix(gong, hit), 0.75)


def hawk_screech():
    # El halcón te ha visto: chillido agudo "kiii-iir" que baja un poco al final, con vibrato rápido.
    d = 0.42
    cry = mul(osc(d, sweep(3300, 2500, d, 1.6), "sine", 0.025, 38), env(d, 0.012, 0.36, 2.2))
    edge = gain(mul(osc(d, sweep(6600, 5000, d, 1.6), "triangle"), env(d, 0.01, 0.2, 3.0)), 0.18)
    breath = mul(bandpass(noise(d, 65), 3500, 9000), env(d, 0.005, 0.1))
    return finish(mix(cry, edge, gain(breath, 0.2)), 0.7)


def hawk_dive():
    # Picada: viento que silba bajando de tono.
    d = 0.5
    wind = mul(bandpass(noise(d, 66), 600, sweep(6000, 1800, d)), env(d, 0.06, 0.4, 2.0))
    whistle = gain(mul(osc(d, sweep(2200, 1100, d)), env(d, 0.05, 0.4, 2.5)), 0.25)
    return finish(mix(wind, whistle), 0.75)


def guard_break():
    # Se le rompe la guardia al escudero: golpe metálico grave y el escudo que tiembla.
    d = 0.4
    clank = partials(d, [310, 470, 820, 1290], [0.3, 0.22, 0.14, 0.08], 67)
    thud = mul(lowpass(noise(d, 68), 900), env(d, 0.001, 0.05))
    return finish(drive(mix(tremolo(clank, 16, 0.4), thud), 1.6), 0.85)


def wrath_charge():
    # Energía contenida; bucle grave que desaparece al cancelar o completar la carga.
    d = 1.2
    body = mix(osc(d, 80), gain(osc(d, 160, "triangle"), 0.25))
    fire = gain(lowpass(noise(d, 801), 650), 0.35)
    return finish(make_loop(mix(body, fire), 0.2), 0.65, fade_out=False)


def wrath_ready():
    d = 0.42
    bloom = mix(osc(d, sweep(180, 540, 0.15)), gain(osc(d, 810, "triangle"), 0.3))
    return finish(mul(bloom, env(d, 0.015, 0.38, 3.0)), 0.75)


def wrath_aim():
    # La subida coincide con los 500 ms para elegir dirección.
    d = 0.50
    tension = mul(osc(d, sweep(110, 440, d, 1.5), "triangle"), env(d, 0.38, 0.10, 1.0))
    wind = gain(mul(bandpass(noise(d, 802), 400, 2200), env(d, 0.40, 0.08, 1.0)), 0.7)
    return finish(mix(tension, wind), 0.75)


def fire_breath():
    # Aliento jade: soplido suave y chisporroteo, en bucle y muy bajo.
    d = 1.0
    hiss = bandpass(noise(d, 911), 500, 4200)
    flicker = tremolo([1.0] * n_samples(d), 13, 0.35)
    sparks = lowpass(crackle(d, 912, 0.004), 6000)
    return finish(make_loop(mix(mul(hiss, flicker), gain(sparks, 0.25)), 0.25), 0.5, fade_out=False)


def wrath_rush():
    d = 1.2
    wind = bandpass(noise(d, 807), 90, 2600)
    body = mix(gain(osc(d, 70), 0.45), gain(osc(d, 140, "triangle"), 0.15))
    return finish(make_loop(drive(mix(wind, body), 1.5), 0.2), 0.65, fade_out=False)


def wrath_hit():
    d = 0.16
    thud = mul(osc(d, sweep(190, 65, 0.10)), env(d, 0.001, 0.12))
    tear = mul(bandpass(noise(d, 808), 600, 6000), env(d, 0.001, 0.10))
    return finish(mix(thud, tear), 0.8)


def soul_snap():
    d = 0.13
    crack = mul(highpass(noise(d, 809), 1600), env(d, 0.001, 0.07))
    bolt = mul(osc(d, sweep(1800, 100, 0.08), "triangle"), env(d, 0.001, 0.10))
    return finish(drive(mix(crack, gain(bolt, 0.6)), 1.7), 0.8)


def wrath_launch():
    d = 0.65
    roar = mul(lowpass(osc(d, sweep(140, 55, d), "saw", 0.05, 27), 850), env(d, 0.008, 0.56, 2.8))
    blast = mul(bandpass(noise(d, 803), 100, sweep(6500, 500, d)), env(d, 0.006, 0.50, 3.0))
    bass = mul(osc(d, sweep(95, 38, 0.18)), env(d, 0.002, 0.22))
    return finish(drive(mix(gain(roar, 0.8), blast, bass), 1.8), 0.85)


def wrath_impact():
    d = 0.42
    thud = mul(osc(d, sweep(130, 35, 0.15)), env(d, 0.001, 0.22))
    rock = mul(lowpass(noise(d, 804), 1600), env(d, 0.001, 0.22))
    return finish(drive(mix(thud, rock), 1.5), 0.85)


def wrath_shatter():
    d = 0.62
    crystal = partials(d, [620, 997, 1613, 2591, 4181], [0.4, 0.35, 0.28, 0.20, 0.14], 805)
    shards = mul(highpass(crackle(d, 806, 0.10), 2400), env(d, 0.002, 0.30))
    absorb = delay(mul(osc(0.35, sweep(720, 160, 0.35)), env(0.35, 0.035, 0.28)), 0.15)
    return finish(mix(crystal, gain(shards, 0.65), gain(absorb, 0.5)), 0.82)


def ui_move():
    d = 0.04
    return finish(lowpass(mul(osc(d, 880, "square"), env(d, 0.001, 0.02)), 3500), 0.5)


def ui_select():
    d = 0.12
    a = mul(osc(0.06, 660, "square"), env(0.06, 0.001, 0.04))
    b = delay(mul(osc(0.06, 990, "square"), env(0.06, 0.001, 0.05)), 0.05)
    return finish(lowpass(mix(a, b), 3500), 0.55)


def ready():
    d = 0.22
    return finish(mul(osc(d, 520, "triangle"), env(d, 0.004, 0.18)), 0.65)


def countdown_tick():
    d = 0.1
    return finish(mul(osc(d, 720, "square"), env(d, 0.003, 0.08)), 0.55)


def go():
    d = 0.36
    chord = mix(osc(d, 880, "triangle"), gain(osc(d, 1320, "triangle"), 0.5))
    return finish(mul(chord, env(d, 0.005, 0.28)), 0.75)


SOUNDS = {name: fn for name, fn in globals().items() if callable(fn) and fn.__module__ == __name__
          and name not in {"n_samples", "lerp", "env", "osc", "noise", "crackle", "lowpass", "highpass", "bandpass",
                           "mul", "gain", "mix", "delay", "drive", "tremolo", "partials", "sweep", "finish", "write", "main",
                           "make_loop", "pluck", "ring"}}


def write(name, samples):
    path = os.path.join(OUT_DIR, name + ".wav")
    with wave.open(path, "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples))
    return path


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    names = sys.argv[1:] or sorted(SOUNDS)
    for name in names:
        if name not in SOUNDS:
            sys.exit(f"No existe el sonido {name}. Hay: {', '.join(sorted(SOUNDS))}")
        samples = SOUNDS[name]()
        write(name, samples)
        print(f"{name}: {len(samples) / RATE:.2f} s")


if __name__ == "__main__":
    main()
