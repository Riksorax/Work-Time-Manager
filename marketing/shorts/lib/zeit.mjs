// Zeitberechnung: Aus den Satzlängen (Ton) wird der Ablauf in Bildern. Reine Funktionen,
// keine Uhr, kein Datum.
import { BeschreibungsFehler, saetzeMitNummer } from './schema.mjs';

export const STANDARD = {
  fps: 30,
  vorlauf: 0.1,
  pause_nach_satz: 0.2,
  nachlauf: 0.1,
  schluss_nachlauf: 0.6,
  schluss_dauer: 2.5,
};

/**
 * Berechnet den Ablauf des Videos in Bildern.
 *
 * Je Szene: Vorlauf, dann die Sätze nacheinander mit Pause dazwischen, dann Nachlauf (auf der
 * Schlusskarte `schluss_nachlauf`). Eine Szene ohne Satz dauert `dauer` (Schlusskarte:
 * `schluss_dauer`); mit Sätzen ist `dauer` eine Mindestdauer. Jeder Satz beginnt auf einem
 * Bild, der Ton startet genau dort (`tonStart`).
 *
 * App-Szenen bekommen dazu (Bildnummern innerhalb der Szene, soweit nicht anders gesagt):
 * - `fortsetzung`: dieselbe Quelle wie die Szene davor, also kein Übergang und die Kamera
 *   fährt von dort weiter.
 * - `zoomBilder`: Länge der Kamerafahrt.
 * - `tippBild`: Zeitpunkt der Tipp-Markierung. Bei einer Folge ist das die Marke `tipp`.
 * - `folgeAb`, `folgeBis`, `halten` (Folge): gezeigt wird Bild `folgeAb` der Folge, nach
 *   `halten` Bildern läuft sie bis `folgeBis` und bleibt dort stehen. Ohne `ab` setzt die Szene
 *   dort fort, wo die Szene davor mit derselben Folge aufgehört hat.
 * - `aufhaengerBis`: Ende des Aufhängers über dem App-Bild (Ende des ersten Satzes).
 * - `hervorhebung.abBild`: Beginn der Hervorhebung.
 *
 * `plan.tipps` nennt die Zeitpunkte aller Tipps in Sekunden (für das Tipp-Geräusch).
 *
 * @param {ReturnType<import('./schema.mjs').pruefeBeschreibung>} beschreibung
 * @param {Map<string, {sekunden: number, datei?: string}>} dauern je Satznummer
 * @param {Partial<typeof STANDARD>} [einstellungen]
 */
export function berechneZeitplan(beschreibung, dauern, einstellungen = {}) {
  const e = { ...STANDARD, ...einstellungen };
  const bilder = (sekunden) => Math.round(sekunden * e.fps);
  const nummern = saetzeMitNummer(beschreibung);
  const fehler = [];
  const tipps = [];
  let von = 0;
  let laufend = 0;
  let davor;
  const szenen = beschreibung.szenen.map((szene, index) => {
    let zeiger = von + (szene.saetze.length > 0 ? bilder(e.vorlauf) : 0);
    const saetze = szene.saetze.map((text, i) => {
      const { nr } = nummern[laufend++];
      const dauer = dauern.get(nr);
      if (!dauer) throw new Error(`Satz ${nr} hat keine Länge (kein Ton)`);
      // Aufrunden: Der nächste Satz beginnt erst, wenn der Ton zu Ende ist.
      const frames = Math.max(1, Math.ceil(dauer.sekunden * e.fps - 1e-9));
      const satz = { nr, text, von: zeiger, frames, tonStart: zeiger / e.fps, sekunden: dauer.sekunden, datei: dauer.datei };
      zeiger += frames + (i < szene.saetze.length - 1 ? bilder(e.pause_nach_satz) : 0);
      return satz;
    });
    if (szene.saetze.length > 0) zeiger += bilder(szene.art === 'schluss' ? e.schluss_nachlauf : e.nachlauf);
    const mindest = bilder(szene.dauer ?? (szene.art === 'schluss' ? e.schluss_dauer : 0));
    const frames = Math.max(zeiger - von, mindest, 1);
    const ergebnis = { ...szene, von, frames, saetze };

    if (szene.art === 'app') {
      const ort = `Szene ${index + 1} (app)`;
      ergebnis.fortsetzung = davor?.art === 'app' && davor.quelle === szene.quelle;
      ergebnis.zoomBilder = Math.max(1, Math.min(frames, bilder(szene.zoom?.dauer ?? 0.6)));
      if (szene.aufhaenger) ergebnis.aufhaengerBis = saetze.length > 0 ? saetze[0].von + saetze[0].frames - von : frames;
      if (szene.hervorhebung) ergebnis.hervorhebung = { ...szene.hervorhebung, abBild: Math.round(szene.hervorhebung.bei * frames) };
      if (szene.folge) {
        const ab = szene.ab ?? (ergebnis.fortsetzung && davor.folgeEnde !== undefined ? Math.min(davor.folgeEnde, szene.bis) : 0);
        let halten = 0;
        if (szene.tipp) {
          const frueh = szene.tippMarke - ab;
          if (frueh < 0) fehler.push(`${ort}: Die Marke „tipp“ (Bild ${szene.tippMarke}) liegt vor dem gezeigten Abschnitt (ab Bild ${ab})`);
          else {
            if (szene.tipp.bei !== undefined) halten = Math.max(0, Math.round(szene.tipp.bei * frames) - frueh);
            ergebnis.tippBild = frueh + halten;
            if (ergebnis.tippBild >= frames || szene.tippMarke > szene.bis) fehler.push(`${ort}: Die Marke „tipp“ wird in der Szene nicht erreicht (Szene zu kurz oder „bis“ zu früh)`);
          }
        }
        ergebnis.folgeAb = ab;
        ergebnis.folgeBis = Math.max(ab, szene.bis);
        ergebnis.halten = halten;
        // Bild der Folge am Ende der Szene: dort setzt die nächste Szene fort.
        ergebnis.folgeEnde = Math.min(ergebnis.folgeBis, ab + Math.max(0, frames - halten));
      } else if (szene.tipp) ergebnis.tippBild = Math.min(frames - 1, Math.round(szene.tipp.bei * frames));
      if (ergebnis.tippBild !== undefined) tipps.push((von + ergebnis.tippBild) / e.fps);
    }
    von += frames;
    davor = ergebnis;
    return ergebnis;
  });
  if (fehler.length > 0) throw new BeschreibungsFehler(fehler);
  return { fps: e.fps, frames: von, sekunden: von / e.fps, szenen, tipps };
}

/** Bild der Folge, das eine Szene bei ihrem Bild `bild` zeigt. */
export function folgeBild(szene, bild) {
  return Math.min(szene.folgeBis, szene.folgeAb + Math.max(0, bild - szene.halten));
}
