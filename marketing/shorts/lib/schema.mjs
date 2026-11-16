// Prüfung der Videobeschreibung (videos/<sprache>/<id>.yaml). Reine Funktion: Dateizugriffe
// (gibt es das Bild?) kommen als Funktion von außen, damit die Tests ohne Dateien laufen.

export const ARTEN = ['aufhaenger', 'app', 'teaser', 'schluss'];

const KOPF = ['id', 'titel', 'musik', 'ausschnitte', 'szenen'];
const GEMEINSAM = ['art', 'saetze', 'dauer'];
const FELDER = {
  aufhaenger: [...GEMEINSAM, 'text'],
  app: [...GEMEINSAM, 'bild', 'folge', 'ab', 'bis', 'zoom', 'tipp', 'einblendung', 'premium', 'aufhaenger', 'hervorhebung'],
  teaser: [...GEMEINSAM, 'text'],
  schluss: [...GEMEINSAM],
};
const AUSSCHNITT = ['x', 'y', 'breite', 'hoehe'];

export class BeschreibungsFehler extends Error {
  /** @param {string[]} meldungen */
  constructor(meldungen) {
    super(`Videobeschreibung ungültig:\n${meldungen.map((m) => `  - ${m}`).join('\n')}`);
    this.name = 'BeschreibungsFehler';
    this.meldungen = meldungen;
  }
}

const istObjekt = (w) => w !== null && typeof w === 'object' && !Array.isArray(w);
const istText = (w) => typeof w === 'string' && w.trim() !== '';
const istZahl = (w) => typeof w === 'number' && Number.isFinite(w);

/** Prüft ein Rechteck mit Anteilen 0–1; gibt die bereinigte Fassung oder `undefined` zurück. */
function rechteck(r, ort, fehler) {
  if (!istObjekt(r)) {
    fehler.push(`${ort}: erwartet x, y, breite, hoehe`);
    return undefined;
  }
  unbekannte(r, AUSSCHNITT, ort, fehler);
  const werte = AUSSCHNITT.map((f) => r[f]);
  if (!werte.every((w) => istZahl(w) && w >= 0 && w <= 1)) {
    fehler.push(`${ort}: x, y, breite, hoehe müssen Zahlen von 0 bis 1 sein (Anteil am Bild)`);
  } else if (r.breite === 0 || r.hoehe === 0 || r.x + r.breite > 1 + 1e-9 || r.y + r.hoehe > 1 + 1e-9) {
    fehler.push(`${ort}: Rechteck ist leer oder ragt über das Bild hinaus`);
  } else return { x: r.x, y: r.y, breite: r.breite, hoehe: r.hoehe };
  return undefined;
}

/**
 * Prüft die Begleitdatei einer Bildfolge (`frames/<sprache>/<name>.json`).
 * @returns {{bilder: number, marken: Record<string, number>, ausschnitte: Record<string, object>} | undefined}
 */
export function pruefeFolge(name, daten, fps, fehler) {
  const ort = `Folge „${name}“`;
  if (!istObjekt(daten)) {
    fehler.push(`${ort}: ${name}.mp4 oder ${name}.json fehlt oder ist nicht lesbar`);
    return undefined;
  }
  const vorher = fehler.length;
  if (!(Number.isInteger(daten.bilder) && daten.bilder >= 1)) fehler.push(`${ort}: „bilder“ muss eine ganze Zahl ab 1 sein`);
  if (fps !== undefined && daten.fps !== fps) fehler.push(`${ort}: „fps“ ist ${daten.fps}, das Video läuft mit ${fps}`);
  const marken = {};
  if (daten.marken !== undefined && !istObjekt(daten.marken)) fehler.push(`${ort}: „marken“ muss eine Zuordnung Name → Bildnummer sein`);
  else {
    for (const [marke, bild] of Object.entries(daten.marken ?? {})) {
      if (!(Number.isInteger(bild) && bild >= 0 && bild < daten.bilder)) fehler.push(`${ort}: Marke „${marke}“ muss eine Bildnummer von 0 bis ${daten.bilder - 1} sein`);
      else marken[marke] = bild;
    }
  }
  const ausschnitte = {};
  if (daten.ausschnitte !== undefined && !istObjekt(daten.ausschnitte)) fehler.push(`${ort}: „ausschnitte“ muss eine Zuordnung Name → Rechteck sein`);
  else {
    for (const [n, r] of Object.entries(daten.ausschnitte ?? {})) {
      const geprueft = rechteck(r, `${ort}, Ausschnitt „${n}“`, fehler);
      if (geprueft) ausschnitte[n] = geprueft;
    }
  }
  return fehler.length > vorher ? undefined : { bilder: daten.bilder, marken, ausschnitte };
}

