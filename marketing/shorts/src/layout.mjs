// Maße der Bausteine für 1080 × 1920. Reine Funktionen, damit Lage und Zoom prüfbar sind.

// Schutzzonen: Dort liegen die Bedienelemente der Plattformen, kein wichtiger Text.
export const SCHUTZ_OBEN = 250;
export const SCHUTZ_UNTEN = 420;

export const KARTE = {
  breite: 842, // 78 % von 1080
  links: 119,
  oben: 270,
  obenMitEinblendung: 430, // Platz für die Texteinblendung über dem App-Bild
  unten: 1670,
  radius: 44,
};
export const UNTERTITEL = { unten: SCHUTZ_UNTEN, zeilenhoehe: 68, schrift: 50 };

/**
 * Lage des App-Bilds in der Karte: `fortschritt` 0 zeigt das Bild oben bündig in voller
 * Breite, 1 den Ausschnitt vergrößert in der Mitte des freien Bereichs über dem Untertitel.
 * Das Bild deckt die Karte immer ganz ab.
 *
 * @param {{breite: number, hoehe: number}} bild Pixelmaße des App-Bilds
 * @param {{x: number, y: number, breite: number, hoehe: number} | undefined} ausschnitt Anteile 0–1
 * @returns {{skala: number, x: number, y: number, bildHoehe: number}} Verschiebung in Pixeln der Karte
 */
export function bildLage(bild, ausschnitt, faktor, fortschritt, kartenHoehe, freiHoehe) {
  const bildHoehe = (KARTE.breite * bild.hoehe) / bild.breite;
  if (!ausschnitt) return { skala: 1, x: 0, y: 0, bildHoehe };
  const skala = 1 + (faktor - 1) * fortschritt;
  const mitteX = (ausschnitt.x + ausschnitt.breite / 2) * KARTE.breite;
  const mitteY = (ausschnitt.y + ausschnitt.hoehe / 2) * bildHoehe;
  const grenze = (wert, min) => Math.min(0, Math.max(min, wert));
  const zielX = grenze(KARTE.breite / 2 - mitteX * faktor, KARTE.breite - KARTE.breite * faktor);
  const zielY = grenze(freiHoehe / 2 - mitteY * faktor, Math.min(0, kartenHoehe - bildHoehe * faktor));
  // „+ 0“ macht aus −0 eine 0.
  return { skala, x: zielX * fortschritt + 0, y: zielY * fortschritt + 0, bildHoehe };
}
