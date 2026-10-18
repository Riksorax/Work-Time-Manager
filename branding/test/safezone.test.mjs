import { test } from 'node:test';
import assert from 'node:assert/strict';
import { decoded, pixelAt } from './support.mjs';

/** Kleinster Abstand zur Bildmitte, ab dem ein Pixel `pred` erfüllt. */
function maxDistance(img, pred) {
  const c = img.width / 2;
  let max = 0;
  for (let y = 0; y < img.height; y++) {
    for (let x = 0; x < img.width; x++) {
      if (pred(pixelAt(img, x, y))) max = Math.max(max, Math.hypot(x + 0.5 - c, y + 0.5 - c));
    }
  }
  return max;
}

test('Adaptiv: Vordergrund und Silhouette liegen im 66-dp-Kreis des 108-dp-Rasters', () => {
  for (const name of ['adaptive_foreground', 'adaptive_monochrome']) {
    const img = decoded(`mobile/assets/icon/${name}.png`);
    const limit = (33 / 108) * img.width;
    const reach = maxDistance(img, (p) => p[3] > 0);
    assert.ok(reach > limit * 0.85, `${name}: Motiv zu klein (${reach.toFixed(1)} von ${limit.toFixed(1)})`);
    assert.ok(reach <= limit, `${name}: Motiv ragt aus der Safe Zone (${reach.toFixed(1)} > ${limit.toFixed(1)})`);
  }
});

test('Adaptiv: Hintergrund ist vollflächig #1565C0', () => {
  const img = decoded('mobile/assets/icon/adaptive_background.png');
  for (const [x, y] of [[0, 0], [1023, 0], [512, 512], [1023, 1023]]) {
    assert.deepEqual(pixelAt(img, x, y), [0x15, 0x65, 0xc0, 255]);
  }
});

test('Maskable: außerhalb des mittleren 80-%-Kreises nur Hintergrundfarbe, Motiv füllt ihn gut aus', () => {
  for (const size of [192, 512]) {
    const img = decoded(`web/public/icon-maskable-${size}x${size}.png`);
    const limit = 0.4 * size;
    const reach = maxDistance(img, (p) => p[0] !== 0x15 || p[1] !== 0x65 || p[2] !== 0xc0);
    assert.ok(reach <= limit, `${size}: Motiv ragt über den 80-%-Kreis (${reach.toFixed(1)} > ${limit})`);
    assert.ok(reach > limit * 0.85, `${size}: Motiv zu klein (${reach.toFixed(1)})`);
    assert.deepEqual(pixelAt(img, 0, 0), [0x15, 0x65, 0xc0, 255]);
  }
});

test('Any-Icons und In-App-Logo: transparent im Rand, Motiv mittig', () => {
  const img = decoded('web/public/icon-512x512.png');
  assert.equal(pixelAt(img, 0, 0)[3], 0);
  assert.equal(pixelAt(img, 511, 511)[3], 0);
  assert.ok(pixelAt(img, 130, 256)[3] > 0, 'Aussenring links');
});