function unbekannte(objekt, erlaubt, ort, fehler) {
  for (const feld of Object.keys(objekt)) {
    if (!erlaubt.includes(feld)) {
      fehler.push(`${ort}: unbekanntes Feld „${feld}“ (erlaubt: ${erlaubt.join(', ')})`);
    }
  }
}

/**
 * Prüft die eingelesene YAML-Struktur und gibt sie mit gesetzten Standardwerten zurück.
 * Wirft `BeschreibungsFehler` mit allen gefundenen Fehlern.
 *
 * @param {unknown} daten
 * App-Szenen bekommen `quelle` (Dateiname von Bild oder Folge); `zoom`, `tipp` und
 * `hervorhebung` tragen das aufgelöste `rechteck`, `ab`/`bis` und `tippMarke` sind Bildnummern.
 *
 * @param {{id?: string, bildVorhanden?: (name: string) => boolean, folge?: (name: string) => unknown, fps?: number}} [optionen]
 *   `id`: erwartete ID (Dateiname ohne Endung). `bildVorhanden`: prüft `frames/<sprache>/<name>`.
 *   `folge`: liefert den Inhalt von `frames/<sprache>/<name>.json` (oder `undefined`, wenn JSON
 *   oder MP4 fehlen). `fps`: Bildrate des Videos, die Folge muss dieselbe haben.
 */
