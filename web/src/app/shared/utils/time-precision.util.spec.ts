import {
  nowToMinute,
  roundMsToMinute,
  roundToMinute,
  roundToMinuteOrUndefined,
  toStoredMinutes,
} from './time-precision.util';

describe('time-precision.util', () => {
  describe('roundToMinute', () => {
    it('schneidet Sekunden unter 30 ab', () => {
      expect(roundToMinute(new Date(2024, 4, 6, 8, 0, 29, 999)))
        .toEqual(new Date(2024, 4, 6, 8, 0, 0, 0));
    });

    it('schneidet auch ab genau 30 Sekunden ab statt aufzurunden', () => {
      expect(roundToMinute(new Date(2024, 4, 6, 8, 0, 30)))
        .toEqual(new Date(2024, 4, 6, 8, 0, 0, 0));
    });

    it('schneidet auch kurz vor der nächsten Minute ab', () => {
      expect(roundToMinute(new Date(2024, 4, 6, 8, 0, 59, 999)))
        .toEqual(new Date(2024, 4, 6, 8, 0, 0, 0));
    });

    it('lässt eine volle Minute unverändert', () => {
      const exact = new Date(2024, 4, 6, 8, 0, 0, 0);
      expect(roundToMinute(exact)).toEqual(exact);
    });

    it('rundet nie über die Stunden- oder Tagesgrenze auf', () => {
      expect(roundToMinute(new Date(2024, 4, 6, 8, 59, 45)))
        .toEqual(new Date(2024, 4, 6, 8, 59, 0, 0));
      expect(roundToMinute(new Date(2024, 4, 6, 23, 59, 45)))
        .toEqual(new Date(2024, 4, 6, 23, 59, 0, 0));
    });
  });

  describe('roundToMinuteOrUndefined', () => {
    it('gibt undefined für null/undefined zurück', () => {
      expect(roundToMinuteOrUndefined(null)).toBeUndefined();
      expect(roundToMinuteOrUndefined(undefined)).toBeUndefined();
    });
  });

  describe('nowToMinute', () => {
    it('liefert einen Zeitstempel ohne Sekundenanteil', () => {
      const now = nowToMinute();
      expect(now.getSeconds()).toBe(0);
      expect(now.getMilliseconds()).toBe(0);
    });
  });

  describe('roundMsToMinute', () => {
    it('rundet kaufmännisch auf volle Minuten', () => {
      expect(roundMsToMinute(5 * 60000 + 29999)).toBe(5 * 60000);
      expect(roundMsToMinute(5 * 60000 + 30000)).toBe(6 * 60000);
    });

    it('rundet negative Werte symmetrisch', () => {
      expect(roundMsToMinute(-(5 * 60000 + 29999))).toBe(-5 * 60000);
      expect(roundMsToMinute(-(5 * 60000 + 30000))).toBe(-6 * 60000);
    });
  });

  describe('toStoredMinutes', () => {
    it('gibt gerundete volle Minuten zurück', () => {
      expect(toStoredMinutes(3600000 + 31000)).toBe(61);
      expect(toStoredMinutes(-(3600000 + 31000))).toBe(-61);
    });
  });
});
