import assert from 'node:assert/strict';
import test from 'node:test';
import { BeschreibungsFehler, pruefeBeschreibung, pruefeDauern, saetzeMitNummer } from '../lib/schema.mjs';

const gueltig = () => ({
  id: 'probe',
  ausschnitte: { knopf: { x: 0.1, y: 0.5, breite: 0.8, hoehe: 0.1 } },
  szenen: [
    { art: 'aufhaenger', text: 'Eine Frage?', saetze: ['Eine Frage?'] },
    { art: 'app', bild: 'bild.png', zoom: { auf: 'knopf' }, tipp: { auf: 'knopf' }, saetze: ['Erster Satz.', 'Zweiter Satz.'] },
    { art: 'schluss' },
  ],
});

/** Erwartet genau einen Fehler, dessen Meldung zum Muster passt. */
function fehlerVon(daten, muster, optionen) {
  assert.throws(
    () => pruefeBeschreibung(daten, optionen),
    (f) => {
      assert.ok(f instanceof BeschreibungsFehler);
      assert.equal(f.meldungen.length, 1, f.message);
      assert.match(f.meldungen[0], muster);
      return true;
    },
  );
}

test('gültige Beschreibung: Standardwerte gesetzt', () => {
  const b = pruefeBeschreibung(gueltig(), { id: 'probe', bildVorhanden: () => true });
  assert.deepEqual(b.szenen[1].zoom, { auf: 'knopf', faktor: 1.25 });
  assert.deepEqual(b.szenen[1].tipp, { auf: 'knopf', bei: 0.5 });
  assert.equal(b.szenen[1].premium, false);
  // Untertitel nur dort, wo der Text nicht schon groß im Bild steht
  assert.deepEqual(b.szenen.map((s) => s.untertitel), [false, true, false]);
});

test('unbekanntes Feld im Kopf, in der Szene, im Zoom und im Ausschnitt', () => {
  fehlerVon({ ...gueltig(), tempo: 2 }, /Kopf: unbekanntes Feld „tempo“/);
  const szene = gueltig();
  szene.szenen[1].zoomm = {};
  fehlerVon(szene, /Szene 2 \(app\): unbekanntes Feld „zoomm“/);
  const zoom = gueltig();
  zoom.szenen[1].zoom.dauer = 1;
  fehlerVon(zoom, /zoom: unbekanntes Feld „dauer“/);
  const ausschnitt = gueltig();
  ausschnitt.ausschnitte.knopf.z = 1;
  fehlerVon(ausschnitt, /Ausschnitt „knopf“: unbekanntes Feld „z“/);
});

test('Feld einer anderen Szenenart ist unbekannt', () => {
  const d = gueltig();
  d.szenen[0].bild = 'bild.png';
  fehlerVon(d, /Szene 1 \(aufhaenger\): unbekanntes Feld „bild“/);
});

test('fehlendes Bild', () => {
  fehlerVon(gueltig(), /Szene 2 \(app\): Bild „bild.png“ fehlt/, { bildVorhanden: () => false });
  const ohne = gueltig();
  delete ohne.szenen[1].bild;
  fehlerVon(ohne, /„bild“ fehlt/);
  const pfad = gueltig();
  pfad.szenen[1].bild = '../geheim.png';
  fehlerVon(pfad, /ohne Ordner/);
});

test('ID passt nicht zum Dateinamen', () => {
  fehlerVon(gueltig(), /Datei heißt aber „anders.yaml“/, { id: 'anders' });
});

test('unbekannte Art, leere Szenenliste, leerer Satz', () => {
  const art = gueltig();
  art.szenen[0].art = 'intro';
  fehlerVon(art, /Szene 1: „art“ fehlt oder ist unbekannt/);
  fehlerVon({ id: 'probe', szenen: [] }, /„szenen“ fehlt oder ist leer/);
  const satz = gueltig();
  satz.szenen[1].saetze[1] = '  ';
  fehlerVon(satz, /Satz 2 ist leer/);
});

test('Szene ohne Satz braucht eine Dauer, die Schlusskarte nicht', () => {
  const d = gueltig();
  delete d.szenen[1].saetze;
  fehlerVon(d, /braucht „saetze“ oder „dauer“/);
  d.szenen[1].dauer = 2;
  assert.equal(pruefeBeschreibung(d).szenen[1].dauer, 2);
});

test('Zoom und Tipp verlangen einen beschriebenen Ausschnitt', () => {
  const d = gueltig();
  d.szenen[1].zoom.auf = 'gibtsnicht';
  fehlerVon(d, /Ausschnitt „gibtsnicht“ ist unter „ausschnitte“ nicht beschrieben/);
  const rand = gueltig();
  rand.ausschnitte.knopf.breite = 0.95;
  fehlerVon(rand, /ragt über das Bild hinaus/);
  const faktor = gueltig();
  faktor.szenen[1].zoom.faktor = 4;
  fehlerVon(faktor, /„faktor“ muss zwischen 1 und 2.5/);
});

test('mehrere Fehler werden gesammelt gemeldet', () => {
  const d = { ...gueltig(), x: 1 };
  d.szenen[0].y = 2;
  assert.throws(() => pruefeBeschreibung(d), (f) => f.meldungen.length === 2 && /Videobeschreibung ungültig/.test(f.message));
});

test('Sätze werden über alle Szenen durchnummeriert', () => {
  const b = pruefeBeschreibung(gueltig());
  assert.deepEqual(saetzeMitNummer(b).map((s) => [s.nr, s.szene]), [['01', 0], ['02', 1], ['03', 1]]);
});

test('Satz ohne Ton ist ein Fehler', () => {
  const b = pruefeBeschreibung(gueltig());
  const eintrag = (nr, text) => ({ nr, text, datei: `${nr}.wav`, sekunden: 1.5 });
  const alle = { saetze: [eintrag('01', 'Eine Frage?'), eintrag('02', 'Erster Satz.'), eintrag('03', 'Zweiter Satz.')] };
  assert.equal(pruefeDauern(b, alle).get('02').sekunden, 1.5);

  const pruefe = (json, muster, vorhanden) =>
    assert.throws(() => pruefeDauern(b, json, vorhanden), (f) => f.meldungen.length === 1 && muster.test(f.meldungen[0]));
  pruefe({ saetze: alle.saetze.slice(0, 2) }, /Satz 03 .*kein Ton/);
  pruefe(alle, /Satz 02 .*Tondatei „02.wav“ fehlt/, (datei) => datei !== '02.wav');
  pruefe({ saetze: [alle.saetze[0], eintrag('02', 'Alter Text.'), alle.saetze[2]] }, /Satz 02 .*anderem Text/);
  pruefe({ saetze: [alle.saetze[0], alle.saetze[1], { ...alle.saetze[2], sekunden: 0 }] }, /Satz 03 .*keine Länge/);
});
