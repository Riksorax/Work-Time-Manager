import assert from 'node:assert/strict';
import test from 'node:test';
import {
  AUFHAENGER_ABSTAND,
  AUFHAENGER_RAND,
  BREITE,
  EINBLENDUNG,
  FREI,
  HOEHE,
  RAND,
  SCHILD,
  aufLeinwand,
  aufhaengerFlaeche,
  aufhaengerSchrift,
  bildMass,
  deckt,
  istFrei,
  kamera,
  mische,
  schildHoehe,
  schildLage,
  szenenKamera,
  ueberdecktY,
  wertSchrift,
} from '../src/layout.mjs';

const bild = { breite: 1080, hoehe: 1920 };
const nah = (a, b, genau = 1e-6) => assert.ok(Math.abs(a - b) < genau, `${a} ≠ ${b}`);

test('bildfüllend: ein 9:16-Bild ist bei Skala 1 deckungsgleich mit der Leinwand', () => {
  assert.deepEqual(bildMass(bild), { breite: 1080, hoehe: 1920 });
  assert.deepEqual(kamera(bild), { skala: 1, x: 0, y: 0 });
  // Der Faktor ohne Ausschnitt ändert nichts.
  assert.deepEqual(kamera(bild, undefined, 1.5), { skala: 1, x: 0, y: 0 });
  assert.deepEqual(aufLeinwand(kamera(bild), bild, { x: 0, y: 0, breite: 1, hoehe: 1 }), { x: 0, y: 0, breite: 1080, hoehe: 1920 });
  assert.deepEqual(FREI, { oben: 250, unten: 1500 });
});

test('anderes Seitenverhältnis: Das Bild deckt die Leinwand trotzdem ganz', () => {
  for (const anderes of [{ breite: 1080, hoehe: 2400 }, { breite: 1200, hoehe: 1920 }, { breite: 540, hoehe: 960 }]) {
    const lage = kamera(anderes);
    assert.ok(deckt(lage, anderes), JSON.stringify(anderes));
    const mass = bildMass(anderes);
    assert.ok(mass.breite >= BREITE && mass.hoehe >= HOEHE);
    // waagerecht mittig, oben bündig
    nah(lage.x, (BREITE - mass.breite) / 2);
    assert.equal(lage.y, 0);
  }
});

test('Zoom legt die Mitte des Ausschnitts in die Mitte der freien Fläche', () => {
  const ausschnitt = { x: 0.3, y: 0.4, breite: 0.4, hoehe: 0.1 };
  const lage = kamera(bild, ausschnitt, 1.5);
  assert.equal(lage.skala, 1.5);
  const r = aufLeinwand(lage, bild, ausschnitt);
  nah(r.x + r.breite / 2, 540);
  nah(r.y + r.hoehe / 2, (FREI.oben + FREI.unten) / 2);
  nah(r.breite, 0.4 * 1080 * 1.5);
  assert.ok(deckt(lage, bild));
});

test('nie Rand oder Hintergrund: Die Kamera deckt die Leinwand für jeden Ausschnitt und Faktor', () => {
  const stellen = [0, 0.05, 0.3, 0.5, 0.86, 0.94];
  for (const faktor of [1, 1.08, 1.25, 2.5]) {
    for (const x of stellen) {
      for (const y of stellen) {
        const lage = kamera(bild, { x, y, breite: 0.06, hoehe: 0.06 }, faktor);
        assert.ok(deckt(lage, bild), `Faktor ${faktor}, Ausschnitt ${x}/${y}: ${JSON.stringify(lage)}`);
      }
    }
  }
});

test('ein Ausschnitt am Bildrand bleibt in der Schutzzone: Das Bild rückt nicht über die Leinwand hinaus', () => {
  const knopf = { x: 0.08, y: 0.86, breite: 0.84, hoehe: 0.06 };
  for (const faktor of [1, 1.2]) {
    const lage = kamera(bild, knopf, faktor);
    // unten bündig, der Knopf liegt weiter unter der freien Fläche
    nah(lage.y + 1920 * faktor, HOEHE);
    assert.equal(istFrei(aufLeinwand(lage, bild, knopf)), false);
  }
  const titel = { x: 0.3, y: 0.01, breite: 0.4, hoehe: 0.04 };
  assert.equal(kamera(bild, titel, 1).y, 0);
  assert.equal(istFrei(aufLeinwand(kamera(bild, titel, 1), bild, titel)), false);
  // In der Bildmitte liegt derselbe Knopf frei (Folge mit Wischgeste).
  const gewischt = { ...knopf, y: 0.55 };
  assert.ok(istFrei(aufLeinwand(kamera(bild, gewischt, 1), bild, gewischt)));
});

