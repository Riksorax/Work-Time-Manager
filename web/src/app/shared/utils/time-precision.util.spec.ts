import {
  nowToMinute,
  roundMsToMinute,
  roundToMinute,
  roundToMinuteOrUndefined,
  toStoredMinutes,
} from './time-precision.util';

describe('time-precision.util', () => {
  describe('roundToMinute', () => {
    it('rundet unter 30 Sekunden ab', () => {
      expect(roundToMinute(new Date(2024, 4, 6, 8, 0, 29, 999)))
        .toEqual(new Date(2024, 4, 6, 8, 0, 0, 0));
    });

    it('rundet ab genau 30 Sekunden auf', () => {
      expect(roundToMinute(new Date(2024, 4, 6, 8, 0, 30)))
        .toEqual(new Date(2024, 4, 6, 8, 1, 0, 0));
    });

    it('lässt eine volle Minute unverändert', () => {
      const exact = new Date(2024, 4, 6, 8, 0, 0, 0);
      expect(roundToMinute(exact)).toEqual(exact);
    });

    it('rundet über die Stunden- und Tagesgrenze korrekt', () => {
      expect(roundToMinute(new Date(2024, 4, 6, 8, 59, 45)))
        .toEqual(new Date(2024, 4, 6, 9, 0, 0, 0));
      expect(roundToMinute(new Date(2024, 4, 6, 23, 59, 45)))
        .toEqual(new Date(2024, 4, 7, 0, 0, 0, 0));
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
