import { normalizeVacationDays } from './vacation-days.util';

describe('normalizeVacationDays', () => {
  it.each([0, 25, 30, 366])('behält gültigen Wert %s', v => {
    expect(normalizeVacationDays(v)).toBe(v);
  });

  it.each([undefined, null, '30', NaN, Infinity, -1, 367, 2.5])('fällt bei %s auf 30 zurück', v => {
    expect(normalizeVacationDays(v)).toBe(30);
  });
});
