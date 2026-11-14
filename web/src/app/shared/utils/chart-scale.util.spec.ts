import { axisLabelStep, estimateTextWidth, formatAxisHours, niceScale } from './chart-scale.util';
import { formatDurationHm, formatSignedDurationHm } from './duration-format.util';

const H = 3_600_000;
const M = 60_000;

describe('niceScale (#531)', () => {
  it('leere Liste und nur Nullen: 0 bis 1 h, kein NaN', () => {
    for (const values of [[], [0, 0, 0]]) {
      const s = niceScale(values);
      expect(s.min).toBe(0);
      expect(s.max).toBe(H);
      expect(s.ticks.every(Number.isFinite)).toBe(true);
      expect(s.ticks[0]).toBe(0);
      expect(s.ticks.at(-1)).toBe(H);
    }
  });

  it('typische Woche: 0 bis 40/50 h mit runden Schritten, 0 enthalten', () => {
    const s = niceScale([38 * H, 40 * H, 41.5 * H]);
    expect(s.min).toBe(0);
    expect(s.max).toBeGreaterThanOrEqual(41.5 * H);
    expect(s.ticks).toContain(0);
    expect(s.ticks.length).toBeLessThanOrEqual(5);
    expect(s.step % H).toBe(0);
  });

  it('nur negative Werte: Maximum ist 0, Minimum deckt den kleinsten Wert', () => {
    const s = niceScale([-3 * H, -12 * H, -0.5 * H]);
    expect(s.max).toBe(0);
    expect(s.min).toBeLessThanOrEqual(-12 * H);
    expect(s.ticks).toContain(0);
  });

  it('positive und negative Werte: beide Seiten, 0 als Teilstrich', () => {
    const s = niceScale([-7 * H, 13 * H]);
    expect(s.min).toBeLessThanOrEqual(-7 * H);
    expect(s.max).toBeGreaterThanOrEqual(13 * H);
    expect(s.ticks).toContain(0);
    expect(s.ticks.length).toBeLessThanOrEqual(5);
  });

  it('sehr große Werte und ein einzelner Ausreißer: endlich, höchstens 5 Teilstriche', () => {
    const s = niceScale([40 * H, 38 * H, 2_000_000 * H]);
    expect(s.max).toBeGreaterThanOrEqual(2_000_000 * H);
    expect(s.ticks.length).toBeLessThanOrEqual(5);
    expect(s.ticks.every(Number.isFinite)).toBe(true);
  });

  it('kleine Werte unter einer Stunde: Viertel- bzw. halbe Stunden', () => {
    const s = niceScale([20 * M]);
    expect(s.step).toBe(15 * M);
    expect(s.max).toBe(30 * M);
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
