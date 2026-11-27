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
  const knopf = { x: 0.1, y: 0.5, breite: 0.8, hoehe: 0.1 };
  assert.deepEqual(b.szenen[1].zoom, { auf: 'knopf', faktor: 1.25, dauer: 0.6, rechteck: knopf });
  assert.deepEqual(b.szenen[1].tipp, { auf: 'knopf', rechteck: knopf, bei: 0.5 });
  assert.equal(b.szenen[1].premium, false);
  assert.equal(b.szenen[1].quelle, 'bild.png');
});

test('Untertitel gibt es nicht mehr: das Feld ist unbekannt', () => {
  const d = gueltig();
  d.szenen[1].untertitel = false;
  fehlerVon(d, /Szene 2 \(app\): unbekanntes Feld „untertitel“/);
});

test('unbekanntes Feld im Kopf, in der Szene, im Zoom und im Ausschnitt', () => {
  fehlerVon({ ...gueltig(), tempo: 2 }, /Kopf: unbekanntes Feld „tempo“/);
  const szene = gueltig();
  szene.szenen[1].zoomm = {};
  fehlerVon(szene, /Szene 2 \(app\): unbekanntes Feld „zoomm“/);
  const zoom = gueltig();
  zoom.szenen[1].zoom.tempo = 1;
  fehlerVon(zoom, /zoom: unbekanntes Feld „tempo“/);
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
  fehlerVon(ohne, /braucht genau eines von „bild“ und „folge“/);
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
  fehlerVon(d, /Ausschnitt „gibtsnicht“ ist weder unter „ausschnitte“ noch in der Folge beschrieben/);
  const rand = gueltig();
  rand.ausschnitte.knopf.breite = 0.95;
  fehlerVon(rand, /ragt über das Bild hinaus/);
  const faktor = gueltig();
  faktor.szenen[1].zoom.faktor = 4;
  fehlerVon(faktor, /„faktor“ muss zwischen 1 und 2.5/);
});

// --- Bildfolge, Aufhänger über dem App-Bild, Hervorhebung ---

const FOLGE = {
  fps: 30,
  bilder: 120,
  marken: { tipp: 30, gestartet: 36 },
  ausschnitte: { start_knopf: { x: 0.1, y: 0.86, breite: 0.8, hoehe: 0.06 }, knopf: { x: 0, y: 0, breite: 0.5, hoehe: 0.5 } },
};
const optionen = (folge = FOLGE) => ({ fps: 30, folge: (name) => (name === 'ablauf' ? folge : undefined) });
const mitFolge = (szene = {}) => ({
  id: 'probe',
  ausschnitte: { knopf: { x: 0.1, y: 0.5, breite: 0.8, hoehe: 0.1 } },
  szenen: [{ art: 'app', folge: 'ablauf', dauer: 2, ...szene }],
});

test('Folge: Abschnitt als Bildnummer oder Marke, Ausschnitte aus der Folge und aus der Videobeschreibung', () => {
  const b = pruefeBeschreibung(mitFolge({ ab: 10, bis: 'gestartet', zoom: { auf: 'start_knopf' }, tipp: { auf: 'knopf' } }), optionen());
  const szene = b.szenen[0];
  assert.deepEqual([szene.folge, szene.quelle, szene.ab, szene.bis, szene.tippMarke], ['ablauf', 'ablauf.mp4', 10, 36, 30]);
  assert.deepEqual(szene.zoom.rechteck, FOLGE.ausschnitte.start_knopf);
  // gleicher Name in beiden: die Videobeschreibung gewinnt; „bei“ hat bei einer Folge keinen Standard
  assert.deepEqual(szene.tipp, { auf: 'knopf', rechteck: { x: 0.1, y: 0.5, breite: 0.8, hoehe: 0.1 } });
  // ohne „ab“/„bis“: Fortsetzung bzw. Anfang, bis zum letzten Bild
  const offen = pruefeBeschreibung(mitFolge(), optionen()).szenen[0];
  assert.deepEqual([offen.ab, offen.bis], [undefined, 119]);
});

