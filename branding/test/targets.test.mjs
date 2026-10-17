import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { TARGETS } from '../lib/targets.mjs';
import { SRC_DIR, BRANDING_DIR } from '../lib/render.mjs';
import { readPngHeader } from '../lib/png.mjs';
import { built, decoded, target } from './support.mjs';

const ALPHA_MODES = ['rgba', 'opaque', 'rgb', 'white'];

test('Zieltabelle: jede Datei ist eindeutig und vollständig beschrieben', () => {
  const outs = TARGETS.map((t) => t.out);
  assert.equal(new Set(outs).size, outs.length, 'doppelte Ausgabedatei');
  for (const t of TARGETS) {
    const sources = Array.isArray(t.src) ? t.src : [t.src];
    assert.ok(sources.length > 0, `${t.out}: keine Quelle`);
    for (const s of sources) assert.ok(fs.existsSync(path.join(SRC_DIR, s)), `${t.out}: Quelle ${s} fehlt`);
    assert.ok(t.use && t.use.length > 0, `${t.out}: Verwendung fehlt`);
    assert.ok(['png', 'ico', 'svg'].includes(t.kind), `${t.out}: unbekanntes Format ${t.kind}`);
    if (t.kind === 'png') {
      assert.ok(Number.isInteger(t.width) && t.width > 0, `${t.out}: Breite fehlt`);
      assert.ok(Number.isInteger(t.height) && t.height > 0, `${t.out}: Höhe fehlt`);
      assert.ok(ALPHA_MODES.includes(t.alpha), `${t.out}: Alpha-Modus fehlt`);
      assert.ok(t.out.endsWith('.png'));
    }
    if (t.kind === 'ico') assert.ok(t.sizes?.length > 0, `${t.out}: ICO-Größen fehlen`);
  }
});

test('Zieltabelle: jede Quelldatei in src/ wird verwendet', () => {
  const used = new Set(TARGETS.flatMap((t) => (Array.isArray(t.src) ? t.src : [t.src])));
  for (const f of fs.readdirSync(SRC_DIR)) assert.ok(used.has(f), `${f} wird von keinem Ziel verwendet`);
});

test('README nennt jede erzeugte Datei', () => {
  const readme = fs.readFileSync(path.join(BRANDING_DIR, 'README.md'), 'utf8');
  for (const t of TARGETS) assert.ok(readme.includes(t.out), `README ohne ${t.out}`);
});

test('PNG-Ausgabe hat exakt die Zielgröße', () => {
  for (const t of TARGETS.filter((x) => x.kind === 'png')) {
    const h = readPngHeader(built(t.out));
    assert.equal(`${h.width}x${h.height}`, `${t.width}x${t.height}`, t.out);
  }
});

test('Store-Icon: 512x512, Alpha-Kanal überall 255', () => {
  const img = decoded('store/icon-512.png');
  assert.equal(img.colorType, 6, '32 Bit verlangt');
  assert.equal(img.width, 512);
  for (let i = 3; i < img.pixels.length; i += 4) assert.equal(img.pixels[i], 255);
});

test('Feature Graphic: 1024x500 ohne Alpha-Kanal (Color Type 2)', () => {
  const h = readPngHeader(built('store/feature-graphic.png'));
  assert.deepEqual([h.width, h.height, h.colorType], [1024, 500, 2]);
});

test('OG-Image: 1200x630 ohne Alpha', () => {
  const h = readPngHeader(built('web/public/og-image.png'));
  assert.deepEqual([h.width, h.height, h.colorType], [1200, 630, 2]);
});

test('Apple-Touch-Icon ist deckend (ohne Alpha) mit 180 px', () => {
  const h = readPngHeader(built('web/public/apple-touch-icon.png'));
  assert.deepEqual([h.width, h.height, h.colorType], [180, 180, 2]);
});

test('ic_notification: nur weiß auf transparent, in allen Dichten', () => {
  const sizes = { mdpi: 24, hdpi: 36, xhdpi: 48, xxhdpi: 72, xxxhdpi: 96 };
  for (const [density, size] of Object.entries(sizes)) {
    const out = `mobile/android/app/src/main/res/drawable-${density}/ic_notification.png`;
    const img = decoded(out);
    assert.equal(img.width, size, out);
    let visible = 0;
    for (let i = 0; i < img.pixels.length; i += 4) {
      if (img.pixels[i + 3] > 0) {
        visible++;
        assert.deepEqual([...img.pixels.subarray(i, i + 3)], [255, 255, 255], `${out}: nicht weiß`);
      }
    }
    assert.ok(visible > size * size * 0.1, `${out}: Silhouette fast leer`);
    assert.ok(visible < size * size * 0.9, `${out}: Silhouette füllt alles`);
  }
});

test('Manifest-Icons: any und maskable nie dieselbe Datei, jede Größe vorhanden', () => {
  const icons = TARGETS.filter((t) => t.manifest);
  for (const purpose of ['any', 'maskable']) {
    const sizes = icons.filter((t) => t.manifest === purpose).map((t) => t.width).sort((a, b) => a - b);
    assert.deepEqual(sizes, [192, 512], `${purpose}: 192 und 512 erwartet`);
  }
  const files = icons.map((t) => t.out);
  assert.equal(new Set(files).size, files.length);
  const maskable = icons.filter((t) => t.manifest === 'maskable').map((t) => t.out);
  const any = icons.filter((t) => t.manifest === 'any').map((t) => t.out);
  for (const f of maskable) assert.ok(!any.includes(f));
  // Dateinamen der bestehenden any-Icons bleiben (Manifest und Browser-Caches verweisen darauf)
  assert.ok(any.includes('web/public/icon-192x192.png') && any.includes('web/public/icon-512x512.png'));
  assert.ok(target('web/public/icon-maskable-512x512.png'));
});
