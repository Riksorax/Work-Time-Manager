import { normalizeWorkdays } from './workdays.util';

describe('normalizeWorkdays', () => {
  it('entfernt Duplikate und sortiert', () => {
    expect(normalizeWorkdays([1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6])).toEqual([1, 2, 3, 4, 5, 6]);
    expect(normalizeWorkdays([5, 3, 1])).toEqual([1, 3, 5]);
  });

  it('verwirft ungültige Wochentage', () => {
    expect(normalizeWorkdays([0, 1, 8, 2.5, 7, -1])).toEqual([1, 7]);
  });

  it('lässt eine leere Liste leer', () => {
    expect(normalizeWorkdays([])).toEqual([]);
  });
});
