// Gemeinsame Helfer: jedes Ziel wird je Testlauf nur einmal gerendert.
import { buildTarget } from '../lib/build.mjs';
import { TARGETS } from '../lib/targets.mjs';
import { decodePng } from '../lib/png.mjs';

const cache = new Map();

export function target(out) {
  const t = TARGETS.find((x) => x.out === out);
  if (!t) throw new Error(`Ziel nicht in targets.mjs: ${out}`);
  return t;
}

export function built(out) {
  if (!cache.has(out)) cache.set(out, buildTarget(target(out)));
  return cache.get(out);
}

export function decoded(out) {
  return decodePng(built(out));
}

/** RGBA-Wert an Position (x, y). */
export function pixelAt(img, x, y) {
  const i = (y * img.width + x) * 4;
  return [img.pixels[i], img.pixels[i + 1], img.pixels[i + 2], img.pixels[i + 3]];
}
