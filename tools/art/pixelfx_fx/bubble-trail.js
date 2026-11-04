// Ruby1: burbujas que se desprenden bajo el agua y suben bamboleándose hasta reventar.
import { Rng, fit, seg, clamp, WHITE } from "../../core/index.js";

export const meta = {
  name: "Ruby1 bubble trail",
  desc: "A puff of air bubbles underwater: a few bubbles of different sizes break off, wobble upward and pop into a tiny ring.",
  tags: ["water", "bubbles", "ruby1", "one-shot"],
  size: [40, 90],
  origin: [20, 80],
  duration: 1.4,
  loop: false,
  fps: 30,
  bg: "dark",
  options: { palette: ["#123a4a", "#2a7a94", "#7fd0e8", "#e6fbff"], seed: 3, count: 5 },
};

export function create(o) {
  const C = fit(o.palette, 4), R = new Rng(o.seed);
  const list = [];
  for (let i = 0; i < o.count; i++) {
    list.push({ x: R.range(-4, 4), delay: R.range(0, 0.18), r: R.chance(0.4) ? 3 : R.chance(0.5) ? 2 : 1.4, rise: R.range(45, 70),
      life: R.range(0.6, 0.85), wob: R.range(6, 10), ph: R.range(0, 6.28) });
  }
  let t = 0;
  return {
    update(dt) { t += dt; },
    draw(p) {
      for (const b of list) {
        const g = seg(t, b.delay, b.delay + b.life);
        if (g <= 0 || g >= 1.15) continue;
        const y = -b.rise * Math.min(g, 1) - 2, x = b.x + Math.sin(t * b.wob + b.ph) * 1.6;
        if (g >= 1) {
          // revienta: un anillito que se abre y desaparece
          const q = (g - 1) / 0.15;
          p.ring ? p.ring(x, y, b.r + 2 * q, 1, C[2], 1 - q) : p.dot(x, y, C[2], 1 - q);
          continue;
        }
        p.circle(x, y, b.r + 0.6, C[2]);
        p.circle(x, y, b.r - 0.4, C[0]);
        p.px(x - b.r * 0.4, y - b.r * 0.4, WHITE);
        p.glow(x, y, b.r + 3, C[2], 0.12);
      }
    },
  };
}
