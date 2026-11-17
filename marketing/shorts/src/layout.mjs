// Maße der Bausteine für 1080 × 1920. Reine Funktionen, damit Lage und Zoom prüfbar sind.
// Alle Rückgaben sind Pixel auf der Leinwand, Rechtecke aus der Videobeschreibung Anteile 0–1.

export const BREITE = 1080;
export const HOEHE = 1920;

// Schutzzonen: Dort liegen die Bedienelemente der Plattformen, kein wichtiger Inhalt.
export const SCHUTZ_OBEN = 250;
export const SCHUTZ_UNTEN = 420;
/** Freie Fläche zwischen den Schutzzonen. */
export const FREI = { oben: SCHUTZ_OBEN, unten: HOEHE - SCHUTZ_UNTEN };
/** Abstand von Platten (Aufhänger, Einblendung, Premium-Kennzeichen) zu den Schutzzonen. */
export const RAND = 30;

/** Dunkle Platte hinter Text, der über der App liegt (Aufhänger, Einblendung). */
export const PLATTE = { links: 50, breite: 980, radius: 40 };
/** Texteinblendung: Platte am oberen Rand der freien Fläche, zwei Zeilen. */
export const EINBLENDUNG = { oben: FREI.oben + RAND, hoehe: 200 };
/** Abstand zwischen Aufhänger-Platte und dem Ausschnitt, auf den die Kamera fährt. */
export const AUFHAENGER_ABSTAND = 60;
/** Abstand der Aufhänger-Platte zu den Schutzzonen. */
export const AUFHAENGER_RAND = 40;

/** Schild der Hervorhebung. */
export const SCHILD = { links: 70, breite: 940, innen: 44, zeile: 58, abstand: 36, wertBreite: 840, wertMax: 210 };

/**
 * Maße des App-Bilds bei Skala 1: Es deckt die Leinwand ganz (kein Rahmen, kein Hintergrund).
 * Ein Bild im Format 9:16 ist dann deckungsgleich mit der Leinwand, ein anderes Format steht
 * an zwei Seiten über.
 */
export function bildMass(bild) {
  const grund = Math.max(BREITE / bild.breite, HOEHE / bild.hoehe);
  return { breite: bild.breite * grund, hoehe: bild.hoehe * grund };
}

const grenze = (wert, min, max) => Math.min(max, Math.max(min, wert));

/**
 * Lage des App-Bilds auf der Leinwand: `x`/`y` der linken oberen Ecke, `skala` zur Größe aus
 * `bildMass`.
 *
 * Ohne Ausschnitt steht das Bild bei Skala 1 oben bündig, waagerecht mittig. Mit Ausschnitt
 * wird es um `faktor` vergrößert und so gelegt, dass die Mitte des Ausschnitts in der Mitte
 * der freien Fläche steht, aber nur so weit, wie das Bild die Leinwand dabei ganz deckt. Ein
 * Ausschnitt am Bildrand (Knopf ganz unten) bleibt deshalb in der Schutzzone; dafür braucht es
 * ein Bild, in dem er höher steht (Folge mit Wischgeste).
 *
 * @param {{breite: number, hoehe: number}} bild Pixelmaße des App-Bilds
 * @param {{x: number, y: number, breite: number, hoehe: number} | undefined} ausschnitt Anteile 0–1
 * @param {number} faktor
 * @param {number} [oben] Oberkante der Fläche, in deren Mitte der Ausschnitt kommt
 * @returns {{skala: number, x: number, y: number}}
 */
export function kamera(bild, ausschnitt, faktor = 1, oben = FREI.oben) {
  const mass = bildMass(bild);
  if (!ausschnitt) return { skala: 1, x: (BREITE - mass.breite) / 2 + 0, y: 0 };
  const breite = mass.breite * faktor;
  const hoehe = mass.hoehe * faktor;
  const mitteX = (ausschnitt.x + ausschnitt.breite / 2) * breite;
  const mitteY = (ausschnitt.y + ausschnitt.hoehe / 2) * hoehe;
  const x = grenze(BREITE / 2 - mitteX, BREITE - breite, 0);
  const y = grenze((oben + FREI.unten) / 2 - mitteY, HOEHE - hoehe, 0);
  // „+ 0“ macht aus −0 eine 0.
  return { skala: faktor, x: x + 0, y: y + 0 };
}

