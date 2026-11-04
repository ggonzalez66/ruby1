// Ruby1: hoja que cae dando vueltas (bucle; el juego la hace caer y mecerse).
import { fit, TAU } from "../../core/index.js";

export const meta = {
  name: "Ruby1 falling leaf",
  desc: "A single jungle leaf tumbling: it turns edge-on and flips, showing its lit top and darker underside with a midrib.",
  tags: ["leaf", "nature", "ambient", "ruby1", "loop"],
  size: [20, 20],
  origin: [10, 10],
  duration: 1.2,
  loop: true,
  fps: 30,
  bg: "dark",
  options: { palette: ["#163314", "#2c5e22", "#4f8f2e", "#86c24a", "#c4ea7c"], seed: 1 },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 5), ph = (t / meta.duration) * TAU;
  const turn = Math.cos(ph), tilt = 0.5 * Math.sin(ph);
  const L = 6, W = 2.6 * Math.abs(turn) + 0.6, top = turn > 0;
  const ca = Math.cos(tilt), sa = Math.sin(tilt);
  for (let u = -L; u <= L; u += 0.5) {
    const w = W * Math.sqrt(1 - (u / L) ** 2);
    for (let v = -w; v <= w; v += 0.5) {
      const x = u * ca - v * sa, y = u * sa + v * ca, edge = Math.abs(v) / Math.max(w, 0.1);
      const c = top ? (edge < 0.25 ? C[3] : v < 0 ? C[4] : C[2]) : edge < 0.25 ? C[1] : C[2];
      p.px(x, y, c);
    }
  }
  // tallo
  p.px(-L * ca - 1, -L * sa, C[1]);
}
