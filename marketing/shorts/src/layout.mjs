// Maße der Bausteine für 1080 × 1920. Reine Funktionen, damit Lage und Zoom prüfbar sind.
// Alle Rückgaben sind Pixel auf der Leinwand, Rechtecke aus der Videobeschreibung Anteile 0–1.

export const BREITE = 1080;
export const HOEHE = 1920;

// Schutzzonen: Dort liegen die Bedienelemente der Plattformen, kein wichtiger Text.
export const SCHUTZ_OBEN = 250;
export const SCHUTZ_UNTEN = 420;
/** Freie Fläche zwischen den Schutzzonen. */
export const FREI = { oben: SCHUTZ_OBEN, unten: HOEHE - SCHUTZ_UNTEN };
/** Abstand, den ein angesteuerter Ausschnitt (Zoom) zur Schutzzone hält. */
export const RAND = 40;

// App-Karte: fast die ganze Leinwand. Ein Bild im Format 9:16 passt bei Skala 1 genau hinein
// (1000 × 1778); oben und unten ragt die Karte in die Schutzzonen.
export const KARTE = {
  breite: 1000,
  links: 40,
  oben: 102,
  obenMitEinblendung: 420, // Platz für die Texteinblendung über dem App-Bild
  unten: 1880,
  radius: 48,
};

/** Schild der Hervorhebung. */
export const SCHILD = { links: 70, breite: 940, innen: 44, zeile: 58, abstand: 36, wertBreite: 840, wertMax: 210 };

/** Höhe des App-Bilds bei Kartenbreite und Skala 1. */
export const bildHoehe = (bild) => (KARTE.breite * bild.hoehe) / bild.breite;

const grenze = (wert, min, max) => Math.min(max, Math.max(min, wert));

/**
 * Lage des App-Bilds auf der Leinwand: `x`/`y` der linken oberen Ecke, `skala` zur Kartenbreite.
 *
 * Ohne Ausschnitt steht das Bild in voller Breite oben bündig in der Karte. Mit Ausschnitt
 * wird es um `faktor` vergrößert und so gelegt, dass die Mitte des Ausschnitts in der Mitte
 * der freien Fläche steht, soweit das Bild die Karte dabei noch ausfüllt. Läge der Ausschnitt
 * danach in einer Schutzzone (z. B. ein Knopf am unteren Bildrand), wird das Bild weiter
 * geschoben; die Karte endet dann früher (`kartenRechteck`).
 *
 * @param {{breite: number, hoehe: number}} bild Pixelmaße des App-Bilds
 * @param {{x: number, y: number, breite: number, hoehe: number} | undefined} ausschnitt Anteile 0–1
 * @param {number} faktor
 * @param {number} [oben] Oberkante der Karte
 * @returns {{skala: number, x: number, y: number, oben: number}}
 */
export function kamera(bild, ausschnitt, faktor = 1, oben = KARTE.oben) {
  if (!ausschnitt) return { skala: 1, x: KARTE.links, y: oben, oben };
  const breite = KARTE.breite * faktor;
  const hoehe = bildHoehe(bild) * faktor;
  const mitteX = (ausschnitt.x + ausschnitt.breite / 2) * breite;
  const x = grenze(BREITE / 2 - mitteX, KARTE.links + KARTE.breite - breite, KARTE.links);

  const frei = { oben: Math.max(FREI.oben, oben), unten: FREI.unten };
  const mitteY = (ausschnitt.y + ausschnitt.hoehe / 2) * hoehe;
  let y = grenze((frei.oben + frei.unten) / 2 - mitteY, Math.min(oben, KARTE.unten - hoehe), oben);
  // Ausschnitt aus der Schutzzone holen.
  const von = y + ausschnitt.y * hoehe;
  const bis = von + ausschnitt.hoehe * hoehe;
  const innen = { oben: frei.oben + RAND, unten: frei.unten - RAND };
  if (bis - von > innen.unten - innen.oben) y += (innen.oben + innen.unten) / 2 - (von + bis) / 2;
  else if (bis > innen.unten) y -= bis - innen.unten;
  else if (von < innen.oben) y += innen.oben - von;
  // „+ 0“ macht aus −0 eine 0.
  return { skala: faktor, x: x + 0, y: y + 0, oben };
}

