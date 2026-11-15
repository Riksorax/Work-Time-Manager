// Prüfung der Videobeschreibung (videos/<sprache>/<id>.yaml). Reine Funktion: Dateizugriffe
// (gibt es das Bild?) kommen als Funktion von außen, damit die Tests ohne Dateien laufen.

export const ARTEN = ['aufhaenger', 'app', 'teaser', 'schluss'];

const KOPF = ['id', 'titel', 'musik', 'ausschnitte', 'szenen'];
const GEMEINSAM = ['art', 'saetze', 'dauer', 'untertitel'];
const FELDER = {
  aufhaenger: [...GEMEINSAM, 'text'],
  app: [...GEMEINSAM, 'bild', 'zoom', 'tipp', 'einblendung', 'premium'],
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
 * @param {{id?: string, bildVorhanden?: (name: string) => boolean}} [optionen]
 *   `id`: erwartete ID (Dateiname ohne Endung). `bildVorhanden`: prüft `frames/<sprache>/<name>`.
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
        const ort = `Ausschnitt „${name}“`;
        if (!istObjekt(r)) {
          fehler.push(`${ort}: erwartet x, y, breite, hoehe`);
          continue;
        }
        unbekannte(r, AUSSCHNITT, ort, fehler);
        const werte = AUSSCHNITT.map((f) => r[f]);
        if (!werte.every((w) => istZahl(w) && w >= 0 && w <= 1)) {
          fehler.push(`${ort}: x, y, breite, hoehe müssen Zahlen von 0 bis 1 sein (Anteil am Bild)`);
        } else if (r.breite === 0 || r.hoehe === 0 || r.x + r.breite > 1 + 1e-9 || r.y + r.hoehe > 1 + 1e-9) {
          fehler.push(`${ort}: Rechteck ist leer oder ragt über das Bild hinaus`);
        } else ausschnitte[name] = { x: r.x, y: r.y, breite: r.breite, hoehe: r.hoehe };
      }
    }
  }
  const ausschnittBekannt = (name, ort) => {
    if (!istText(name)) fehler.push(`${ort}: „auf“ fehlt (Name eines Ausschnitts)`);
    else if (istObjekt(daten.ausschnitte) && !(name in daten.ausschnitte)) {
      fehler.push(`${ort}: Ausschnitt „${name}“ ist unter „ausschnitte“ nicht beschrieben`);
    } else if (!istObjekt(daten.ausschnitte)) fehler.push(`${ort}: Ausschnitt „${name}“, aber „ausschnitte“ fehlt`);
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
      if (s.untertitel !== undefined && typeof s.untertitel !== 'boolean') fehler.push(`${o}: „untertitel“ muss true oder false sein`);

      // Auf Aufhänger- und Schlusskarte steht der Text schon groß im Bild.
      const szene = { art: s.art, saetze, untertitel: s.untertitel ?? (s.art === 'app' || s.art === 'teaser') };
      if (s.dauer !== undefined) szene.dauer = s.dauer;

      if (s.art === 'aufhaenger' || s.art === 'teaser') {
        if (!istText(s.text)) fehler.push(`${o}: „text“ fehlt`);
        else szene.text = s.text.trim();
      }
      if (s.art === 'app') {
        if (!istText(s.bild)) fehler.push(`${o}: „bild“ fehlt`);
        else {
          szene.bild = s.bild;
          if (!/^[\w.-]+\.png$/i.test(s.bild)) fehler.push(`${o}: „bild“ muss ein PNG-Dateiname ohne Ordner sein, nicht „${s.bild}“`);
          else if (optionen.bildVorhanden && !optionen.bildVorhanden(s.bild)) fehler.push(`${o}: Bild „${s.bild}“ fehlt`);
        }
        if (s.zoom !== undefined) {
          if (!istObjekt(s.zoom)) fehler.push(`${o}: „zoom“ erwartet auf (und optional faktor)`);
          else {
            unbekannte(s.zoom, ['auf', 'faktor'], `${o}, zoom`, fehler);
            ausschnittBekannt(s.zoom.auf, `${o}, zoom`);
            const faktor = s.zoom.faktor ?? 1.25;
            if (!(istZahl(faktor) && faktor >= 1 && faktor <= 2.5)) fehler.push(`${o}, zoom: „faktor“ muss zwischen 1 und 2.5 liegen`);
            szene.zoom = { auf: s.zoom.auf, faktor };
          }
        }
        if (s.tipp !== undefined) {
          if (!istObjekt(s.tipp)) fehler.push(`${o}: „tipp“ erwartet auf (und optional bei)`);
          else {
            unbekannte(s.tipp, ['auf', 'bei'], `${o}, tipp`, fehler);
            ausschnittBekannt(s.tipp.auf, `${o}, tipp`);
            const bei = s.tipp.bei ?? 0.5;
            if (!(istZahl(bei) && bei >= 0 && bei <= 1)) fehler.push(`${o}, tipp: „bei“ muss zwischen 0 und 1 liegen (Anteil der Szenendauer)`);
            szene.tipp = { auf: s.tipp.auf, bei };
          }
        }
        if (s.einblendung !== undefined) {
          if (!istText(s.einblendung)) fehler.push(`${o}: „einblendung“ muss Text sein`);
          else if (s.einblendung.trim().length > 44) fehler.push(`${o}: „einblendung“ ist länger als 44 Zeichen (zwei Zeilen)`);
          else szene.einblendung = s.einblendung.trim();
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
