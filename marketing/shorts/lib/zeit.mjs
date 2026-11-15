// Zeitberechnung: Aus den Satzlängen (Ton) wird der Ablauf in Bildern. Reine Funktionen,
// keine Uhr, kein Datum.
import { saetzeMitNummer } from './schema.mjs';

export const STANDARD = {
  fps: 30,
  vorlauf: 0.3,
  pause_nach_satz: 0.25,
  nachlauf: 0.3,
  schluss_dauer: 2.5,
  untertitel_zeichen: 30,
};

/** Bricht Wörter gierig in Zeilen mit höchstens `max` Zeichen. Ein überlanges Wort bleibt allein. */
export function zeilen(text, max) {
  const ergebnis = [];
  let zeile = '';
  for (const wort of text.trim().split(/\s+/)) {
    if (zeile === '') zeile = wort;
    else if (zeile.length + 1 + wort.length <= max) zeile += ` ${wort}`;
    else {
      ergebnis.push(zeile);
      zeile = wort;
    }
  }
  if (zeile !== '') ergebnis.push(zeile);
  return ergebnis;
}

/** Zwei Zeilen möglichst gleich lang umbrechen (beide höchstens `max`). */
function ausgleichen(paar, max) {
  if (paar.length < 2) return paar;
  const woerter = paar.join(' ').split(' ');
  let beste = paar;
  let besteDifferenz = Math.abs(paar[0].length - paar[1].length);
  for (let i = 1; i < woerter.length; i++) {
    const a = woerter.slice(0, i).join(' ');
    const b = woerter.slice(i).join(' ');
    if (a.length > max || b.length > max) continue;
    const differenz = Math.abs(a.length - b.length);
    if (differenz < besteDifferenz) {
      beste = [a, b];
      besteDifferenz = differenz;
    }
  }
  return beste;
}

/**
 * Teilt einen Satz in Untertitel-Teile mit je höchstens zwei Zeilen.
 * @returns {string[][]} Teile, jeder Teil ist eine Liste von ein oder zwei Zeilen
 */
export function untertitelTeile(text, max = STANDARD.untertitel_zeichen) {
  const alle = zeilen(text, max);
  const teile = [];
  for (let i = 0; i < alle.length; i += 2) teile.push(ausgleichen(alle.slice(i, i + 2), max));
  return teile;
}

/**
 * Berechnet den Ablauf des Videos in Bildern.
 *
 * Je Szene: Vorlauf, dann die Sätze nacheinander mit Pause dazwischen, dann Nachlauf. Eine
 * Szene ohne Satz dauert `dauer` (Schlusskarte: `schluss_dauer`); mit Sätzen ist `dauer` eine
 * Mindestdauer. Jeder Satz beginnt auf einem Bild, der Ton startet genau dort (`tonStart`).
 *
 * @param {ReturnType<import('./schema.mjs').pruefeBeschreibung>} beschreibung
 * @param {Map<string, {sekunden: number, datei?: string}>} dauern je Satznummer
 * @param {Partial<typeof STANDARD>} [einstellungen]
 */
export function berechneZeitplan(beschreibung, dauern, einstellungen = {}) {
  const e = { ...STANDARD, ...einstellungen };
  const bilder = (sekunden) => Math.round(sekunden * e.fps);
  const nummern = saetzeMitNummer(beschreibung);
  let von = 0;
  let laufend = 0;
  const szenen = beschreibung.szenen.map((szene) => {
    let zeiger = von + (szene.saetze.length > 0 ? bilder(e.vorlauf) : 0);
    const saetze = szene.saetze.map((text, i) => {
      const { nr } = nummern[laufend++];
      const dauer = dauern.get(nr);
      if (!dauer) throw new Error(`Satz ${nr} hat keine Länge (kein Ton)`);
      // Aufrunden: Der Untertitel bleibt stehen, bis der Ton zu Ende ist.
      const frames = Math.max(1, Math.ceil(dauer.sekunden * e.fps - 1e-9));
      const satz = { nr, text, von: zeiger, frames, tonStart: zeiger / e.fps, sekunden: dauer.sekunden, datei: dauer.datei };
      satz.untertitel = szene.untertitel ? verteile(untertitelTeile(text, e.untertitel_zeichen), zeiger, frames) : [];
      zeiger += frames + (i < szene.saetze.length - 1 ? bilder(e.pause_nach_satz) : 0);
      return satz;
    });
    if (szene.saetze.length > 0) zeiger += bilder(e.nachlauf);
    const mindest = bilder(szene.dauer ?? (szene.art === 'schluss' ? e.schluss_dauer : 0));
    const frames = Math.max(zeiger - von, mindest, 1);
    const ergebnis = { ...szene, von, frames, saetze };
    von += frames;
    return ergebnis;
  });
  return { fps: e.fps, frames: von, sekunden: von / e.fps, szenen };
}

/** Verteilt die Untertitel-Teile eines Satzes nach Zeichenzahl auf seine Bilder. */
function verteile(teile, von, frames) {
  const laengen = teile.map((t) => t.join(' ').length);
  const summe = laengen.reduce((a, b) => a + b, 0);
  let bisher = 0;
  return teile.map((zeilenDesTeils, i) => {
    const start = von + Math.round((bisher / summe) * frames);
    bisher += laengen[i];
    const ende = von + Math.round((bisher / summe) * frames);
    return { zeilen: zeilenDesTeils, von: start, frames: Math.max(1, ende - start) };
  });
}
