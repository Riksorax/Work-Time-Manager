import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { checkAll, exportAll } from '../lib/build.mjs';
import { TARGETS } from '../lib/targets.mjs';
import { decodePng, encodePng } from '../lib/png.mjs';

// Kleine, schnelle Auswahl: PNG, ICO und SVG
const SUBSET = ['web/public/favicon-32x32.png', 'web/public/favicon.ico', 'web/public/logo.svg', 'store/feature-graphic.png']
  .map((out) => TARGETS.find((t) => t.out === out));

function withTempRoot(fn) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'branding-'));
  try {
    fn(root);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
}

function nudgePng(file, { x, y, channel, delta }) {
  const img = decodePng(fs.readFileSync(file));
  const raw = fs.readFileSync(file);
  const colorType = raw[25];
  const i = (y * img.width + x) * 4 + channel;
  img.pixels[i] += delta;
  fs.writeFileSync(file, encodePng(img, { colorType }));
}

test('frisch exportiert: keine Drift, zweiter Export ist byte-identisch (idempotent)', () => {
  withTempRoot((root) => {
    exportAll({ root, targets: SUBSET });
    assert.deepEqual(checkAll({ root, targets: SUBSET }), []);
    const before = SUBSET.map((t) => fs.readFileSync(path.join(root, t.out)));
    exportAll({ root, targets: SUBSET });
    SUBSET.forEach((t, i) => assert.ok(before[i].equals(fs.readFileSync(path.join(root, t.out))), `${t.out} nicht idempotent`));
  });
});

test('fehlende Datei wird gemeldet', () => {
  withTempRoot((root) => {
    exportAll({ root, targets: SUBSET });
    fs.rmSync(path.join(root, 'web/public/favicon-32x32.png'));
    const findings = checkAll({ root, targets: SUBSET });
    assert.equal(findings.length, 1);
    assert.match(findings[0], /favicon-32x32\.png: fehlt/);
  });
});

test('Pixelabweichung um 1 ist Toleranz, um 2 ist Drift', () => {
  withTempRoot((root) => {
    exportAll({ root, targets: SUBSET });
    const file = path.join(root, 'store/feature-graphic.png');
    nudgePng(file, { x: 10, y: 10, channel: 2, delta: 1 });
    assert.deepEqual(checkAll({ root, targets: SUBSET }), [], 'Abweichung 1 muss toleriert werden');
    nudgePng(file, { x: 10, y: 10, channel: 2, delta: 1 });
    const findings = checkAll({ root, targets: SUBSET });
    assert.equal(findings.length, 1);
    assert.match(findings[0], /feature-graphic\.png: Pixelabweichung bis 2/);
  });
});

test('veränderte SVG-Kopie und ICO-Eintrag werden als Drift erkannt', () => {
  withTempRoot((root) => {
    exportAll({ root, targets: SUBSET });
    fs.appendFileSync(path.join(root, 'web/public/logo.svg'), '<!-- manipuliert -->');
    const ico = path.join(root, 'web/public/favicon.ico');
    const buf = fs.readFileSync(ico);
    buf[buf.length - 20] ^= 0xff; // Bytes im letzten PNG (zlib/CRC) zerstören
    fs.writeFileSync(ico, buf);
    const findings = checkAll({ root, targets: SUBSET }).join('\n');
    assert.match(findings, /logo\.svg: SVG weicht/);
    assert.match(findings, /favicon\.ico/);
  });
});

test('PNG-Kodierer/-Dekodierer: Rundreise für RGB und RGBA', () => {
  const pixels = Buffer.alloc(5 * 3 * 4);
  for (let i = 0; i < pixels.length; i++) pixels[i] = (i * 37) % 256;
  for (let i = 3; i < pixels.length; i += 4) pixels[i] = 255;
  const img = { width: 5, height: 3, pixels };
  for (const colorType of [2, 6]) {
    const back = decodePng(encodePng(img, { colorType }));
    assert.equal(back.colorType, colorType);
    assert.ok(back.pixels.equals(pixels), `Rundreise Typ ${colorType}`);
  }
});
