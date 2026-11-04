// Ruby1: orbe de energía del ruby roto que vuela hacia Viridy (bucle; el juego lo mueve).
import { Rng, fit, TAU, WHITE } from "../../core/index.js";

export const meta = {
  name: "Ruby1 energy orb",
  desc: "A small orb of gem energy: a hot white core, a pulsing colored body and a glow, with two motes circling it.",
  tags: ["orb", "energy", "pickup", "ruby1", "loop"],
  size: [24, 24],
  origin: [12, 12],
  duration: 0.4,
  loop: true,
  fps: 30,
  bg: "dark",
  options: { palette: ["#3a0612", "#8a1430", "#e0365a", "#ff9ab0", "#fff2f5"], seed: 2 },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 5), ph = (t / meta.duration) * TAU;
  const r = 3.2 + 0.7 * Math.sin(ph);
  p.glow(0, 0, 9, C[2], 0.55);
  p.circle(0, 0, r + 1, C[1]);
  p.circle(0, 0, r, C[2]);
  p.circle(-0.6, -0.6, r * 0.6, C[3]);
  p.px(-1, -1, C[4]);
  p.px(0, -1, WHITE);
  for (let i = 0; i < 2; i++) {
    const a = ph + i * Math.PI, x = Math.cos(a) * 6.5, y = Math.sin(a) * 3;
    p.px(x, y, i ? C[3] : C[4]);
    p.glow(x, y, 2.5, C[3], 0.4);
  }
}