test('Folge: fehlende Datei, falsche Bildrate, unbekannte Marke, Abschnitt außerhalb', () => {
  fehlerVon(mitFolge({ folge: 'gibtsnicht' }), /Folge „gibtsnicht“: gibtsnicht.mp4 oder gibtsnicht.json fehlt/, optionen());
  fehlerVon(mitFolge(), /Folge „ablauf“: „fps“ ist 25, das Video läuft mit 30/, optionen({ ...FOLGE, fps: 25 }));
  fehlerVon(mitFolge(), /Marke „tipp“ muss eine Bildnummer von 0 bis 119 sein/, optionen({ ...FOLGE, marken: { tipp: 120 } }));
  fehlerVon(mitFolge(), /Folge „ablauf“, Ausschnitt „a“: Rechteck ist leer oder ragt über das Bild hinaus/, optionen({ ...FOLGE, ausschnitte: { a: { x: 0.5, y: 0, breite: 0.6, hoehe: 0.1 } } }));
  fehlerVon(mitFolge({ ab: 'spaeter' }), /„ab“: Marke „spaeter“ kennt die Folge nicht/, optionen());
  fehlerVon(mitFolge({ bis: 120 }), /„bis“ muss eine Bildnummer von 0 bis 119 oder eine Marke sein/, optionen());
  fehlerVon(mitFolge({ ab: 50, bis: 40 }), /„bis“ liegt vor „ab“/, optionen());
  fehlerVon(mitFolge({ tipp: { auf: 'knopf' } }), /Der Folge „ablauf“ fehlt die Marke „tipp“/, optionen({ ...FOLGE, marken: {} }));
  fehlerVon(mitFolge({ folge: '../ablauf' }), /„folge“ muss ein Name ohne Ordner und Endung sein/, optionen());
});

test('Bild und Folge schließen sich aus; „ab“/„bis“ nur mit Folge', () => {
  fehlerVon(mitFolge({ bild: 'bild.png' }), /braucht genau eines von „bild“ und „folge“/, optionen());
  const d = gueltig();
  d.szenen[1].bis = 5;
  fehlerVon(d, /„bis“ gibt es nur mit „folge“/);
});

test('Aufhänger über dem App-Bild', () => {
  const b = pruefeBeschreibung(mitFolge({ aufhaenger: ' Wann ist Feierabend? ' }), optionen());
  assert.equal(b.szenen[0].aufhaenger, 'Wann ist Feierabend?');
  fehlerVon(mitFolge({ aufhaenger: 'x'.repeat(61) }), /„aufhaenger“ ist länger als 60 Zeichen/, optionen());
  fehlerVon(mitFolge({ aufhaenger: 'Frage?', einblendung: 'Text' }), /„aufhaenger“ und „einblendung“ schließen sich aus/, optionen());
});

test('Hervorhebung: Ausschnitt und Wert sind Pflicht', () => {
  const h = { auf: 'start_knopf', zeile: 'Feierabend heute', wert: '16:22 Uhr' };
  const b = pruefeBeschreibung(mitFolge({ hervorhebung: h }), optionen());
  assert.deepEqual(b.szenen[0].hervorhebung, { auf: 'start_knopf', rechteck: FOLGE.ausschnitte.start_knopf, wert: '16:22 Uhr', bei: 0.2, zeile: 'Feierabend heute' });
  fehlerVon(mitFolge({ hervorhebung: { auf: 'start_knopf' } }), /hervorhebung: „wert“ fehlt/, optionen());
  fehlerVon(mitFolge({ hervorhebung: { ...h, wert: 1622 } }), /hervorhebung: „wert“ fehlt/, optionen());
  fehlerVon(mitFolge({ hervorhebung: { ...h, auf: 'nirgends' } }), /hervorhebung: Ausschnitt „nirgends“ ist weder/, optionen());
  fehlerVon(mitFolge({ hervorhebung: { ...h, bei: 2 } }), /hervorhebung: „bei“ muss zwischen 0 und 1 liegen/, optionen());
  fehlerVon(mitFolge({ hervorhebung: { ...h, farbe: 'rot' } }), /hervorhebung: unbekanntes Feld „farbe“/, optionen());
  fehlerVon(mitFolge({ hervorhebung: { ...h, wert: '1234567890123' } }), /„wert“ ist länger als 12 Zeichen/, optionen());
  // „nach“: Marke der Folge, vor der das Schild nicht erscheint
  assert.equal(pruefeBeschreibung(mitFolge({ hervorhebung: { ...h, nach: 'gestartet' } }), optionen()).szenen[0].hervorhebung.nachMarke, 36);
  fehlerVon(mitFolge({ hervorhebung: { ...h, nach: 'spaeter' } }), /hervorhebung: „nach“: Marke „spaeter“ kennt die Folge nicht/, optionen());
  const mitBild = gueltig();
  mitBild.szenen[1].hervorhebung = { auf: 'knopf', wert: '1', nach: 'gestartet' };
  fehlerVon(mitBild, /hervorhebung: „nach“ gibt es nur mit „folge“/);
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
