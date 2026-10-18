// Erzeugt die Zieldateien aus den SVG-Quellen und vergleicht sie mit dem Stand im Repo.
import fs from 'node:fs';
import path from 'node:path';
import { TARGETS } from './targets.mjs';
import { buildSvg, renderSvg, readSource, REPO_ROOT } from './render.mjs';
import { decodePng, encodePng } from './png.mjs';
import { packIco, parseIco } from './ico.mjs';

/** Höchster erlaubter Unterschied je Farbkanal beim Pixelvergleich (resvg kann je Plattform um 1 abweichen). */
export const PIXEL_TOLERANCE = 1;

function renderTarget(target, width, height) {
  const svg = buildSvg(target.src, target.viewBox);
  const img = renderSvg(svg, width);
  if (img.height !== height) {
    throw new Error(`${target.out}: Seitenverhältnis der Quelle passt nicht (${img.width}x${img.height}, erwartet ${width}x${height})`);
  }
  return img;
}

function assertOpaque(img, out) {
  for (let i = 3; i < img.pixels.length; i += 4) {
    if (img.pixels[i] !== 255) throw new Error(`${out}: Quelle ist nicht überall deckend`);
  }
}

function encodeFor(target, img) {
  if (target.alpha === 'rgb') {
    assertOpaque(img, target.out);
    return encodePng(img, { colorType: 2 });
  }
  if (target.alpha === 'opaque') assertOpaque(img, target.out);
  return encodePng(img, { colorType: 6 });
}

/** @returns {Buffer} Inhalt der Zieldatei */
export function buildTarget(target) {
  if (target.kind === 'svg') return Buffer.from(readSource(target.src), 'utf8');
  if (target.kind === 'ico') {
    const images = target.sizes.map((size) => ({
      size,
      data: encodePng(renderTarget(target, size, size), { colorType: 6 }),
    }));
    return packIco(images);
  }
  return encodeFor(target, renderTarget(target, target.width, target.height));
}

export function exportAll({ root = REPO_ROOT, targets = TARGETS, log = () => {} } = {}) {
  for (const target of targets) {
    const data = buildTarget(target);
    const file = path.join(root, target.out);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, data);
    log(`${target.out} (${data.length} Byte)`);
  }
}

/** Größter Kanalunterschied zweier gleich großer RGBA-Bilder (vollständig transparente Pixel zählen als gleich). */
export function maxPixelDiff(a, b) {
  let max = 0;
  for (let i = 0; i < a.pixels.length; i += 4) {
    if (a.pixels[i + 3] === 0 && b.pixels[i + 3] === 0) continue;
    for (let k = 0; k < 4; k++) {
      const d = Math.abs(a.pixels[i + k] - b.pixels[i + k]);
      if (d > max) max = d;
    }
  }
  return max;
}

function comparePng(expected, actual, label) {
  let a;
  let b;
  try {
    a = decodePng(expected);
    b = decodePng(actual);
  } catch (e) {
    return `${label}: nicht lesbar (${e.message})`;
  }
  if (a.width !== b.width || a.height !== b.height) {
    return `${label}: Größe ${b.width}x${b.height} statt ${a.width}x${a.height}`;
  }
  if (a.colorType !== b.colorType) return `${label}: Farbtyp ${b.colorType} statt ${a.colorType}`;
  const diff = maxPixelDiff(a, b);
  return diff > PIXEL_TOLERANCE ? `${label}: Pixelabweichung bis ${diff} (erlaubt ${PIXEL_TOLERANCE})` : null;
}

/** Vergleicht Datei und frische Erzeugung. @returns {string|null} Befund oder null */
export function compareData(target, expected, actual) {
  if (target.kind === 'svg') {
    return expected.equals(actual) ? null : `${target.out}: SVG weicht von der Quelle ab`;
  }
  if (target.kind === 'png') return comparePng(expected, actual, target.out);
  let a;
  let b;
  try {
    a = parseIco(expected);
    b = parseIco(actual);
  } catch (e) {
    return `${target.out}: nicht lesbar (${e.message})`;
  }
  if (a.length !== b.length) return `${target.out}: ${b.length} statt ${a.length} Einträge`;
  for (let i = 0; i < a.length; i++) {
    const r = comparePng(a[i].data, b[i].data, `${target.out} [${a[i].width}px]`);
    if (r) return r;
  }
  return null;
}

/** Drift-Check: @returns {string[]} Befunde, leer = alles aktuell */
export function checkAll({ root = REPO_ROOT, targets = TARGETS } = {}) {
  const findings = [];
  for (const target of targets) {
    const file = path.join(root, target.out);
    if (!fs.existsSync(file)) {
      findings.push(`${target.out}: fehlt`);
      continue;
    }
    const finding = compareData(target, fs.readFileSync(file), buildTarget(target));
    if (finding) findings.push(finding);
  }
  return findings;
}
