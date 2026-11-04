// Ruby1: luciérnaga de la jungla (bucle; el juego la hace vagar): cuerpo oscuro, alas que vibran y una
// cola que se enciende y se apaga despacio.
import { fit, hex, TAU, WHITE } from "../../core/index.js";

export const meta = {
  name: "Ruby1 firefly",
  desc: "A single firefly hovering: a dark body with buzzing wings and a tail lantern that swells to a warm glow and dims.",
  tags: ["critter", "firefly", "ambient", "ruby1", "loop"],
  size: [20, 20],
  origin: [10, 10],
  duration: 2.0,
  loop: true,
  fps: 30,
  bg: "dark",
  options: { palette: ["#1d2a10", "#4c6b1c", "#a6d636", "#e9ff8a", "#fffde0"], seed: 1 },
};

const BODY = hex("#2a2418"), WING = hex("#c8d8e8");

export function draw(p, t, o) {
  const C = fit(o.palette, 5), ph = (t / meta.duration) * TAU;
  const k = Math.pow(0.5 + 0.5 * Math.sin(ph), 2);
  p.glow(0, 1, 2 + 6 * k, C[2], 0.25 + 0.55 * k);
  p.px(0, 1, k > 0.6 ? C[4] : k > 0.25 ? C[3] : C[2]);
  p.px(1, 1, k > 0.4 ? C[3] : C[1]);
  p.px(-1, 0, BODY);
  p.px(-2, 0, BODY);
  const flap = Math.sin(ph * 12) > 0;
  p.dot(-1, flap ? -1 : -2, WING, 0.6);
  p.dot(0, flap ? -2 : -1, WING, 0.5);
}
