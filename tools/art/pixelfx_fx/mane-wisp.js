// Ruby1: mota de la melena espiritual de Viridy (fotogramas para las partículas del juego, que la tiñen
// con el color del rango de estilo): una llamita que nace, se enrosca hacia arriba y se deshace en humo.
import { fit, seg, ease, clamp, mix, WHITE } from "../../core/index.js";

export const meta = {
  name: "Ruby1 mane wisp",
  desc: "A tiny spirit flame wisp: it flares from a dot, curls upward as a teardrop with a hot core, thins to a ribbon and breaks into faint smoke.",
  tags: ["wisp", "flame", "spirit", "particle", "ruby1", "one-shot"],
  size: [20, 30],
  origin: [10, 24],
  duration: 0.6,
  loop: false,
  fps: 30,
  bg: "dark",
  options: { palette: ["#0d2a1d", "#1f5e3c", "#3aa363", "#86e6a2", "#e0ffe8"], seed: 1 },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 5), D = meta.duration, g = t / D;
  if (g >= 1) return;
  const born = ease.outCubic(seg(g, 0, 0.18)), thin = seg(g, 0.45, 0.85), smoke = seg(g, 0.7, 1);
  const h = 4 + 14 * ease.outQuad(seg(g, 0, 0.7)), w = 3.2 * born * (1 - thin * 0.7);
  // cuerpo: gota que se curva (la punta se va hacia un lado)
  for (let j = 0; j <= h; j++) {
    const u = j / Math.max(h, 1), cx = Math.sin(u * 2.4 + g * 3) * 2.5 * u, rw = w * Math.sqrt(1 - u) * (1 - u * 0.3);
    for (let x = -rw; x <= rw; x += 0.5) {
      const e = Math.abs(x) / Math.max(rw, 0.1), core = e < 0.4 && u < 0.5;
      const c = core ? (g < 0.25 ? WHITE : C[4]) : e < 0.75 ? C[3] : C[2];
      p.dot(cx + x, -j, c, (1 - smoke) * (1 - u * 0.5));
    }
  }
  if (smoke > 0) p.disc(Math.sin(g * 5) * 2, -h - 2 * smoke, 2 + 3 * smoke, C[2], 0.35 * (1 - smoke));
  p.glow(0, -h * 0.3, 5, C[3], 0.35 * (1 - g));
}
