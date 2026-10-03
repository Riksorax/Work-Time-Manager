import { addCalendarDays, getIsoWeekBounds, getIsoWeekNumber, getIsoWeekYear } from './iso-week.util';

const d = (y: number, m: number, day: number, h = 0) => new Date(y, m - 1, day, h);

describe('iso-week.util', () => {
  it.each([
    [2026, 3, 30, 14], [2026, 8, 31, 36], [2026, 10, 26, 44],
    [2024, 12, 30, 1], [2025, 12, 29, 1], [2027, 1, 1, 53], [2027, 1, 4, 1], [2021, 1, 1, 53],
  ])('KW %i-%i-%i = %i', (y, m, day, kw) => {
    expect(getIsoWeekNumber(d(y, m, day))).toBe(kw);
    expect(getIsoWeekNumber(d(y, m, day, 23))).toBe(kw);
  });

  it('Wochenjahr am Jahreswechsel', () => {
    expect(getIsoWeekYear(d(2027, 1, 1))).toBe(2026);
    expect(getIsoWeekYear(d(2024, 12, 30))).toBe(2025);
  });

  it('addCalendarDays behaelt Kalendertag ueber Umstellungen', () => {
    const r = addCalendarDays(d(2026, 3, 30), -7);
    expect([r.getFullYear(), r.getMonth(), r.getDate(), r.getHours()]).toEqual([2026, 2, 23, 0]);
    const f = addCalendarDays(d(2026, 10, 26), -7);
    expect([f.getMonth(), f.getDate(), f.getHours()]).toEqual([9, 19, 0]);
  });

  it('getIsoWeekBounds liefert Mo 0:00 bis So 0:00', () => {
    for (const [y, m, day] of [[2026, 3, 30], [2026, 4, 1], [2026, 10, 25], [2026, 10, 28]]) {
      const { start, end } = getIsoWeekBounds(d(y, m, day));
      expect([start.getDay(), start.getHours(), end.getDay(), end.getHours()]).toEqual([1, 0, 0, 0]);
    }
  });
});
