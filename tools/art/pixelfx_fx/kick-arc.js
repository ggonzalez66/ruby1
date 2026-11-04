// Ruby1: barrido de las patadas y el rodillazo: una media luna rápida que llena la zona de golpe y se va.
import { Rng, fit, clamp, seg, ease, mix, WHITE } from "../../core/index.js";

export const meta = {
  name: "Ruby1 kick arc",
  desc: "A fast kick smear: a crescent sweeps forward through the hit zone from low to high, its edge white-hot, then thins and fades with a puff of air at the tip.",
  tags: ["kick", "melee", "smear", "ruby1", "one-shot"],
  size: [140, 96],
  origin: [8, 48],
  duration: 0.3,
  loop: false,
  fps: 30,
  bg: "dark",
  options: { palette: ["#14261f", "#2c5546", "#4f8f74", "#96d6b8", "#e8fff4", "#ffffff"], seed: 6, reach: 118, height: 70 },
};

export function create(o) {
  const C = fit(o.palette, 6), RX = o.reach * 0.5, RY = o.height * 0.5, CX = RX * 0.75;
  let t = 0;
  // arco de la elipse que cubre la zona de golpe, de abajo-atrás a arriba-delante
  const A0 = 2.3, A1 = -1.25;
  return {
    update(dt) { t += dt; },
    draw(p) {
      // barrido muy rápido, se sostiene un instante y adelgaza desde la cola hasta desaparecer
      const sweep = ease.outQuart(seg(t, 0, 0.06)), fade = seg(t, 0.1, 0.3);
      const head = A0 + (A1 - A0) * sweep, tail = A0 + (A1 - A0) * clamp(fade * 1.1);
      const N = 260;
      for (let i = 0; i <= N; i++) {
        const a = A0 + (A1 - A0) * (i / N);
        if (a < head || a > tail) continue;
        const u = (a - tail) / ((head - tail) || 1);
        const thick = (20 * Math.pow(Math.sin(Math.PI * clamp(u * 0.92 + 0.04)), 0.6) + 2) * (1 - fade * 0.85);
        for (let s = 0; s < thick; s += 0.5) {
          const e = s / thick, k = s / RX;
          const x = CX + Math.cos(a) * RX * (1 - k), y = Math.sin(a) * RY * (1 - k * RY / RX);
          if (e < 0.14) p.px(x, y, WHITE);
          else if (e < 0.4) p.px(x, y, C[4]);
          else p.blend(x, y, e < 0.7 ? C[3] : C[2], 0.75 * (1 - e) + 0.15);
        }
        if (i % 18 === 0) p.glow(CX + Math.cos(a) * RX, Math.sin(a) * RY, 7, C[4], 0.25 * (1 - fade));
      }
      // soplo de aire en la punta al terminar el barrido
      if (t > 0.05 && t < 0.26) {
        const q = seg(t, 0.05, 0.26), x = CX + Math.cos(A1) * RX + 6 * q, y = Math.sin(A1) * RY - 4 * q;
        p.disc(x, y, 3 + 6 * q, C[3], 0.4 * (1 - q));
      }
    },
  };
}
