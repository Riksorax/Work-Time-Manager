import { calendarDateFromUtcMidnight, localDateFromEntryId, parseEntryId } from './entry-day.util';

/**
 * Zonen-Regressionstests (#407) für die Lesegrenzen-Helfer. Behauptet wird nur über lokale Kalenderfelder und
 * `new Date(y, m, d)` (in jeder Zone wahr), nie über absolute Zeitpunkte. Läuft in CI zusätzlich unter
 * America/Los_Angeles und Pacific/Auckland.
 */
const fields = (d: Date) => [d.getFullYear(), d.getMonth() + 1, d.getDate(), d.getHours(), d.getMinutes()];

describe('localDateFromEntryId', () => {
  it.each([
    ['2026-10-05', [2026, 10, 5]],
    ['2026-03-02', [2026, 3, 2]],
    ['2026-12-31', [2026, 12, 31]],
    ['2026-01-01', [2026, 1, 1]],
    ['2026-11-01', [2026, 11, 1]],
    ['2024-02-29', [2024, 2, 29]],
  ])('%s -> lokale Mitternacht %j', (id, [y, m, d]) => {
    expect(fields(localDateFromEntryId(id))).toEqual([y, m, d, 0, 0]);
  });

  it.each(['2026-03-29', '2026-10-25', '2026-03-08', '2026-11-01', '2026-09-27', '2026-04-05'])(
    'Zeitumstellungstag %s: lokale Mitternacht des Tages',
    id => {
      const [y, m, d] = id.split('-').map(Number);
      expect(localDateFromEntryId(id).getTime()).toBe(new Date(y, m - 1, d).getTime());
    },
  );
});

describe('parseEntryId', () => {
  it.each([
    ['2026-10-05', [2026, 10, 5]],
    ['2026-01-01', [2026, 1, 1]],
    ['2024-02-29', [2024, 2, 29]],
  ])('gültige id %s -> lokale Mitternacht', (id, [y, m, d]) => {
    const parsed = parseEntryId(id);
    expect(parsed).not.toBeNull();
    expect(fields(parsed!)).toEqual([y, m, d, 0, 0]);
  });

  it.each([
    '1', '', 'x', '2026-3-2', '2026-13-45', '2026-02-30', '2026-02-31', '2025-02-29', '2026-00-10', '2026-10-00',
    '2026-10-05T00:00:00Z', ' 2026-10-05', '2026-10-05 ', '2026-10-NaN', 'a0a0-10-05',
  ])('ungültige id %j -> null', id => {
    expect(parseEntryId(id)).toBeNull();
  });

  it('Round-Trip: 2026-02-31 läuft nicht in den März über', () => {
    expect(parseEntryId('2026-02-31')).toBeNull();
  });
});

describe('calendarDateFromUtcMidnight', () => {
  it('UTC-Mitternacht 05.10. -> lokaler 05.10., 00:00', () => {
    expect(fields(calendarDateFromUtcMidnight(new Date(Date.UTC(2026, 9, 5))))).toEqual([2026, 10, 5, 0, 0]);
  });

  it.each([
    ['+00:00', '2026-10-05T00:00:00+00:00'],
    ['Z', '2026-10-05T00:00:00Z'],
    ['.000Z', '2026-10-05T00:00:00.000Z'],
  ])('geparstes Datum mit Suffix %s', (_label, iso) => {
    expect(fields(calendarDateFromUtcMidnight(new Date(iso)))).toEqual([2026, 10, 5, 0, 0]);
  });

  it('ergibt die lokale Mitternacht als Zeitpunkt (new Date(y, m, d))', () => {
    expect(calendarDateFromUtcMidnight(new Date(Date.UTC(2026, 9, 5))).getTime()).toBe(new Date(2026, 9, 5).getTime());
  });

  it.each([
    [Date.UTC(2026, 10, 1), [2026, 11, 1]],   // Monatserster (Sonntag)
    [Date.UTC(2026, 0, 1), [2026, 1, 1]],     // Jahresanfang
    [Date.UTC(2025, 11, 31), [2025, 12, 31]], // Jahresende
    [Date.UTC(2024, 1, 29), [2024, 2, 29]],   // Schaltjahr
  ])('Grenzfall %i', (utc, [y, m, d]) => {
    expect(fields(calendarDateFromUtcMidnight(new Date(utc)))).toEqual([y, m, d, 0, 0]);
  });

  it.each([
    Date.UTC(2026, 2, 29), Date.UTC(2026, 9, 25), Date.UTC(2026, 2, 8), Date.UTC(2026, 10, 1),
    Date.UTC(2026, 8, 27), Date.UTC(2026, 3, 5),
  ])('Zeitumstellungstag (UTC %i): lokale Mitternacht desselben Kalendertags', utc => {
    const src = new Date(utc);
    const expected = new Date(src.getUTCFullYear(), src.getUTCMonth(), src.getUTCDate());
    expect(calendarDateFromUtcMidnight(src).getTime()).toBe(expected.getTime());
  });

  it('hängt nur von den UTC-Feldern ab: 23:59 UTC bleibt am 05.10. (nicht 06.10.)', () => {
    expect(fields(calendarDateFromUtcMidnight(new Date(Date.UTC(2026, 9, 5, 23, 59))))).toEqual([2026, 10, 5, 0, 0]);
  });

  it('gibt ein neues Objekt zurück und verändert die Eingabe nicht', () => {
    const src = new Date(Date.UTC(2026, 9, 5));
    const before = src.getTime();
    const out = calendarDateFromUtcMidnight(src);
    expect(out).not.toBe(src);
    expect(src.getTime()).toBe(before);
  });
});