/** Lage des Bilds am Ende einer App-Szene (Ziel der Kamerafahrt). */
export function szenenKamera(szene, bild) {
  const oben = szene.einblendung ? EINBLENDUNG.oben + EINBLENDUNG.hoehe + RAND : FREI.oben;
  return kamera(bild, szene.zoom?.rechteck, szene.zoom?.faktor ?? 1, oben);
}

/** Zwischenlage zweier Kameras, `t` von 0 bis 1. Decken beide die Leinwand, deckt sie auch jede Zwischenlage. */
export function mische(a, b, t) {
  const m = (feld) => a[feld] + (b[feld] - a[feld]) * t;
  return { skala: m('skala'), x: m('x'), y: m('y') };
}

/** Deckt das Bild in dieser Lage die ganze Leinwand (kein Rand, kein Hintergrund)? */
export function deckt(lage, bild) {
  const mass = bildMass(bild);
  const genau = 1e-6;
  return lage.x <= genau && lage.y <= genau && lage.x + mass.breite * lage.skala >= BREITE - genau && lage.y + mass.hoehe * lage.skala >= HOEHE - genau;
}

/** Ein Ausschnitt des Bilds (Anteile) als Rechteck auf der Leinwand. */
export function aufLeinwand(lage, bild, ausschnitt) {
  const mass = bildMass(bild);
  const breite = mass.breite * lage.skala;
  const hoehe = mass.hoehe * lage.skala;
  return { x: lage.x + ausschnitt.x * breite, y: lage.y + ausschnitt.y * hoehe, breite: ausschnitt.breite * breite, hoehe: ausschnitt.hoehe * hoehe };
}

/** Liegt das Rechteck (Leinwand) ganz außerhalb der Schutzzonen? */
export const istFrei = (r) => r.y >= FREI.oben - 1e-6 && r.y + r.hoehe <= FREI.unten + 1e-6;

/** Überschneiden sich zwei Rechtecke (Leinwand) in der Höhe? */
export const ueberdecktY = (a, b) => a.y < b.y + b.hoehe - 1e-6 && b.y < a.y + a.hoehe - 1e-6;

/**
 * Fläche für die Platte des Aufhängers. Fährt die Kamera auf einen Ausschnitt (`ziel`, Rechteck
 * auf der Leinwand, z. B. der große Timer), bleibt er sichtbar: Die Platte sitzt im größeren
 * freien Teil daneben, an dessen vom Ausschnitt abgewandtem Ende (`anker`). Ohne Ausschnitt
 * steht sie mittig in der freien Fläche.
 *
 * @returns {{oben: number, unten: number, anker: 'oben' | 'mitte' | 'unten'}}
 */
export function aufhaengerFlaeche(ziel) {
  const oben = FREI.oben + AUFHAENGER_RAND;
  const unten = FREI.unten - AUFHAENGER_RAND;
  if (!ziel) return { oben, unten, anker: 'mitte' };
  const darunter = { oben: Math.max(oben, ziel.y + ziel.hoehe + AUFHAENGER_ABSTAND), unten, anker: 'unten' };
  const darueber = { oben, unten: Math.min(unten, ziel.y - AUFHAENGER_ABSTAND), anker: 'oben' };
  return darunter.unten - darunter.oben >= darueber.unten - darueber.oben ? darunter : darueber;
}

/** Schriftgröße des Aufhängers je nach Länge. */
export function aufhaengerSchrift(text) {
  // Feste Zeilen (Zeilenumbruch im Text): so groß, dass die längste Zeile in die Platte passt
  // (Open Sans Bold, grob 0,56 em je Zeichen), damit keine Zeile von selbst umbricht.
  if (text.includes('\n')) {
    const laengste = Math.max(...text.split('\n').map((zeile) => zeile.trim().length));
    return Math.min(120, Math.floor((PLATTE.breite - 100) / (0.56 * Math.max(1, laengste))));
  }
  return text.length <= 28 ? 120 : text.length <= 48 ? 104 : 86;
}

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
  if (darunter >= FREI.oben && darunter + hoehe <= FREI.unten) return { ...basis, y: darunter, unter: true };
  const darueber = quelle.y - SCHILD.abstand - hoehe;
  if (darueber >= FREI.oben && darueber + hoehe <= FREI.unten) return { ...basis, y: darueber, unter: false };
  // Kein Platz neben der Quelle: an den Rand der freien Fläche, der ihr näher liegt.
  const unten = quelle.y + quelle.hoehe / 2 >= (FREI.oben + FREI.unten) / 2;
  return { ...basis, y: unten ? FREI.unten - hoehe : FREI.oben, unter: !unten };
}
