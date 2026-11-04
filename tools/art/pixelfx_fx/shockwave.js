// Ruby1: onda expansiva del aterrizaje del picado (recrea las ondas de polígonos originales del juego).
import { Particles, Lights, P, Rng, fit, band, ease, seg, clamp, mix, WHITE, TAU } from "../../core/index.js";

export const meta = {
  name: "Ruby1 shockwave",
  desc: "A dive lands: a white flash flat on the floor, a crisp ring races out along the ground with two curved walls of air rising at its ends, a slower second ring and dust thrown up at the edges.",
  tags: ["impact", "shockwave", "ground", "ruby1", "one-shot"],
  size: [232, 84],
  origin: [116, 62],
  duration: 0.75,
  loop: false,
  fps: 30,
  bg: "ground",
  options: { palette: ["#0c2a1c", "#1d5a3a", "#2f8a55", "#53c07a", "#9cefb0", "#e6ffe9"], seed: 3 },
};

export function create(o) {
  const C = fit(o.palette, 6), R = new Rng(o.seed), floor = () => 0;
  const dust = new Particles({ rng: R, ground: floor, sparks: [C[5], C[4], C[3]] }), lights = new Lights();
  lights.add(0, -3, 40, C[4], 0.8, 0.25);
  lights.add(0, -2, 26, C[5], 1.0, 0.12);
  // polvo que salta en los bordes del anillo, a los dos lados
  for (let i = 0; i < 26; i++) {
    const s = i % 2 ? 1 : -1, v = R.range(140, 260);
    dust.spawn(P.DUST, s * R.range(8, 20), -1, s * v, -R.range(10, 40), R.range(0.3, 0.55), R.chance(0.5) ? C[3] : C[2], R.range(2, 3.6), R.range(0, 0.06));
  }
  for (let i = 0; i < 16; i++) {
    const s = R.sign(), a = -Math.PI / 2 + s * R.range(0.5, 1.3), v = R.range(90, 200);
    dust.spawn(P.SPARK, s * R.range(4, 12), -2, Math.cos(a) * v, Math.sin(a) * v, R.range(0.2, 0.4), C[5]);
  }
  let t = 0;
  // pared de aire: una media luna que se levanta al frente de la onda, a cada lado (como las ondas
  // originales): relleno translúcido, borde exterior brillante y la cresta blanca
  const wall = (p, r, g, side) => {
    const h = 30 * Math.sin(Math.PI * clamp(g * 1.25)), k = clamp(1.15 - g * 1.2);
    if (h < 2 || k <= 0) return;
    const w = 7 + 5 * g;
    for (let j = 0; j <= h; j++) {
      const u = j / h, lean = Math.pow(u, 1.6) * (8 + 8 * g);
      const outer = r - lean, inner = outer - w * (1 - u) - 1;
      for (let x = inner; x <= outer; x++) p.blend(side * x, -j, C[3], 0.35 * k * (1 - u * 0.6));
      p.px(side * outer, -j, u > 0.7 ? C[5] : C[4]);
      if (u > 0.82) p.px(side * (outer - 1), -j, WHITE);
      p.dot(side * inner, -j, C[2], 0.6 * k);
    }
    p.glow(side * (r - 4), -h * 0.5, 14, C[4], 0.35 * k);
  };
  return {
    update(dt) { t += dt; dust.update(dt); lights.update(dt); },
    draw(p) {
      // destello plano en el suelo, los dos primeros fotogramas
      if (t < 0.07) {
        const k = 1 - t / 0.07;
        p.line(-34 * k - 6, 0, 34 * k + 6, 0, WHITE);
        p.line(-20 * k - 3, -1, 20 * k + 3, -1, C[5]);
        p.glow(0, -2, 18, WHITE, 0.6 * k);
      }
      for (const [t0, dur, r1, th, k0] of [[0, 0.42, 104, 3, 1.0], [0.08, 0.6, 72, 4, 0.6]]) {
        const g = seg(t, t0, t0 + dur);
        if (g <= 0 || g >= 1) continue;
        const r = 4 + r1 * ease.outQuart(g), fade = 1 - g;
        // el anillo adelgaza en vez de punteado: se ve entero hasta el final
        band(p, 0, 0, r, 0.16, Math.max(0.5, th * fade), k0 * Math.min(1, fade * 1.6), [C[2], C[3], C[4], C[5]]);
        if (t0 === 0) {
          wall(p, r, g, 1);
          wall(p, r, g, -1);
        }
      }
      dust.draw(p);
      lights.draw(p);
    },
  };
}
