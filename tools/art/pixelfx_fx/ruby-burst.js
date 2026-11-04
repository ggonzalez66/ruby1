// Ruby1: el ruby estalla en una nube con forma de rombo (como la gema), con un rombo de luz que se abre.
import { Lights, Rng, fit, clamp, seg, ease, mix, WHITE, TAU } from "../../core/index.js";

export const meta = {
  name: "Ruby1 ruby burst",
  desc: "A ruby shatters: a white diamond flash, a diamond outline opening outward, a cloud that keeps the rhombus shape as it swells and thins, and shards from the corners.",
  tags: ["explosion", "gem", "crystal", "ruby1", "one-shot"],
  size: [160, 200],
  origin: [80, 100],
  duration: 1.1,
  loop: false,
  fps: 30,
  bg: "dark",
  options: { palette: ["#2a0610", "#5e0d22", "#a3183a", "#e0365a", "#ff8aa0", "#fff0f3"], seed: 9, radius: 54 },
};

// punto del contorno del rombo (ancho 0.72 del alto) para u en 0..1 alrededor
function rhombus(u, r) {
  u = ((u % 1) + 1) % 1;
  const a = u * 4, side = Math.floor(a) % 4, f = a - Math.floor(a);
  const P = [[0, -r], [r * 0.72, 0], [0, r], [-r * 0.72, 0]];
  const p0 = P[side], p1 = P[(side + 1) % 4];
  return [p0[0] + (p1[0] - p0[0]) * f, p0[1] + (p1[1] - p0[1]) * f];
}

export function create(o) {
  const C = fit(o.palette, 6), R = new Rng(o.seed), lights = new Lights(), RAD = o.radius;
  lights.add(0, 0, 44, C[4], 0.9, 0.3);
  lights.add(0, 0, 18, C[5], 1.0, 0.12);
  // bocanadas repartidas sobre el rombo (y algunas hacia dentro) que se hinchan y se aclaran
  const puffs = [];
  for (let i = 0; i < 64; i++) {
    const u = (i + R.range(-0.3, 0.3)) / 64, depth = R.chance(0.85) ? R.range(0.88, 1.04) : R.range(0.4, 0.7);
    // más chicas cerca de las puntas para que el rombo quede afilado
    const corner = Math.abs(((u * 4) % 1) - 0.5) * 2;
    puffs.push({ u, depth, size: R.range(4, 8) * (0.55 + 0.45 * (1 - corner)) * (depth > 0.75 ? 1 : 1.3), delay: R.range(0, 0.06), life: R.range(0.55, 0.85), lit: R.chance(0.45) });
  }
  // las cuatro puntas se estiran un poco más allá
  for (let i = 0; i < 4; i++) for (let j = 0; j < 3; j++) {
    puffs.push({ u: i / 4 + R.range(-0.01, 0.01), depth: 1.02 + j * 0.06, size: R.range(3, 4.5) - j * 0.6, delay: R.range(0.01, 0.05), life: R.range(0.5, 0.7), lit: true });
  }
  // esquirlas que salen de las cuatro puntas y de los lados
  const shards = [];
  for (let i = 0; i < 16; i++) {
    const corner = i % 4, u = corner / 4 + 0.25 * (i < 8 ? 0 : R.range(0.3, 0.7));
    const [ex, ey] = rhombus(u, 1);
    const len = Math.hypot(ex, ey);
    shards.push({ dx: ex / len, dy: ey / len, v: R.range(110, 190), life: R.range(0.35, 0.6), size: R.range(3, 6), spin: R.range(-12, 12) });
  }
  let t = 0;
  const outline = (p, r, k, c) => {
    const n = Math.ceil(r * 12);
    for (let i = 0; i < n; i++) {
      const [x, y] = rhombus(i / n, r);
      p.dot(x, y, c, k);
    }
  };
  return {
    update(dt) { t += dt; lights.update(dt); },
    draw(p) {
      // 1. destello: un rombo blanco macizo que se encoge
      if (t < 0.09) {
        const k = 1 - t / 0.09, r = 10 + 8 * k;
        p.poly([[0, -r], [r * 0.72, 0], [0, r], [-r * 0.72, 0]], WHITE);
        p.glow(0, 0, 26, C[5], 0.8 * k);
      }
      // 2. la nube: cada bocanada viaja hacia fuera conservando la forma de rombo
      for (const q of puffs) {
        const g = seg(t, q.delay, q.delay + q.life);
        if (g <= 0 || g >= 1) continue;
        const r = RAD * q.depth * ease.outExpo(g) * 0.95 + 4;
        const [x, y] = rhombus(q.u, r);
        const rad = q.size * (0.6 + 0.8 * g), a = 0.72 * (1 - g) * (1 - g);
        p.disc(x, y, rad, (d) => (d < 0.45 && q.lit ? C[4] : d < 0.8 ? C[3] : C[2]), a);
        if (g < 0.35) p.disc(x, y - rad * 0.2, rad * 0.5, C[5], a * 0.6);
      }
      // 3. contorno nítido del rombo que se abre y se rompe en puntos
      const go = seg(t, 0.02, 0.45);
      if (go > 0 && go < 1) {
        const r = 8 + (RAD + 10) * ease.outQuart(go);
        outline(p, r, 1 - go, go < 0.4 ? C[5] : C[4]);
        outline(p, r - 2, 0.6 * (1 - go), C[3]);
      }
      // 4. esquirlas: rombitos alargados que giran y se apagan
      for (const s of shards) {
        const g = seg(t, 0.03, 0.03 + s.life);
        if (g <= 0 || g >= 1) continue;
        const d = s.v * (t - 0.03) * (1 - 0.45 * g), x = s.dx * d, y = s.dy * d;
        const a = Math.atan2(s.dy, s.dx) + s.spin * (t - 0.03), L = s.size * (1 - g * 0.5);
        const ca = Math.cos(a), sa = Math.sin(a);
        p.poly([[x + ca * L, y + sa * L], [x - sa * 1.5, y + ca * 1.5], [x - ca * L * 0.5, y - sa * L * 0.5], [x + sa * 1.5, y - ca * 1.5]], g < 0.5 ? C[4] : C[3]);
        p.px(x + ca * L * 0.6, y + sa * L * 0.6, C[5]);
        p.glow(x, y, 4, C[4], 0.3 * (1 - g));
      }
      lights.draw(p);
    },
  };
}
