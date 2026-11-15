/**
 * Reine Hilfen für die SVG-Diagramme (#531): Skalierung, Achsenbeschriftung, Ausdünnen der Beschriftungen.
 * Keine Fachlogik: die Werte kommen fertig gerechnet vom Backend, hier wird nur gezeichnet.
 */

const MINUTE = 60_000;
const HOUR = 60 * MINUTE;

/** Ein Wert des Diagramms (ein Zeitraum). Dauern in Millisekunden. */
export interface ChartPoint {
  /** Stabiler Schlüssel (z. B. `2026-W45`). */
  key: string;
  /** Kurze Achsenbeschriftung (z. B. „KW 45“, „Nov.“). */
  axisLabel: string;
  /** Volle Bezeichnung für Detailzeile, Tabelle und Screenreader (z. B. „KW 45 · 2.–8. Nov. 2026“). */
  label: string;
  /** Hauptwert (Balken bzw. Linienpunkt). */
  value: number;
  /** Vergleichswert, im Balkendiagramm das Soll (als Marke gezeichnet). */
  reference?: number;
  /** Zusatzwert nur für Detailzeile und Tabelle (Liniendiagramm: Überstunden des einzelnen Zeitraums). */
  secondary?: number;
  /** `false`: keine Einträge im Zeitraum, wird als Lücke gezeichnet. */
  hasData: boolean;
  /** Laufender, noch unvollständiger Zeitraum. */
  partial: boolean;
}

/** Beschriftungen eines Diagramms (übersetzt von der aufrufenden Komponente). */
export interface ChartLabels {
  /** Name des Diagramms: `aria-label` des SVG und Überschrift der Textalternative. */
  title: string;
  /** Spaltenkopf der Zeiträume in der Tabelle. */
  period: string;
  value: string;
  reference?: string;
  secondary?: string;
  /** Text für Zeiträume ohne Einträge. */
  noData: string;
  /** Legende/Zusatz für den laufenden Zeitraum. */
  partial: string;
}

export interface LinearScale {
  min: number;
  max: number;
  step: number;
  ticks: number[];
}

/** Teilstriche je Achse: mindestens 4, höchstens 6 (also 3 bis 5 Abstände). */
const MIN_INTERVALS = 3;
const MAX_INTERVALS = 5;

/**
 * „Schöne“ Schrittweiten der Achse, aufsteigend: unter einer Stunde 5, 10, 15 und 30 Minuten (ganze Minuten), ab einer
 * Stunde 1, 2, 2,5, 5 und 10 × 10ⁿ Stunden.
 */
function* candidateSteps(): Generator<number> {
  for (const minutes of [5, 10, 15, 30]) yield minutes * MINUTE;
  for (let mag = 1; mag < 1e12; mag *= 10) {
    for (const m of [1, 2, 2.5, 5]) yield m * mag * HOUR;
  }
}

/**
 * Lineare Skala mit „runden“ Teilstrichen, die 0 immer enthält (Balken und Nulllinie). Gewählt wird die kleinste
 * schöne Schrittweite, mit der höchstens 5 Abstände (6 Teilstriche) reichen: so liegen Ober- und Untergrenze nah am
 * größten bzw. kleinsten Wert (z. B. 44 h mit Soll 40 h → 0 bis 50 h). Bei sehr kleinen Werten wird auf mindestens
 * 3 Abstände (4 Teilstriche) aufgefüllt. Robust für leere Listen, nur Nullen (dann 0 bis 1 h), nur negative Werte,
 * sehr große Werte und nicht endliche Werte (zählen als 0).
 */
export function niceScale(values: readonly number[]): LinearScale {
  const finite = values.map(v => (Number.isFinite(v) ? v : 0));
  const lo = Math.min(0, ...finite) + 0;
  let hi = Math.max(0, ...finite) + 0;
  if (hi === lo) hi = HOUR;
  let step = HOUR;
  let min = 0;
  let max = HOUR;
  for (const candidate of candidateSteps()) {
    step = candidate;
    min = Math.floor(lo / step) * step;
    max = Math.ceil(hi / step) * step;
    if (Math.round((max - min) / step) <= MAX_INTERVALS) break;
  }
  // Nur bei Werten unter der kleinsten Schrittweite: auf der Seite der Werte auffüllen (0 bleibt Grenze).
  const missing = MIN_INTERVALS - Math.round((max - min) / step);
  if (missing > 0) {
    if (max > 0 || min === 0) max += missing * step;
    else min -= missing * step;
  }
  min += 0;
  max += 0;
  const ticks: number[] = [];
  for (let t = min; t <= max + step / 2; t += step) ticks.push(Math.round(t) + 0);
  return { min, max, step, ticks };
}

/** Achsenbeschriftung in Stunden: „40 h“, „0:30 h“; mit `signed` „+10 h“ / „-5 h“ (0 ohne Vorzeichen). */
export function formatAxisHours(ms: number, signed = false): string {
  const sign = ms > 0 ? (signed ? '+' : '') : ms < 0 ? '-' : '';
  const abs = Math.abs(ms);
  if (abs % HOUR === 0) return `${sign}${abs / HOUR} h`;
  const h = Math.floor(abs / HOUR);
  const m = Math.round((abs % HOUR) / MINUTE);
  return `${sign}${h}:${String(m).padStart(2, '0')} h`;
}

/**
 * Jede wievielte Achsenbeschriftung gezeigt wird, damit sich die Beschriftungen bei schmaler Breite nicht
 * überlappen (1 = alle). Gezeigt werden die Indizes `i` mit `(count - 1 - i) % step === 0`, also immer der letzte
 * (laufende) Zeitraum.
 */
export function axisLabelStep(count: number, plotWidth: number, labelWidth: number): number {
  if (count <= 1 || plotWidth <= 0) return 1;
  const slot = plotWidth / count;
  return Math.max(1, Math.ceil(labelWidth / slot));
}

/** Geschätzte Breite einer Beschriftung in px (Systemschrift, ~0,6 em je Zeichen). */
export function estimateTextWidth(text: string, fontSizePx: number): number {
  return Math.ceil(text.length * fontSizePx * 0.6);
}