test('mit Einblendung zielt der Zoom auf die Fläche unter der Platte', () => {
  const ausschnitt = { x: 0.3, y: 0.5, breite: 0.4, hoehe: 0.1 };
  const lage = szenenKamera({ einblendung: 'Text', zoom: { rechteck: ausschnitt, faktor: 1.5 } }, bild);
  const r = aufLeinwand(lage, bild, ausschnitt);
  const unterPlatte = EINBLENDUNG.oben + EINBLENDUNG.hoehe + RAND;
  nah(r.y + r.hoehe / 2, (unterPlatte + FREI.unten) / 2);
  assert.ok(deckt(lage, bild));
  // Die Platte selbst liegt in der freien Fläche.
  assert.ok(istFrei({ y: EINBLENDUNG.oben, hoehe: EINBLENDUNG.hoehe }));
  assert.deepEqual(szenenKamera({}, bild), kamera(bild));
});

test('Kamerafahrt: Zwischenlagen liegen zwischen Start und Ziel und decken die Leinwand', () => {
  const a = kamera(bild);
  const b = kamera(bild, { x: 0.3, y: 0.4, breite: 0.4, hoehe: 0.1 }, 1.5);
  assert.deepEqual(mische(a, b, 0), a);
  assert.deepEqual(mische(a, b, 1), b);
  assert.equal(mische(a, b, 0.5).skala, 1.25);
  const c = kamera(bild, { x: 0.7, y: 0.9, breite: 0.2, hoehe: 0.05 }, 2.5);
  const d = kamera(bild, { x: 0, y: 0, breite: 0.2, hoehe: 0.05 }, 1.1);
  for (const [von, nach] of [[a, b], [b, c], [c, d], [d, a]]) {
    for (let t = 0; t <= 1; t += 0.05) assert.ok(deckt(mische(von, nach, t), bild), `t = ${t}`);
  }
});

test('Aufhänger: Die Platte lässt den Ausschnitt der Kamerafahrt frei und bleibt zwischen den Schutzzonen', () => {
  assert.deepEqual(aufhaengerFlaeche(undefined), { oben: FREI.oben + AUFHAENGER_RAND, unten: FREI.unten - AUFHAENGER_RAND, anker: 'mitte' });

  // Großer Timer oben im Bild: Platte darunter, am unteren Ende der freien Fläche.
  const timer = { x: 250, y: 200, breite: 580, hoehe: 190 };
  const unter = aufhaengerFlaeche(timer);
  assert.equal(unter.anker, 'unten');
  assert.equal(unter.oben, timer.y + timer.hoehe + AUFHAENGER_ABSTAND);
  assert.equal(unter.unten, FREI.unten - AUFHAENGER_RAND);
  assert.equal(ueberdecktY({ y: unter.oben, hoehe: unter.unten - unter.oben }, timer), false);

  // Ausschnitt unten im Bild: Platte darüber, am oberen Ende.
  const knopf = { x: 80, y: 1200, breite: 900, hoehe: 140 };
  const ueber = aufhaengerFlaeche(knopf);
  assert.deepEqual(ueber, { oben: FREI.oben + AUFHAENGER_RAND, unten: knopf.y - AUFHAENGER_ABSTAND, anker: 'oben' });

  // Ausschnitt in einer Schutzzone: Die Fläche beginnt trotzdem erst in der freien Fläche.
  assert.equal(aufhaengerFlaeche({ x: 0, y: 20, breite: 1080, hoehe: 100 }).oben, FREI.oben + AUFHAENGER_RAND);
  // Drei Zeilen der größten Stufe passen in die Fläche unter dem Timer.
  for (const text of ['Kurz?', 'Wann hast du heute eigentlich Feierabend?', 'x'.repeat(60)]) {
    assert.ok(aufhaengerSchrift(text) >= 80);
    assert.ok(aufhaengerSchrift(text) * 1.14 * 4 + 150 <= unter.unten - unter.oben);
  }
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
  // Was über der Quelle steht (z. B. „Heutige Überstunden“), bleibt frei.
  assert.equal(ueberdecktY({ y: unter.y, hoehe }, { y: 760, hoehe: 160 }), false);

  const tief = { x: 240, y: 1300, breite: 600, hoehe: 36 };
  const ueber = schildLage(tief, '16:22 Uhr');
  assert.equal(ueber.unter, false);
  assert.equal(ueber.y + hoehe, tief.y - SCHILD.abstand);
  assert.ok(istFrei({ y: ueber.y, hoehe }));

  // Quelle so hoch wie die freie Fläche oder selbst in einer Schutzzone: Das Schild bleibt frei.
  for (const quelle of [{ x: 100, y: 300, breite: 100, hoehe: 1150 }, { x: 100, y: 1700, breite: 800, hoehe: 100 }, { x: 100, y: 40, breite: 800, hoehe: 100 }]) {
    assert.ok(istFrei({ y: schildLage(quelle, '16:22 Uhr').y, hoehe }), JSON.stringify(quelle));
  }
  // Die Spitze bleibt innerhalb des Schilds, auch wenn die Quelle am Rand liegt.
  assert.ok(schildLage({ x: 0, y: 900, breite: 60, hoehe: 30 }, '1').spitzeX >= SCHILD.links + 90);
});
