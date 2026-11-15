import assert from 'node:assert/strict';
import test from 'node:test';
import { KARTE, SCHUTZ_OBEN, SCHUTZ_UNTEN, UNTERTITEL, bildLage } from '../src/layout.mjs';

const bild = { breite: 1080, hoehe: 1920 };
const kartenHoehe = KARTE.unten - KARTE.oben;

test('Karte ist ca. 78 % breit und mittig; Untertitel und Einblendung liegen außerhalb der Schutzzonen', () => {
  assert.equal(Math.round((KARTE.breite / 1080) * 100), 78);
  assert.equal(KARTE.links * 2 + KARTE.breite, 1080);
  assert.ok(KARTE.oben >= SCHUTZ_OBEN);
  assert.equal(UNTERTITEL.unten, SCHUTZ_UNTEN);
});

test('ohne Ausschnitt steht das Bild oben bündig', () => {
  assert.deepEqual(bildLage(bild, undefined, 1.25, 1, kartenHoehe, 1000), { skala: 1, x: 0, y: 0, bildHoehe: 1496.888888888889 });
});

test('Zoom beginnt bei voller Breite und endet mit dem Ausschnitt in der Mitte', () => {
  const ausschnitt = { x: 0.3, y: 0.4, breite: 0.4, hoehe: 0.1 };
  const start = bildLage(bild, ausschnitt, 1.5, 0, kartenHoehe, 1000);
  assert.deepEqual([start.skala, start.x, start.y], [1, 0, 0]);
  const ende = bildLage(bild, ausschnitt, 1.5, 1, kartenHoehe, 1000);
  assert.equal(ende.skala, 1.5);
  // Mitte des Ausschnitts (50 %, 45 %) liegt in der Mitte der Karte bzw. des freien Bereichs
  assert.ok(Math.abs(0.5 * KARTE.breite * 1.5 + ende.x - KARTE.breite / 2) < 1e-9);
  assert.ok(Math.abs(0.45 * ende.bildHoehe * 1.5 + ende.y - 500) < 1e-9);
});

test('das Bild deckt die Karte immer ab (Ausschnitt in der Ecke)', () => {
  for (const ausschnitt of [{ x: 0, y: 0, breite: 0.1, hoehe: 0.05 }, { x: 0.9, y: 0.95, breite: 0.1, hoehe: 0.05 }]) {
    for (const fortschritt of [0, 0.5, 1]) {
      const l = bildLage(bild, ausschnitt, 1.4, fortschritt, kartenHoehe, 1000);
      assert.ok(l.x <= 0 && l.x + KARTE.breite * l.skala >= KARTE.breite - 1e-9);
      assert.ok(l.y <= 0 && l.y + l.bildHoehe * l.skala >= kartenHoehe - 1e-9);
    }
  }
});
