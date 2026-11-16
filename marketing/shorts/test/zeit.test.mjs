import assert from 'node:assert/strict';
import test from 'node:test';
import { pruefeBeschreibung } from '../lib/schema.mjs';
import { berechneZeitplan, folgeBild } from '../lib/zeit.mjs';

const beschreibung = () =>
  pruefeBeschreibung({
    id: 'probe',
    szenen: [
      { art: 'aufhaenger', text: 'Frage?', saetze: ['Frage?'] },
      { art: 'app', bild: 'bild.png', saetze: ['Erster Satz.', 'Zweiter Satz.'] },
      { art: 'schluss' },
    ],
  });
const dauern = (...sekunden) => new Map(sekunden.map((s, i) => [String(i + 1).padStart(2, '0'), { sekunden: s, datei: `${i + 1}.wav` }]));
const fest = { fps: 30, vorlauf: 0.3, pause_nach_satz: 0.2, nachlauf: 0.3, schluss_nachlauf: 0.6, schluss_dauer: 2.5 };

test('Szenendauer folgt aus dem Ton', () => {
  const plan = berechneZeitplan(beschreibung(), dauern(2, 1, 1.5), fest);
  // Szene 1: 9 Vorlauf + 60 + 9 Nachlauf
  assert.deepEqual([plan.szenen[0].von, plan.szenen[0].frames], [0, 78]);
  // Szene 2: 9 + 30 + 6 Pause + 45 + 9
  assert.deepEqual([plan.szenen[1].von, plan.szenen[1].frames], [78, 99]);
  // Schlusskarte ohne Satz: 2,5 s
  assert.deepEqual([plan.szenen[2].von, plan.szenen[2].frames], [177, 75]);
  assert.equal(plan.frames, 252);
  assert.equal(plan.sekunden, 8.4);
});

test('Satzbeginn liegt auf einem Bild, der Ton startet genau dort', () => {
  const plan = berechneZeitplan(beschreibung(), dauern(2, 1, 1.5), fest);
  const [erster, zweiter] = plan.szenen[1].saetze;
  assert.deepEqual([erster.nr, erster.von, erster.frames], ['02', 87, 30]);
  assert.deepEqual([zweiter.nr, zweiter.von, zweiter.frames], ['03', 123, 45]);
  assert.equal(zweiter.tonStart, 4.1);
  assert.equal(zweiter.datei, '3.wav');
});

test('krumme Länge wird aufgerundet, Sätze überlappen nie', () => {
  const plan = berechneZeitplan(beschreibung(), dauern(1.01, 2.345, 0.5), fest);
  assert.equal(plan.szenen[0].saetze[0].frames, 31);
  const alle = plan.szenen.flatMap((s) => s.saetze);
  for (let i = 1; i < alle.length; i++) {
    assert.ok(alle[i].tonStart >= alle[i - 1].tonStart + alle[i - 1].sekunden, `Satz ${alle[i].nr} überlappt`);
  }
  for (const s of plan.szenen) for (const satz of s.saetze) assert.ok(satz.von + satz.frames <= s.von + s.frames);
});

test('dauer ist Mindestdauer; Szenen schließen lückenlos an', () => {
  const b = beschreibung();
  b.szenen[0].dauer = 5;
  b.szenen[2].dauer = 1;
  const plan = berechneZeitplan(b, dauern(2, 1, 1.5), fest);
  assert.equal(plan.szenen[0].frames, 150);
  assert.equal(plan.szenen[2].frames, 30);
  let erwartet = 0;
  for (const s of plan.szenen) {
    assert.equal(s.von, erwartet);
    erwartet += s.frames;
  }
  assert.equal(plan.frames, erwartet);
});

test('fehlende Länge ist ein Fehler', () => {
  assert.throws(() => berechneZeitplan(beschreibung(), dauern(2, 1), fest), /Satz 03 hat keine Länge/);
});