/** Lage des Bilds am Ende einer App-Szene (Ziel der Kamerafahrt). */
export function szenenKamera(szene, bild) {
  const oben = szene.einblendung ? KARTE.obenMitEinblendung : KARTE.oben;
  return kamera(bild, szene.zoom?.rechteck, szene.zoom?.faktor ?? 1, oben);
}

/** Zwischenlage zweier Kameras, `t` von 0 bis 1. */
export function mische(a, b, t) {
  const m = (feld) => a[feld] + (b[feld] - a[feld]) * t;
  return { skala: m('skala'), x: m('x'), y: m('y'), oben: m('oben') };
}

/** Sichtbare Karte: Schnitt aus Kartenrahmen und Bild. */
export function kartenRechteck(lage, bild) {
  const oben = Math.max(lage.oben, lage.y);
  const unten = Math.min(KARTE.unten, lage.y + bildHoehe(bild) * lage.skala);
  return { x: KARTE.links, y: oben, breite: KARTE.breite, hoehe: Math.max(0, unten - oben) };
}

/** Ein Ausschnitt des Bilds (Anteile) als Rechteck auf der Leinwand. */
export function aufLeinwand(lage, bild, ausschnitt) {
  const breite = KARTE.breite * lage.skala;
  const hoehe = bildHoehe(bild) * lage.skala;
  return { x: lage.x + ausschnitt.x * breite, y: lage.y + ausschnitt.y * hoehe, breite: ausschnitt.breite * breite, hoehe: ausschnitt.hoehe * hoehe };
}

/** Liegt das Rechteck (Leinwand) ganz außerhalb der Schutzzonen? */
export const istFrei = (r) => r.y >= FREI.oben - 1e-6 && r.y + r.hoehe <= FREI.unten + 1e-6;

/** Schriftgröße der großen Zahl: so groß, wie sie in das Schild passt (Open Sans Bold, grob 0,56 em je Zeichen). */
export const wertSchrift = (text) => Math.min(SCHILD.wertMax, Math.floor(SCHILD.wertBreite / (0.56 * Math.max(1, text.length))));

/** Höhe des Schilds: kleine Zeile, große Zahl, Innenabstand. */
export const schildHoehe = (wert) => Math.round(2 * SCHILD.innen + SCHILD.zeile * 1.25 + wertSchrift(wert) * 1.12);

/**
 * Lage des Schilds zu seiner Quelle (Rechteck des Ausschnitts auf der Leinwand): direkt
 * darunter, sonst darüber, immer zwischen den Schutzzonen. `spitzeX` ist die Stelle der Kante,
 * von der die Spitze auf die Quelle zeigt.
 */
export function schildLage(quelle, wert) {
  const hoehe = schildHoehe(wert);
  const spitzeX = grenze(quelle.x + quelle.breite / 2, SCHILD.links + 90, SCHILD.links + SCHILD.breite - 90);
  const basis = { x: SCHILD.links, breite: SCHILD.breite, hoehe, spitzeX };
  const darunter = quelle.y + quelle.hoehe + SCHILD.abstand;
  if (darunter + hoehe <= FREI.unten) return { ...basis, y: darunter, unter: true };
  const darueber = quelle.y - SCHILD.abstand - hoehe;
  if (darueber >= FREI.oben) return { ...basis, y: darueber, unter: false };
  // Kein Platz neben der Quelle: an den unteren Rand der freien Fläche, die Quelle wird verdeckt.
  return { ...basis, y: FREI.unten - hoehe, unter: true };
}