export function pruefeBeschreibung(daten, optionen = {}) {
  const fehler = [];
  if (!istObjekt(daten)) throw new BeschreibungsFehler(['Die Datei enthält keine YAML-Zuordnung']);
  unbekannte(daten, KOPF, 'Kopf', fehler);

  if (!istText(daten.id)) fehler.push('Kopf: „id“ fehlt');
  else if (!/^[a-z0-9][a-z0-9-]*$/.test(daten.id)) fehler.push(`Kopf: „id“ nur aus a–z, 0–9 und „-“, nicht „${daten.id}“`);
  else if (optionen.id !== undefined && daten.id !== optionen.id) {
    fehler.push(`Kopf: „id“ ist „${daten.id}“, die Datei heißt aber „${optionen.id}.yaml“`);
  }
  if (daten.titel !== undefined && !istText(daten.titel)) fehler.push('Kopf: „titel“ muss Text sein');
  if (daten.musik !== undefined && !istText(daten.musik)) fehler.push('Kopf: „musik“ muss ein Dateiname sein');

  const ausschnitte = {};
  if (daten.ausschnitte !== undefined) {
    if (!istObjekt(daten.ausschnitte)) fehler.push('„ausschnitte“ muss eine Zuordnung Name → Rechteck sein');
    else {
      for (const [name, r] of Object.entries(daten.ausschnitte)) {
        const geprueft = rechteck(r, `Ausschnitt „${name}“`, fehler);
        if (geprueft) ausschnitte[name] = geprueft;
      }
    }
  }
  const folgen = new Map();
  const ladeFolge = (name) => {
    if (!folgen.has(name)) folgen.set(name, pruefeFolge(name, optionen.folge ? optionen.folge(name) : undefined, optionen.fps, fehler));
    return folgen.get(name);
  };
  /** Rechteck zum Namen: erst aus der Videobeschreibung, dann aus der Folge der Szene. */
  const ausschnittVon = (name, folge, ort) => {
    if (!istText(name)) fehler.push(`${ort}: „auf“ fehlt (Name eines Ausschnitts)`);
    else if (istObjekt(daten.ausschnitte) && name in daten.ausschnitte) return ausschnitte[name];
    else if (folge?.ausschnitte[name]) return folge.ausschnitte[name];
    else fehler.push(`${ort}: Ausschnitt „${name}“ ist weder unter „ausschnitte“ noch in der Folge beschrieben`);
    return undefined;
  };
  const anteil = (wert, ort, feld) => {
    if (!(istZahl(wert) && wert >= 0 && wert <= 1)) fehler.push(`${ort}: „${feld}“ muss zwischen 0 und 1 liegen (Anteil der Szenendauer)`);
  };

  const szenen = [];
  if (!Array.isArray(daten.szenen) || daten.szenen.length === 0) fehler.push('„szenen“ fehlt oder ist leer');
  else {
    daten.szenen.forEach((s, i) => {
      const ort = `Szene ${i + 1}`;
      if (!istObjekt(s)) return fehler.push(`${ort}: keine Zuordnung`);
      if (!ARTEN.includes(s.art)) return fehler.push(`${ort}: „art“ fehlt oder ist unbekannt (erlaubt: ${ARTEN.join(', ')})`);
      const o = `${ort} (${s.art})`;
      unbekannte(s, FELDER[s.art], o, fehler);

      let saetze = [];
      if (s.saetze !== undefined) {
        if (!Array.isArray(s.saetze)) fehler.push(`${o}: „saetze“ muss eine Liste sein`);
        else {
          s.saetze.forEach((satz, j) => {
            if (!istText(satz)) fehler.push(`${o}: Satz ${j + 1} ist leer oder kein Text`);
          });
          saetze = s.saetze.filter(istText).map((satz) => satz.trim());
        }
      }
      if (s.dauer !== undefined && !(istZahl(s.dauer) && s.dauer > 0)) fehler.push(`${o}: „dauer“ muss eine Zahl größer 0 sein (Sekunden)`);
      if (saetze.length === 0 && s.dauer === undefined && s.art !== 'schluss') {
        fehler.push(`${o}: braucht „saetze“ oder „dauer“`);
      }

      const szene = { art: s.art, saetze };
      if (s.dauer !== undefined) szene.dauer = s.dauer;

      if (s.art === 'aufhaenger' || s.art === 'teaser') {
        if (!istText(s.text)) fehler.push(`${o}: „text“ fehlt`);
        else szene.text = s.text.trim();
      }
      if (s.art === 'app') {
        let folge;
        if ((s.bild === undefined) === (s.folge === undefined)) fehler.push(`${o}: braucht genau eines von „bild“ und „folge“`);
        else if (s.bild !== undefined) {
          if (!istText(s.bild)) fehler.push(`${o}: „bild“ fehlt`);
          else {
            szene.bild = s.bild;
            szene.quelle = s.bild;
            if (!/^[\w.-]+\.png$/i.test(s.bild)) fehler.push(`${o}: „bild“ muss ein PNG-Dateiname ohne Ordner sein, nicht „${s.bild}“`);
            else if (optionen.bildVorhanden && !optionen.bildVorhanden(s.bild)) fehler.push(`${o}: Bild „${s.bild}“ fehlt`);
          }
          for (const feld of ['ab', 'bis']) if (s[feld] !== undefined) fehler.push(`${o}: „${feld}“ gibt es nur mit „folge“`);
        } else if (!istText(s.folge) || !/^[\w-]+$/.test(s.folge)) fehler.push(`${o}: „folge“ muss ein Name ohne Ordner und Endung sein`);
        else {
          szene.folge = s.folge;
          szene.quelle = `${s.folge}.mp4`;
          folge = ladeFolge(s.folge);
          if (folge) {
            const bildnummer = (wert, feld) => {
              const nr = typeof wert === 'string' ? folge.marken[wert] : wert;
              if (typeof wert === 'string' && nr === undefined) fehler.push(`${o}: „${feld}“: Marke „${wert}“ kennt die Folge nicht`);
              else if (!(Number.isInteger(nr) && nr >= 0 && nr < folge.bilder)) fehler.push(`${o}: „${feld}“ muss eine Bildnummer von 0 bis ${folge.bilder - 1} oder eine Marke sein`);
              else return nr;
              return undefined;
            };
            if (s.ab !== undefined) szene.ab = bildnummer(s.ab, 'ab');
            szene.bis = s.bis !== undefined ? bildnummer(s.bis, 'bis') : folge.bilder - 1;
            if (szene.ab !== undefined && szene.bis !== undefined && szene.bis < szene.ab) fehler.push(`${o}: „bis“ liegt vor „ab“`);
          }
        }
        const folgeGeladen = s.folge === undefined || folge !== undefined;
        if (s.zoom !== undefined) {
          if (!istObjekt(s.zoom)) fehler.push(`${o}: „zoom“ erwartet auf (und optional faktor, dauer)`);
          else {
            unbekannte(s.zoom, ['auf', 'faktor', 'dauer'], `${o}, zoom`, fehler);
            const r = folgeGeladen ? ausschnittVon(s.zoom.auf, folge, `${o}, zoom`) : undefined;
            const faktor = s.zoom.faktor ?? 1.25;
            if (!(istZahl(faktor) && faktor >= 1 && faktor <= 2.5)) fehler.push(`${o}, zoom: „faktor“ muss zwischen 1 und 2.5 liegen`);
            const dauer = s.zoom.dauer ?? 0.6;
            if (!(istZahl(dauer) && dauer > 0)) fehler.push(`${o}, zoom: „dauer“ muss eine Zahl größer 0 sein (Sekunden der Kamerafahrt)`);
            szene.zoom = { auf: s.zoom.auf, faktor, dauer, rechteck: r };
          }
        }
        if (s.tipp !== undefined) {
          if (!istObjekt(s.tipp)) fehler.push(`${o}: „tipp“ erwartet auf (und optional bei)`);
          else {
            unbekannte(s.tipp, ['auf', 'bei'], `${o}, tipp`, fehler);
            const r = folgeGeladen ? ausschnittVon(s.tipp.auf, folge, `${o}, tipp`) : undefined;
            szene.tipp = { auf: s.tipp.auf, rechteck: r };
            // Bei einer Folge bestimmt die Marke „tipp“ den Zeitpunkt; „bei“ hält nur das erste Bild an.
            const bei = s.tipp.bei ?? (s.folge === undefined ? 0.5 : undefined);
            if (bei !== undefined) {
              anteil(bei, `${o}, tipp`, 'bei');
              szene.tipp.bei = bei;
            }
            if (folge) {
              if (folge.marken.tipp === undefined) fehler.push(`${o}, tipp: Der Folge „${s.folge}“ fehlt die Marke „tipp“`);
              else szene.tippMarke = folge.marken.tipp;
            }
          }
        }
        if (s.einblendung !== undefined) {
          if (!istText(s.einblendung)) fehler.push(`${o}: „einblendung“ muss Text sein`);
          else if (s.einblendung.trim().length > 44) fehler.push(`${o}: „einblendung“ ist länger als 44 Zeichen (zwei Zeilen)`);
          else szene.einblendung = s.einblendung.trim();
        }
        if (s.aufhaenger !== undefined) {
          if (!istText(s.aufhaenger)) fehler.push(`${o}: „aufhaenger“ muss Text sein`);
          else if (s.aufhaenger.trim().length > 60) fehler.push(`${o}: „aufhaenger“ ist länger als 60 Zeichen`);
          else szene.aufhaenger = s.aufhaenger.trim();
          if (s.einblendung !== undefined) fehler.push(`${o}: „aufhaenger“ und „einblendung“ schließen sich aus`);
        }
        if (s.hervorhebung !== undefined) {
          const h = s.hervorhebung;
          if (!istObjekt(h)) fehler.push(`${o}: „hervorhebung“ erwartet auf, wert (und optional zeile, bei)`);
          else {
            const oh = `${o}, hervorhebung`;
            unbekannte(h, ['auf', 'zeile', 'wert', 'bei'], oh, fehler);
            const r = folgeGeladen ? ausschnittVon(h.auf, folge, oh) : undefined;
            if (!istText(h.wert)) fehler.push(`${oh}: „wert“ fehlt (die große Zahl, als Text in Anführungszeichen)`);
            else if (h.wert.trim().length > 12) fehler.push(`${oh}: „wert“ ist länger als 12 Zeichen`);
            if (h.zeile !== undefined && !istText(h.zeile)) fehler.push(`${oh}: „zeile“ muss Text sein`);
            else if (istText(h.zeile) && h.zeile.trim().length > 28) fehler.push(`${oh}: „zeile“ ist länger als 28 Zeichen`);
            const bei = h.bei ?? 0.2;
            anteil(bei, oh, 'bei');
            szene.hervorhebung = { auf: h.auf, rechteck: r, wert: istText(h.wert) ? h.wert.trim() : '', bei };
            if (istText(h.zeile)) szene.hervorhebung.zeile = h.zeile.trim();
          }
        }
        if (s.premium !== undefined && typeof s.premium !== 'boolean') fehler.push(`${o}: „premium“ muss true oder false sein`);
        szene.premium = s.premium === true;
      }
      szenen.push(szene);
    });
  }

  if (fehler.length > 0) throw new BeschreibungsFehler(fehler);
  const ergebnis = { id: daten.id, ausschnitte, szenen };
  if (daten.titel !== undefined) ergebnis.titel = daten.titel;
  if (daten.musik !== undefined) ergebnis.musik = daten.musik;
  return ergebnis;
}

