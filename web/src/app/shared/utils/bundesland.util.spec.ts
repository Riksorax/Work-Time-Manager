import { BUNDESLAND_VALUES } from '../models';
import { isBundesland, normalizeBundesland } from './bundesland.util';

describe('bundesland.util', () => {
  it.each(BUNDESLAND_VALUES)('normalizeBundesland behält gültigen Wert %s', (v) => {
    expect(normalizeBundesland(v)).toBe(v);
    expect(isBundesland(v)).toBe(true);
  });

  it.each([['""', ''], ['NRW', 'NRW'], ['null', null], ['undefined', undefined], ['42', 42], ['{}', {}], ['Bayern', 'Bayern']])(
    'liefert für %s null',
    (_label, raw) => {
      expect(normalizeBundesland(raw)).toBeNull();
      expect(isBundesland(raw)).toBe(false);
    },
  );
});
