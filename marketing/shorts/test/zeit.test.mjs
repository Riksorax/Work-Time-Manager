import assert from 'node:assert/strict';
import test from 'node:test';
import { pruefeBeschreibung } from '../lib/schema.mjs';
import { berechneZeitplan, untertitelTeile, zeilen } from '../lib/zeit.mjs';

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
const fest = { fps: 30, vorlauf: 0.3, pause_nach_satz: 0.2, nachlauf: 0.3, schluss_dauer: 2.5, untertitel_zeichen: 30 };

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

test('Zeilenumbruch hält die Zeichenzahl ein', () => {
  assert.deepEqual(zeilen('Im Work Time Manager startest du deinen Arbeitstag', 30), ['Im Work Time Manager startest', 'du deinen Arbeitstag']);
  assert.deepEqual(zeilen('Donaudampfschifffahrtsgesellschaftskapitän fährt', 20), ['Donaudampfschifffahrtsgesellschaftskapitän', 'fährt']);
});

test('Untertitel: höchstens zwei Zeilen je Teil, kein Wort geht verloren', () => {
  const text = 'Die App zeigt dir live, dass du um 16:40 Uhr fertig bist, und dein Überstunden-Saldo steht bei +12:45 Stunden.';
  const teile = untertitelTeile(text, 30);
  assert.ok(teile.length >= 2);
  for (const teil of teile) {
    assert.ok(teil.length <= 2);
    for (const zeile of teil) assert.ok(zeile.length <= 30, zeile);
  }
  assert.equal(teile.flat().join(' '), text);
  // kurzer Satz bleibt eine Zeile, zwei Zeilen werden ausgeglichen
  assert.deepEqual(untertitelTeile('Kurz.', 30), [['Kurz.']]);
  assert.deepEqual(untertitelTeile('eins zwei drei vier fünf sechs sieben acht', 30), [['eins zwei drei vier', 'fünf sechs sieben acht']]);
});

test('Untertitel-Teile füllen den Satz lückenlos, nur in Szenen mit Untertitel', () => {
  const b = beschreibung();
  b.szenen[1].saetze[0] = 'Die App zeigt dir live, dass du um 16:40 Uhr fertig bist, und dein Überstunden-Saldo steht bei +12:45 Stunden.';
  const plan = berechneZeitplan(b, dauern(2, 6, 1.5), fest);
  assert.deepEqual(plan.szenen[0].saetze[0].untertitel, []);
  const satz = plan.szenen[1].saetze[0];
  let zeiger = satz.von;
  for (const teil of satz.untertitel) {
    assert.equal(teil.von, zeiger);
    zeiger += teil.frames;
  }
  assert.equal(zeiger, satz.von + satz.frames);
});