test('andere Bildrate', () => {
  const plan = berechneZeitplan(beschreibung(), dauern(2, 1, 1.5), { ...fest, fps: 60 });
  assert.equal(plan.frames, 504);
  assert.equal(plan.sekunden, 8.4);
});

test('Stille zwischen zwei Sätzen: Pause in der Szene, Nachlauf + Vorlauf über die Szenengrenze', () => {
  const plan = berechneZeitplan(beschreibung(), dauern(2, 1, 1.5), { fps: 30, vorlauf: 0.1, pause_nach_satz: 0.2, nachlauf: 0.1 });
  const [a, b, c] = plan.szenen.flatMap((s) => s.saetze);
  assert.equal(b.von - (a.von + a.frames), 6);
  assert.equal(c.von - (b.von + b.frames), 6);
});

test('Schlusskarte mit Satz bleibt nach dem Satz stehen (schluss_nachlauf)', () => {
  const b = beschreibung();
  b.szenen[2].saetze = ['Schluss.'];
  const plan = berechneZeitplan(b, dauern(2, 1, 1.5, 3), fest);
  // 9 Vorlauf + 90 + 18 Nachlauf der Schlusskarte
  assert.equal(plan.szenen[2].frames, 117);
});

// --- App-Szenen: Fortsetzung, Bildfolge, Tipp, Aufhänger, Hervorhebung ---

const FOLGE = { fps: 30, bilder: 200, marken: { tipp: 40, gestartet: 46 }, ausschnitte: { knopf: { x: 0.1, y: 0.8, breite: 0.8, hoehe: 0.1 } } };
const mitFolge = (szenen) => pruefeBeschreibung({ id: 'probe', szenen }, { folge: (name) => (name === 'ablauf' ? FOLGE : undefined), fps: 30 });
const plane = (szenen, ...sekunden) => berechneZeitplan(mitFolge(szenen), dauern(...sekunden), fest);

test('Bild: Tipp bei einem Anteil der Szenendauer, Zeitpunkt steht für das Tipp-Geräusch im Plan', () => {
  const plan = berechneZeitplan(
    pruefeBeschreibung({
      id: 'probe',
      ausschnitte: { knopf: { x: 0.1, y: 0.5, breite: 0.8, hoehe: 0.1 } },
      szenen: [
        { art: 'aufhaenger', text: 'Frage?', dauer: 1 },
        { art: 'app', bild: 'bild.png', tipp: { auf: 'knopf', bei: 0.5 }, dauer: 2 },
        { art: 'app', bild: 'bild.png', dauer: 1 },
        { art: 'app', bild: 'anderes.png', dauer: 1 },
      ],
    }),
    dauern(),
    fest,
  );
  assert.equal(plan.szenen[1].tippBild, 30);
  assert.deepEqual(plan.tipps, [2]);
  // dieselbe Quelle wie davor: Fortsetzung ohne Übergang; anderes Bild: neuer Schnitt
  assert.deepEqual(plan.szenen.slice(1).map((s) => s.fortsetzung), [false, true, false]);
  assert.equal(plan.szenen[1].zoomBilder, 18);
});

test('Folge: Szenen setzen nacheinander fort, das letzte Bild bleibt stehen', () => {
  const plan = plane(
    [
      { art: 'app', folge: 'ablauf', bis: 20, dauer: 1 },
      { art: 'app', folge: 'ablauf', dauer: 2 },
      { art: 'app', folge: 'ablauf', dauer: 10 },
      { art: 'app', folge: 'ablauf', ab: 'gestartet', bis: 60, dauer: 1 },
    ],
  );
  const [a, b, c, d] = plan.szenen;
  // Szene 1 hält bei Bild 20 an (30 Bilder lang, Abschnitt 0–20)
  assert.deepEqual([a.folgeAb, a.folgeBis, a.folgeEnde, a.fortsetzung], [0, 20, 20, false]);
  assert.deepEqual([0, 20, 29].map((bild) => folgeBild(a, bild)), [0, 20, 20]);
  // Szene 2 beginnt genau dort: kein Sprung
  assert.deepEqual([b.folgeAb, b.folgeEnde, b.fortsetzung], [20, 80, true]);
  assert.equal(folgeBild(b, 0), folgeBild(a, a.frames - 1));
  // Szene 3 ist länger als der Rest der Folge: letztes Bild bleibt stehen
  assert.deepEqual([c.folgeAb, c.folgeBis, c.folgeEnde], [80, 199, 199]);
  assert.equal(folgeBild(c, 119), 199);
  assert.equal(folgeBild(c, 299), 199);
  // ausdrückliches „ab“ (Marke) springt in der Folge, bleibt aber Fortsetzung derselben Quelle
  assert.deepEqual([d.folgeAb, d.folgeBis, d.fortsetzung], [46, 60, true]);
});