/** Alle Sätze in Sprechreihenfolge mit laufender Nummer („01“, „02“ …), wie `tts/synth.py` sie vergibt. */
export function saetzeMitNummer(beschreibung) {
  const liste = [];
  beschreibung.szenen.forEach((szene, szenenIndex) => {
    for (const text of szene.saetze) {
      liste.push({ nr: String(liste.length + 1).padStart(2, '0'), szene: szenenIndex, text });
    }
  });
  return liste;
}

/**
 * Prüft `dauer.json` aus der Synthese gegen die Beschreibung: Jeder Satz braucht einen Eintrag
 * mit demselben Text und einer Länge größer 0.
 * @returns {Map<string, {sekunden: number, datei: string}>} je Satznummer
 */
export function pruefeDauern(beschreibung, dauerJson, tonVorhanden = () => true) {
  const fehler = [];
  const eintraege = new Map((dauerJson?.saetze ?? []).map((e) => [e.nr, e]));
  const ergebnis = new Map();
  for (const satz of saetzeMitNummer(beschreibung)) {
    const e = eintraege.get(satz.nr);
    const ort = `Satz ${satz.nr} („${satz.text.slice(0, 40)}${satz.text.length > 40 ? '…' : ''}“)`;
    if (!e) fehler.push(`${ort}: kein Ton (fehlt in dauer.json)`);
    else if (e.text !== satz.text) fehler.push(`${ort}: Ton gehört zu anderem Text („${String(e.text).slice(0, 40)}“), Synthese neu starten`);
    else if (!(istZahl(e.sekunden) && e.sekunden > 0)) fehler.push(`${ort}: Ton hat keine Länge`);
    else if (!istText(e.datei) || !tonVorhanden(e.datei)) fehler.push(`${ort}: Tondatei „${e.datei}“ fehlt`);
    else ergebnis.set(satz.nr, { sekunden: e.sekunden, datei: e.datei });
  }
  if (fehler.length > 0) throw new BeschreibungsFehler(fehler);
  return ergebnis;
}
