import { breakDurationLabel, breakDurationMs } from './break-duration.utils';

// Feste Zeitpunkte, keine Abhängigkeit von Datum oder Zeitzone.
const at = (h: number, m: number, s = 0) => new Date(2026, 2, 18, h, m, s);

describe('breakDurationMs (#504)', () => {
  it('abgeschlossene Pause: Ende minus Start', () => {
    expect(breakDurationMs({ start: at(12, 0), end: at(12, 30) }, at(18, 0))).toBe(30 * 60000);
  });

  it('laufende Pause: bis jetzt', () => {
    expect(breakDurationMs({ start: at(12, 0) }, at(12, 12, 30))).toBe(12.5 * 60000);
  });

  it('nie negativ (Uhr vor dem Start)', () => {
    expect(breakDurationMs({ start: at(12, 0) }, at(11, 59))).toBe(0);
  });
});

describe('breakDurationLabel (#504)', () => {
  it('unter einer Minute', () => {
    expect(breakDurationLabel(59_999).key).toBe('dashboard.breakDurationLessThanMinute');
    expect(breakDurationLabel(0).key).toBe('dashboard.breakDurationLessThanMinute');
  });

  it('volle Minuten, abgerundet', () => {
    const l = breakDurationLabel(30 * 60000 + 59_000);
    expect(l.key).toBe('dashboard.breakDurationMinutes');
    expect(l.params).toEqual({ hours: 0, minutes: 30 });
  });

  it('ab einer Stunde mit Stunden und Minuten', () => {
    const l = breakDurationLabel(65 * 60000);
    expect(l.key).toBe('dashboard.breakDurationHoursMinutes');
    expect(l.params).toEqual({ hours: 1, minutes: 5 });
  });

  it('genau eine Stunde', () => {
    expect(breakDurationLabel(60 * 60000).params).toEqual({ hours: 1, minutes: 0 });
  });
});
