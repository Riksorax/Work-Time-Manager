import { axisLabelStep, estimateTextWidth, formatAxisHours, niceScale } from './chart-scale.util';
import { formatDurationHm, formatSignedDurationHm } from './duration-format.util';

const H = 3_600_000;
const M = 60_000;

describe('niceScale (#531)', () => {
  /** Gemeinsame Eigenschaften jeder Skala: 4 bis 6 Teilstriche, 0 enthalten, gleichmäßige Schritte, Werte abgedeckt. */
  function expectWellFormed(values: number[]): ReturnType<typeof niceScale> {
    const s = niceScale(values);
    expect(s.ticks.length).toBeGreaterThanOrEqual(4);
    expect(s.ticks.length).toBeLessThanOrEqual(6);
    expect(s.ticks).toContain(0);
    expect(s.ticks[0]).toBe(s.min);
    expect(s.ticks.at(-1)).toBe(s.max);
    for (let i = 1; i < s.ticks.length; i++) expect(s.ticks[i] - s.ticks[i - 1]).toBe(s.step);
    expect(s.ticks.every(Number.isFinite)).toBe(true);
    const finite = values.filter(Number.isFinite);
    if (finite.length) {
      expect(s.max).toBeGreaterThanOrEqual(Math.max(...finite));
      expect(s.min).toBeLessThanOrEqual(Math.min(...finite));
    }
    return s;
  }

  it('leere Liste und nur Nullen: 0 bis 1 h in Viertelstunden, kein NaN', () => {
    for (const values of [[], [0, 0, 0]]) {
      const s = expectWellFormed(values);
      expect(s.min).toBe(0);
      expect(s.max).toBe(H);
      expect(s.step).toBe(15 * M);
    }
  });

  it('max 44 h mit Soll 40 h: Obergrenze 50 h in 10-h-Schritten (vorher 60 h)', () => {
    const s = expectWellFormed([38.5 * H, 40 * H, 44 * H, 40 * H, 22 * H, 24 * H]);
    expect(s.min).toBe(0);
    expect(s.max).toBe(50 * H);
    expect(s.step).toBe(10 * H);
    expect(s.ticks).toEqual([0, 10, 20, 30, 40, 50].map(h => h * H));
  });

  it('typische Woche bis 41,5 h: Obergrenze 50 h', () => {
    const s = expectWellFormed([38 * H, 40 * H, 41.5 * H]);
    expect(s.max).toBe(50 * H);
  });

  it('Monate um 170 h: Obergrenze 200 h statt 400 h', () => {
    const s = expectWellFormed([168 * H, 152 * H, 175 * H, 86 * H]);
    expect(s.max).toBe(200 * H);
    expect(s.step).toBe(50 * H);
  });

  it('Schritt 2,5 h, wenn er die Obergrenze näher an den Wert bringt', () => {
    const s = expectWellFormed([11 * H]);
    expect(s.step).toBe(2.5 * H);
    expect(s.max).toBe(12.5 * H);
  });

  it('nur negative Werte: Maximum ist 0, Minimum nah am kleinsten Wert', () => {
    const s = expectWellFormed([-3 * H, -12 * H, -0.5 * H]);
    expect(s.max).toBe(0);
    expect(s.min).toBe(-12.5 * H);
    expect(s.step).toBe(2.5 * H);
  });

  it('positive und negative Werte: beide Seiten, 0 als Teilstrich', () => {
    const s = expectWellFormed([-7 * H, 13 * H]);
    expect(s.min).toBe(-10 * H);
    expect(s.max).toBe(15 * H);
    expect(s.step).toBe(5 * H);
  });

  it('Überstunden-Linie zwischen -1,5 h und +5 h: -2 h bis +6 h', () => {
    const s = expectWellFormed([-1.5 * H, -0.5 * H, 2 * H, 5 * H, 2.5 * H]);
    expect(s.min).toBe(-2 * H);
    expect(s.max).toBe(6 * H);
  });

  it('sehr große Werte und ein einzelner Ausreißer: endlich, runde Schritte', () => {
    const s = expectWellFormed([40 * H, 38 * H, 2_000_000 * H]);
    expect(s.max).toBe(2_000_000 * H);
    expect(s.step).toBe(500_000 * H);
  });

  it('kleine Werte unter 2 h: halbe bzw. Viertelstunden, Obergrenze nah am Wert', () => {
    expect(expectWellFormed([1.5 * H]).max).toBe(1.5 * H);
    expect(expectWellFormed([1.5 * H]).step).toBe(30 * M);
    expect(expectWellFormed([20 * M]).max).toBe(20 * M);
    expect(expectWellFormed([20 * M]).step).toBe(5 * M);
    const tiny = expectWellFormed([2 * M]);
    expect(tiny.step).toBe(5 * M);
    expect(tiny.max).toBe(15 * M);
  });

  it('alle Schritte sind ganze Minuten', () => {
    for (const v of [7 * M, 50 * M, 3.3 * H, 27 * H, 333 * H, -9 * H]) {
      expect(expectWellFormed([v]).step % M).toBe(0);
    }
  });

  it('nicht endliche Werte zählen als 0', () => {
    const s = niceScale([Number.NaN, Number.POSITIVE_INFINITY, 2 * H]);
    expect(Number.isFinite(s.max)).toBe(true);
    expect(s.max).toBeGreaterThanOrEqual(2 * H);
  });
});

describe('formatAxisHours (#531)', () => {
  it('ganze Stunden, Teilstunden, Vorzeichen', () => {
    expect(formatAxisHours(0)).toBe('0 h');
    expect(formatAxisHours(40 * H)).toBe('40 h');
    expect(formatAxisHours(30 * M)).toBe('0:30 h');
    expect(formatAxisHours(10 * H, true)).toBe('+10 h');
    expect(formatAxisHours(-5 * H, true)).toBe('-5 h');
    expect(formatAxisHours(0, true)).toBe('0 h');
  });
});

describe('axisLabelStep (#531)', () => {
  it('genug Platz: jede Beschriftung', () => {
    expect(axisLabelStep(12, 720, 40)).toBe(1);
  });

  it('Handy-Breite: jede zweite oder dritte, nie Überlappung', () => {
    const step = axisLabelStep(12, 300, 40);
    expect(step).toBeGreaterThan(1);
    expect((300 / 12) * step).toBeGreaterThanOrEqual(40);
  });

  it('Sonderfälle: ein Punkt oder keine Breite', () => {
    expect(axisLabelStep(1, 300, 40)).toBe(1);
    expect(axisLabelStep(12, 0, 40)).toBe(1);
  });

  it('Breitenschätzung wächst mit Text und Schriftgröße', () => {
    expect(estimateTextWidth('KW 45', 11)).toBeGreaterThan(estimateTextWidth('Nov', 11));
    expect(estimateTextWidth('KW 45', 12)).toBeGreaterThan(estimateTextWidth('KW 45', 10));
  });
});

describe('duration-format (Format der Berichte)', () => {
  it('HH:MM und ±HH:MM, Minuten abgeschnitten', () => {
    expect(formatDurationHm(38 * H + 24 * M + 59_000)).toBe('38:24');
    expect(formatDurationHm(-90 * M)).toBe('01:30');
    expect(formatSignedDurationHm(150 * M)).toBe('+02:30');
    expect(formatSignedDurationHm(-96 * M)).toBe('-01:36');
    expect(formatSignedDurationHm(0)).toBe('+00:00');
    expect(formatDurationHm(Number.NaN)).toBe('00:00');
  });
});
