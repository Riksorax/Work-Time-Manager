// SVG -> RGBA-Pixel mit @resvg/resvg-js. Schriften kommen ausschließlich aus dem
// Repo (OpenSans), Systemschriften sind abgeschaltet: gleiche Ausgabe auf jeder Maschine.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Resvg } from '@resvg/resvg-js';
import { decodePng } from './png.mjs';

export const BRANDING_DIR = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
export const REPO_ROOT = path.resolve(BRANDING_DIR, '..');
export const SRC_DIR = path.join(BRANDING_DIR, 'src');

const FONT_FILES = ['OpenSans-Bold.ttf', 'OpenSans-Regular.ttf'].map((f) =>
  path.join(REPO_ROOT, 'mobile', 'assets', 'fonts', f),
);

export function readSource(name) {
  return fs.readFileSync(path.join(SRC_DIR, name), 'utf8');
}

/** Inhalt zwischen <svg ...> und </svg> (Kommentar vor dem Wurzelelement entfällt). */
function innerSvg(text) {
  return text.replace(/^[\s\S]*?<svg\b[^>]*>/, '').replace(/<\/svg>\s*$/, '');
}

/**
 * Baut den SVG-Text eines Ziels. Mehrere Quellen werden übereinandergelegt
 * (erste unten); `viewBox` schneidet aus (z. B. Maskable: Motiv im 80-%-Kreis).
 */
export function buildSvg(src, viewBox) {
  const layers = Array.isArray(src) ? src : [src];
  if (layers.length === 1 && !viewBox) return readSource(layers[0]);
  const vb = viewBox ?? '0 0 1024 1024';
  const [, , w, h] = vb.split(/\s+/).map(Number);
  const body = layers.map((l) => innerSvg(readSource(l))).join('\n');
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="${vb}">${body}</svg>`;
}

/** @returns {{width:number,height:number,pixels:Buffer}} RGBA (gerade Werte, nicht vormultipliziert) */
export function renderSvg(svgText, width) {
  const resvg = new Resvg(svgText, {
    fitTo: { mode: 'width', value: width },
    font: {
      loadSystemFonts: false,
      fontFiles: FONT_FILES,
      defaultFontFamily: 'Open Sans',
    },
  });
  // `img.pixels` ist vormultipliziert; der PNG-Weg liefert die gewünschten geraden Werte.
  const { width: w, height: h, pixels } = decodePng(resvg.render().asPng());
  return { width: w, height: h, pixels };
}
