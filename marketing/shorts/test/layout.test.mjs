import assert from 'node:assert/strict';
import test from 'node:test';
import { FREI, KARTE, RAND, SCHILD, aufLeinwand, bildHoehe, istFrei, kamera, kartenRechteck, mische, schildHoehe, schildLage, szenenKamera, wertSchrift } from '../src/layout.mjs';

const bild = { breite: 1080, hoehe: 1920 };
const nah = (a, b, genau = 1e-6) => assert.ok(Math.abs(a - b) < genau, `${a} ≠ ${b}`);

test('Karte füllt die Leinwand fast aus: 1000 px breit, mittig, ein 9:16-Bild passt bei Skala 1 genau hinein', () => {
  assert.equal(KARTE.links * 2 + KARTE.breite, 1080);
  assert.ok(KARTE.breite / 1080 > 0.9);
  nah(KARTE.unten - KARTE.oben, bildHoehe(bild), 0.5);
  // Die Karte ragt in beide Schutzzonen, die freie Fläche liegt ganz in ihr.
  assert.ok(KARTE.oben < FREI.oben && KARTE.unten > FREI.unten);
  assert.deepEqual(FREI, { oben: 250, unten: 1500 });
});

test('ohne Ausschnitt steht das Bild oben bündig in voller Breite', () => {
  assert.deepEqual(kamera(bild, undefined, 1.5), { skala: 1, x: KARTE.links, y: KARTE.oben, oben: KARTE.oben });
  const karte = kartenRechteck(kamera(bild), bild);
  assert.deepEqual([karte.x, karte.y, karte.breite], [40, 102, 1000]);
  nah(karte.y + karte.hoehe, KARTE.unten, 0.5);
});

test('Zoom legt die Mitte des Ausschnitts in die Mitte der freien Fläche', () => {
  const ausschnitt = { x: 0.3, y: 0.4, breite: 0.4, hoehe: 0.1 };
  const lage = kamera(bild, ausschnitt, 1.5);
  assert.equal(lage.skala, 1.5);
  const r = aufLeinwand(lage, bild, ausschnitt);
  nah(r.x + r.breite / 2, 540);
  nah(r.y + r.hoehe / 2, (FREI.oben + FREI.unten) / 2);
  nah(r.breite, 0.4 * 1000 * 1.5);
});

test('das Bild deckt die Karte ab, solange der Ausschnitt dabei frei liegt', () => {
  const ausschnitt = { x: 0, y: 0.3, breite: 0.1, hoehe: 0.05 };
  const lage = kamera(bild, ausschnitt, 1.4);
  assert.ok(lage.x <= KARTE.links && lage.x + 1000 * 1.4 >= KARTE.links + KARTE.breite - 1e-6);
  assert.ok(lage.y <= KARTE.oben && lage.y + bildHoehe(bild) * 1.4 >= KARTE.unten - 1e-6);
  assert.ok(istFrei(aufLeinwand(lage, bild, ausschnitt)));
});

test('ein Ausschnitt am Bildrand wird aus der Schutzzone geholt, die Karte endet dann früher', () => {
  const knopf = { x: 0.08, y: 0.86, breite: 0.84, hoehe: 0.06 };
  // Ohne Zoom läge der Knopf unten in der Schutzzone.
  assert.equal(istFrei(aufLeinwand(kamera(bild), bild, knopf)), false);
  for (const faktor of [1, 1.2]) {
    const lage = kamera(bild, knopf, faktor);
    const r = aufLeinwand(lage, bild, knopf);
    nah(r.y + r.hoehe, FREI.unten - RAND);
    const karte = kartenRechteck(lage, bild);
    assert.equal(karte.y, KARTE.oben);
    assert.ok(karte.y + karte.hoehe < KARTE.unten);
  }
  // Dasselbe oben: Der Ausschnitt rückt unter die obere Schutzzone, die Karte beginnt tiefer.
  const titel = { x: 0.3, y: 0.01, breite: 0.4, hoehe: 0.04 };
  const lage = kamera(bild, titel, 1);
  nah(aufLeinwand(lage, bild, titel).y, FREI.oben + RAND);
  assert.ok(kartenRechteck(lage, bild).y > KARTE.oben);
});

test('mit Einblendung beginnt die Karte tiefer, der Zoom zielt auf die Fläche darunter', () => {
  const ausschnitt = { x: 0.3, y: 0.5, breite: 0.4, hoehe: 0.1 };
  const lage = szenenKamera({ einblendung: 'Text', zoom: { rechteck: ausschnitt, faktor: 1.5 } }, bild);
  assert.equal(lage.oben, KARTE.obenMitEinblendung);
  const r = aufLeinwand(lage, bild, ausschnitt);
  nah(r.y + r.hoehe / 2, (KARTE.obenMitEinblendung + FREI.unten) / 2);
  assert.equal(kartenRechteck(lage, bild).y, KARTE.obenMitEinblendung);
  assert.deepEqual(szenenKamera({}, bild), kamera(bild));
});

test('Kamerafahrt: Zwischenlage liegt zwischen Start und Ziel', () => {
  const a = kamera(bild);
  const b = kamera(bild, { x: 0.3, y: 0.4, breite: 0.4, hoehe: 0.1 }, 1.5);
  assert.deepEqual(mische(a, b, 0), a);
  assert.deepEqual(mische(a, b, 1), b);
  assert.equal(mische(a, b, 0.5).skala, 1.25);
});

test('Schild der Hervorhebung: große Zahl, direkt unter der Quelle, nie in einer Schutzzone', () => {
  assert.ok(wertSchrift('16:22 Uhr') >= 150);
  assert.equal(wertSchrift('8 h'), SCHILD.wertMax);
  assert.ok(wertSchrift('+12:45 Std.') * 0.56 * 11 <= SCHILD.wertBreite);
  const hoehe = schildHoehe('16:22 Uhr');

  const mitte = { x: 240, y: 930, breite: 600, hoehe: 36 };
  const unter = schildLage(mitte, '16:22 Uhr');
  assert.equal(unter.unter, true);
  assert.equal(unter.y, mitte.y + mitte.hoehe + SCHILD.abstand);
  assert.equal(unter.spitzeX, 540);
  assert.ok(istFrei({ y: unter.y, hoehe }));

  const tief = { x: 240, y: 1300, breite: 600, hoehe: 36 };
  const ueber = schildLage(tief, '16:22 Uhr');
  assert.equal(ueber.unter, false);
  assert.equal(ueber.y + hoehe, tief.y - SCHILD.abstand);
  assert.ok(istFrei({ y: ueber.y, hoehe }));

  // Quelle so hoch wie die freie Fläche: Das Schild bleibt trotzdem frei von den Schutzzonen.
  const riesig = { x: 100, y: 300, breite: 100, hoehe: 1150 };
  assert.ok(istFrei({ y: schildLage(riesig, '16:22 Uhr').y, hoehe }));
  // Die Spitze bleibt innerhalb des Schilds, auch wenn die Quelle am Rand liegt.
  assert.ok(schildLage({ x: 0, y: 900, breite: 60, hoehe: 30 }, '1').spitzeX >= SCHILD.links + 90);
});
