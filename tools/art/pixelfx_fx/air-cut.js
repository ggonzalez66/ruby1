// Ruby1: el corte que deja el uppercut en el aire: una media luna fina que aparece de golpe, se queda
// flotando y se deshace desde la cola hacia la punta.
import { Rng, fit, clamp, seg, ease, mix, WHITE, TAU } from "../../core/index.js";

export const meta = {
  name: "Ruby1 air cut",
  desc: "A rising slash leaves a thin crescent cut in the air: it snaps in, hangs glowing, and dissolves from tail to tip with a few glints drifting off.",
  tags: ["slash", "melee", "trail", "ruby1", "one-shot"],
  size: [96, 150],
  origin: [30, 136],
  duration: 1.0,
  loop: false,
  fps: 30,
  bg: "dark",
  options: { palette: ["#0d2a22", "#1f5e48", "#3aa37a", "#7fe0b4", "#d4fff0", "#ffffff"], seed: 4, height: 118, bulge: 34 },
};

export function create(o) {
  const C = fit(o.palette, 6), R = new Rng(o.seed), H = o.height, B = o.bulge;
  // la media luna: de abajo (0, 0) arriba (0, -H), abombada hacia delante
  const at = (u) => [Math.sin(u * Math.PI) * B - u * 6, -u * H];
  const width = (u) => 4.5 * Math.sin(Math.PI * Math.pow(u, 0.8));
  const glints = [];
  for (let i = 0; i < 10; i++) glints.push({ u: R.range(0.1, 0.95), t0: R.range(0.25, 0.7), vx: R.range(4, 14), vy: R.range(-16, -4), life: R.range(0.25, 0.45) });
  let t = 0;
  return {
    update(dt) { t += dt; },
    draw(p) {
      const grow = ease.outExpo(seg(t, 0, 0.06));
      const dissolve = seg(t, 0.32, 0.95);
      const N = 90;
      for (let i = 0; i <= N; i++) {
        const u = i / N;
        if (u > grow) break;
        // se deshace desde la cola: cada punto se apaga cuando el frente de disolución lo pasa
        const front = dissolve * 1.25 - 0.15, k = clamp((u - front) / 0.25);
        if (k <= 0) continue;
        const [x, y] = at(u), [x2, y2] = at(Math.min(1, u + 1 / N));
        const nx = -(y2 - y), ny = x2 - x, L = Math.hypot(nx, ny) || 1;
        const w = width(u) * (t < 0.12 ? 1.3 : 1) * (0.5 + 0.5 * k);
        for (let s = -w; s <= w; s += 0.5) {
          const e = Math.abs(s) / Math.max(w, 0.01);
          const c = e < 0.3 ? (t < 0.1 ? WHITE : C[5]) : e < 0.65 ? C[4] : C[3];
          p.dot(x + (nx / L) * s, y + (ny / L) * s, c, k * (1 - e * 0.4));
        }
        if (i % 6 === 0) p.glow(x, y, 7, C[3], 0.18 * k);
      }
      for (const g of glints) {
        const q = seg(t, g.t0, g.t0 + g.life);
        if (q <= 0 || q >= 1) continue;
        const [x, y] = at(g.u), d = t - g.t0;
        p.dot(x + g.vx * d, y + g.vy * d, q < 0.5 ? C[5] : C[3], 1 - q);
        p.glow(x + g.vx * d, y + g.vy * d, 3, C[4], 0.3 * (1 - q));
      }
    },
  };
}
