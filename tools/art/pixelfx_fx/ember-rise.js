// Ruby1: brasas que se levantan del suelo al caer el picado y quedan suspendidas un momento.
import { Lights, Rng, fit, clamp, seg, ease, mix, WHITE, TAU } from "../../core/index.js";

export const meta = {
  name: "Ruby1 ember rise",
  desc: "Embers burst up from a strip of ground, brake hard, hang in the air glowing and flickering for a moment, then cool and drift down as they go out.",
  tags: ["embers", "fire", "ground", "ruby1", "one-shot"],
  size: [150, 110],
  origin: [75, 96],
  duration: 1.5,
  loop: false,
  fps: 30,
  bg: "ground",
  options: { palette: ["#06251a", "#145c38", "#2a9a58", "#58d67f", "#a8f7bd", "#efffef"], seed: 5, count: 34, width: 56 },
};

export function create(o) {
  const C = fit(o.palette, 6), R = new Rng(o.seed), lights = new Lights();
  lights.add(0, -6, 34, C[3], 0.7, 0.35);
  const embers = [];
  for (let i = 0; i < o.count; i++) {
    const x = R.range(-o.width / 2, o.width / 2) * (0.4 + 0.6 * R.next());
    // cuánto sube cada una antes de frenar: las del centro, más alto
    const rise = R.range(22, 70) * (1 - Math.abs(x) / o.width * 0.8);
    embers.push({
      x0: x, x: x, y: -1, rise, delay: R.range(0, 0.08),
      up: R.range(0.16, 0.26), hang: R.range(0.35, 0.65), cool: R.range(0.35, 0.55),
      drift: R.range(-10, 10), sway: R.range(1, 3), ph: R.range(0, TAU), size: R.chance(0.45) ? 2 : 1,
      flick: R.range(9, 16),
    });
  }
  let t = 0;
  return {
    update(dt) { t += dt; lights.update(dt); },
    draw(p) {
      // chispazo en el suelo al tocar
      if (t < 0.1) {
        const k = 1 - t / 0.1;
        p.line(-o.width * 0.5 * k, 0, o.width * 0.5 * k, 0, C[5]);
        p.glow(0, -2, 16, C[4], 0.5 * k);
      }
      for (const e of embers) {
        const te = t - e.delay;
        if (te <= 0) continue;
        const gUp = seg(te, 0, e.up), gHang = seg(te, e.up, e.up + e.hang), gCool = seg(te, e.up + e.hang, e.up + e.hang + e.cool);
        if (gCool >= 1) continue;
        // sube muy rápido y frena en seco; suspendida flota apenas; al enfriarse cae un poco
        let y = -e.rise * ease.outExpo(gUp) - 4 * Math.sin(gHang * Math.PI * 0.5) + 10 * gCool * gCool;
        const x = e.x0 + e.drift * (gUp * 0.3 + gHang * 0.4 + gCool * 0.3) + Math.sin(te * e.sway * 3 + e.ph) * (gHang > 0 ? 1.2 : 0);
        const heat = gCool > 0 ? 1 - gCool : 1;
        const flick = 0.75 + 0.25 * Math.sin(te * e.flick + e.ph);
        // blancas solo al salir disparadas; suspendidas, verde vivo que parpadea; al enfriarse, verde oscuro
        const c = gUp < 0.6 ? C[5] : heat > 0.85 ? (flick > 0.95 ? C[5] : C[4]) : heat > 0.45 ? C[3] : C[2];
        const k = clamp(heat * 1.4) * flick;
        // estela mientras sube rápido
        if (gUp < 1) {
          const len = 6 * (1 - gUp);
          p.line(x, y, x, y + len, (u) => mix(c, C[2], u), (u) => k * (1 - u));
        }
        p.dot(x, y, c, k);
        if (e.size > 1) {
          p.dot(x + 1, y, c, k * 0.85); p.dot(x, y - 1, c, k * 0.85); p.dot(x + 1, y - 1, mix(c, C[5], 0.5), k * 0.7);
          // las grandes, suspendidas, echan un destello en cruz al parpadear
          if (gHang > 0 && gCool <= 0 && flick > 0.97) { p.dot(x - 1, y, C[4], 0.7); p.dot(x + 2, y - 1, C[4], 0.7); p.dot(x, y - 2, C[4], 0.7); p.dot(x + 1, y + 1, C[4], 0.7); }
        }
        p.glow(x, y, e.size > 1 ? 6 : 4, C[3], 0.45 * k);
      }
      lights.draw(p);
    },
  };
}