test('Folge: Tipp-Markierung an der Marke „tipp“; „bei“ hält das erste Bild so lange an', () => {
  const szene = (tipp, dauer = 3) => [{ art: 'app', folge: 'ablauf', tipp, dauer }];
  const ohne = plane(szene({ auf: 'knopf' }));
  assert.deepEqual([ohne.szenen[0].tippBild, ohne.szenen[0].halten], [40, 0]);
  assert.equal(folgeBild(ohne.szenen[0], 40), 40);
  assert.deepEqual(ohne.tipps, [40 / 30]);

  const spaeter = plane(szene({ auf: 'knopf', bei: 0.6 })).szenen[0];
  assert.deepEqual([spaeter.tippBild, spaeter.halten], [54, 14]);
  assert.deepEqual([0, 14, 54, 89].map((bild) => folgeBild(spaeter, bild)), [0, 0, 40, 75]);
  assert.equal(spaeter.folgeEnde, 76);

  // „bei“ früher als die Marke: Die Folge wird nicht übersprungen, der Tipp bleibt an der Marke.
  assert.equal(plane(szene({ auf: 'knopf', bei: 0.1 })).szenen[0].tippBild, 40);
});

test('Folge: Tipp außerhalb des gezeigten Abschnitts ist ein Fehler', () => {
  assert.throws(() => plane([{ art: 'app', folge: 'ablauf', ab: 'gestartet', tipp: { auf: 'knopf' }, dauer: 3 }]), /Marke „tipp“ \(Bild 40\) liegt vor dem gezeigten Abschnitt/);
  assert.throws(() => plane([{ art: 'app', folge: 'ablauf', tipp: { auf: 'knopf' }, dauer: 1 }]), /wird in der Szene nicht erreicht/);
  assert.throws(() => plane([{ art: 'app', folge: 'ablauf', bis: 30, tipp: { auf: 'knopf' }, dauer: 3 }]), /wird in der Szene nicht erreicht/);
});

test('Aufhänger über dem App-Bild endet mit dem ersten Satz, Hervorhebung beginnt bei ihrem Anteil', () => {
  const plan = plane(
    [
      { art: 'app', folge: 'ablauf', bis: 0, aufhaenger: 'Frage?', saetze: ['Frage?', 'Noch ein Satz.'] },
      { art: 'app', folge: 'ablauf', hervorhebung: { auf: 'knopf', zeile: 'Feierabend heute', wert: '16:22 Uhr', bei: 0.25 }, zoom: { auf: 'knopf', dauer: 1 }, dauer: 4 },
    ],
    2,
    1,
  );
  // 9 Vorlauf + 60 Bilder Satz
  assert.equal(plan.szenen[0].aufhaengerBis, 69);
  assert.equal(plan.szenen[1].hervorhebung.abBild, 30);
  assert.equal(plan.szenen[1].hervorhebung.wert, '16:22 Uhr');
  assert.equal(plan.szenen[1].zoomBilder, 30);
  // „bis: 0“ friert das erste Bild ein, die nächste Szene läuft von dort los
  assert.equal(plan.szenen[1].folgeAb, 0);
});
