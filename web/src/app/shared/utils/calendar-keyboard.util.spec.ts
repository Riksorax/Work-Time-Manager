import { CalendarNavKey, isCalendarNavKey, nextFocusDate } from './calendar-keyboard.util';

const ymd = (d: Date): [number, number, number] => [d.getFullYear(), d.getMonth() + 1, d.getDate()];
const next = (key: CalendarNavKey, from: Date, ctrl = false): [number, number, number] =>
  ymd(nextFocusDate(key, from, ctrl));

describe('calendar-keyboard.util', () => {
  describe('Pfeile', () => {
    const from = new Date(2026, 9, 15);
    it('bewegt um +-1 und +-7 Tage', () => {
      expect(next('ArrowRight', from)).toEqual([2026, 10, 16]);
      expect(next('ArrowLeft', from)).toEqual([2026, 10, 14]);
      expect(next('ArrowDown', from)).toEqual([2026, 10, 22]);
      expect(next('ArrowUp', from)).toEqual([2026, 10, 8]);
    });
    it('geht über Monatsgrenzen', () => {
      expect(next('ArrowRight', new Date(2026, 9, 31))).toEqual([2026, 11, 1]);
      expect(next('ArrowLeft', new Date(2026, 10, 1))).toEqual([2026, 10, 31]);
      expect(next('ArrowDown', new Date(2026, 9, 28))).toEqual([2026, 11, 4]);
    });
    it('geht über Jahresgrenzen', () => {
      expect(next('ArrowRight', new Date(2026, 11, 31))).toEqual([2027, 1, 1]);
      expect(next('ArrowLeft', new Date(2027, 0, 1))).toEqual([2026, 12, 31]);
      expect(next('ArrowUp', new Date(2027, 0, 1))).toEqual([2026, 12, 25]);
    });
    it('beachtet das Schaltjahr 2028', () => {
      expect(next('ArrowRight', new Date(2028, 1, 28))).toEqual([2028, 2, 29]);
      expect(next('ArrowRight', new Date(2028, 1, 29))).toEqual([2028, 3, 1]);
    });
    it('Ctrl ändert bei Pfeilen nichts', () => {
      expect(next('ArrowRight', from, true)).toEqual([2026, 10, 16]);
    });
  });

  describe('PageUp/PageDown', () => {
    it('wechselt den Monat und klemmt auf den Monatsletzten', () => {
      expect(next('PageDown', new Date(2026, 0, 31))).toEqual([2026, 2, 28]);
      expect(next('PageUp', new Date(2026, 2, 31))).toEqual([2026, 2, 28]);
      expect(next('PageDown', new Date(2028, 0, 31))).toEqual([2028, 2, 29]);
      expect(next('PageUp', new Date(2028, 2, 31))).toEqual([2028, 2, 29]);
    });
    it('behält den Tag und wechselt das Jahr', () => {
      expect(next('PageDown', new Date(2026, 11, 15))).toEqual([2027, 1, 15]);
      expect(next('PageUp', new Date(2027, 0, 15))).toEqual([2026, 12, 15]);
      expect(next('PageUp', new Date(2026, 9, 15))).toEqual([2026, 9, 15]);
    });
  });

  describe('Home/End', () => {
    it('springt auf Montag/Sonntag der Zeile', () => {
      expect(next('Home', new Date(2026, 9, 14))).toEqual([2026, 10, 12]);
      expect(next('End', new Date(2026, 9, 14))).toEqual([2026, 10, 18]);
      expect(next('Home', new Date(2026, 9, 12))).toEqual([2026, 10, 12]);
      expect(next('End', new Date(2026, 9, 18))).toEqual([2026, 10, 18]);
    });
    it('klemmt auf den Monat', () => {
      expect(next('Home', new Date(2026, 9, 2))).toEqual([2026, 10, 1]);
      expect(next('End', new Date(2026, 9, 29))).toEqual([2026, 10, 31]);
    });
    it('Strg+Home/End: Monatsanfang/-ende', () => {
      expect(next('Home', new Date(2026, 9, 14), true)).toEqual([2026, 10, 1]);
      expect(next('End', new Date(2026, 9, 14), true)).toEqual([2026, 10, 31]);
      expect(next('End', new Date(2026, 1, 3), true)).toEqual([2026, 2, 28]);
      expect(next('End', new Date(2028, 1, 3), true)).toEqual([2028, 2, 29]);
    });
  });

  describe('Zeitumstellung', () => {
    it('verschiebt keine Tage und liefert lokale Mitternacht', () => {
      for (const from of [new Date(2026, 9, 25), new Date(2026, 2, 29)]) {
        const y = from.getFullYear(), m = from.getMonth(), d = from.getDate();
        const cases: [CalendarNavKey, number][] = [
          ['ArrowRight', 1], ['ArrowLeft', -1], ['ArrowDown', 7], ['ArrowUp', -7],
        ];
        for (const [key, n] of cases) {
          const r = nextFocusDate(key, from, false);
          const exp = new Date(y, m, d + n);
          expect(ymd(r)).toEqual(ymd(exp));
          expect(r.getHours()).toBe(0);
        }
      }
    });
  });

  describe('Reinheit', () => {
    it('mutiert die Eingabe nicht und liefert eine neue Instanz', () => {
      const from = new Date(2026, 9, 15);
      const t = from.getTime();
      const r = nextFocusDate('Home', from, true);
      expect(from.getTime()).toBe(t);
      expect(r).not.toBe(from);
      const same = nextFocusDate('Home', new Date(2026, 9, 1), true);
      expect(ymd(same)).toEqual([2026, 10, 1]);
    });
  });

  describe('isCalendarNavKey', () => {
    it('erkennt die 8 Navigationstasten', () => {
      for (const k of ['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown', 'Home', 'End', 'PageUp', 'PageDown']) {
        expect(isCalendarNavKey(k)).toBe(true);
      }
    });
    it('lehnt andere Tasten ab', () => {
      for (const k of ['Enter', ' ', 'a', 'Tab']) expect(isCalendarNavKey(k)).toBe(false);
    });
  });
});
