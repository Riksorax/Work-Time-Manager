// Farben, Schrift und Logo kommen aus `branding/` (SVG-Master) und werden hier nur gelesen,
// nicht kopiert und nicht neu festgelegt. Ändert sich das Branding, ändern sich die Videos mit.
import fs from 'node:fs';
import path from 'node:path';

export const REPO = path.resolve(import.meta.dirname, '..', '..', '..');
export const BRANDING_SRC = path.join(REPO, 'branding', 'src');
// Dieselben Schriftdateien wie in branding/lib/render.mjs.
export const SCHRIFT_DATEIEN = {
  400: path.join(REPO, 'mobile', 'assets', 'fonts', 'OpenSans-Regular.ttf'),
  700: path.join(REPO, 'mobile', 'assets', 'fonts', 'OpenSans-Bold.ttf'),
};
export const LOGO = path.join(BRANDING_SRC, 'logo.svg');

/** Farben eines `<linearGradient id="…">` aus einem SVG-Text. */
export function verlauf(svg, id) {
  const block = new RegExp(`<linearGradient id="${id}"[^>]*>([\\s\\S]*?)</linearGradient>`).exec(svg);
  const farben = block ? [...block[1].matchAll(/stop-color="(#[0-9a-fA-F]{6})"/g)].map((m) => m[1].toLowerCase()) : [];
  if (farben.length < 2) throw new Error(`Branding: Verlauf „${id}“ nicht gefunden`);
  return farben;
}

/** @param {(name: string) => string} [lies] liest eine Datei aus `branding/src/` */
export function ladeMarke(lies = (name) => fs.readFileSync(path.join(BRANDING_SRC, name), 'utf8')) {
  const grafik = lies('feature-graphic.svg');
  const logo = lies('logo.svg');
  const name = /<title>([^<]+)<\/title>/.exec(logo)?.[1];
  const schrift = /font-family="([^",]+)/.exec(grafik)?.[1];
  if (!name || !schrift) throw new Error('Branding: Name (<title>) oder Schrift (font-family) nicht gefunden');
  return {
    name,
    schrift,
    grund: verlauf(grafik, 'bg'), // Markengrund: #1565c0 → #0d47a1
    akzent: verlauf(logo, 'gb'), // Türkis des Zahnrad-Badges
  };
}
