import { CalendarNavKey, isCalendarNavKey, nextFocusDate, rangeDiff, rangeKeys } from './calendar-keyboard.util';

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

describe('rangeKeys', () => {
  const k = (y: number, m: number, d: number) =>
    `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`;

  it('liefert für denselben Tag genau einen Key', () => {
    expect(rangeKeys(new Date(2026, 9, 15), new Date(2026, 9, 15))).toEqual(['2026-10-15']);
  });

  it('liefert vorwärts und rückwärts denselben geordneten Bereich', () => {
    const fwd = rangeKeys(new Date(2026, 9, 15), new Date(2026, 9, 18));
    expect(fwd).toEqual(['2026-10-15', '2026-10-16', '2026-10-17', '2026-10-18']);
    expect(rangeKeys(new Date(2026, 9, 18), new Date(2026, 9, 15))).toEqual(fwd);
  });

  it('geht über Monats- und Jahresgrenzen', () => {
    expect(rangeKeys(new Date(2026, 9, 30), new Date(2026, 10, 2)))
      .toEqual(['2026-10-30', '2026-10-31', '2026-11-01', '2026-11-02']);
    expect(rangeKeys(new Date(2026, 11, 30), new Date(2027, 0, 2)))
      .toEqual(['2026-12-30', '2026-12-31', '2027-01-01', '2027-01-02']);
  });

  it('beachtet das Schaltjahr', () => {
    expect(rangeKeys(new Date(2028, 1, 27), new Date(2028, 2, 1)))
      .toEqual(['2028-02-27', '2028-02-28', '2028-02-29', '2028-03-01']);
    expect(rangeKeys(new Date(2026, 1, 27), new Date(2026, 2, 1)))
      .toEqual(['2026-02-27', '2026-02-28', '2026-03-01']);
  });

  it('liefert über die Zeitumstellung je Tag genau einen Key', () => {
    expect(rangeKeys(new Date(2026, 9, 24), new Date(2026, 9, 27)))
      .toEqual(['2026-10-24', '2026-10-25', '2026-10-26', '2026-10-27']);
    expect(rangeKeys(new Date(2026, 2, 28), new Date(2026, 2, 30)))
      .toEqual(['2026-03-28', '2026-03-29', '2026-03-30']);
  });

  it('liefert für ein ganzes Jahr 365 bzw. 366 Keys ohne Dopplung', () => {
    const y26 = rangeKeys(new Date(2026, 0, 1), new Date(2026, 11, 31));
    expect(y26).toHaveLength(365);
    expect(new Set(y26).size).toBe(365);
    expect(y26[0]).toBe(k(2026, 1, 1));
    expect(y26[364]).toBe(k(2026, 12, 31));
    expect(rangeKeys(new Date(2028, 0, 1), new Date(2028, 11, 31))).toHaveLength(366);
  });

  it('ist rein: Eingaben bleiben unverändert', () => {
    const a = new Date(2026, 9, 18, 13, 30);
    const b = new Date(2026, 9, 15, 8, 5);
    const a0 = a.getTime();
    const b0 = b.getTime();
    rangeKeys(a, b);
    expect(a.getTime()).toBe(a0);
    expect(b.getTime()).toBe(b0);
  });
});

describe('rangeDiff', () => {
  const set = (...days: number[]) => new Set(days.map(d => `2026-10-${String(d).padStart(2, '0')}`));
  const keys = (...days: number[]) => [...set(...days)];
  const sorted = (a: string[]) => [...a].sort();

  it('Erweitern entfernt nichts', () => {
    const r = rangeDiff(set(10, 11, 12), set(10, 11, 12, 13), set());
    expect(r.remove).toEqual([]);
    expect(sorted(r.add)).toEqual(sorted(keys(10, 11, 12, 13)));
  });

  it('Verkleinern entfernt den letzten Tag', () => {
    expect(rangeDiff(set(10, 11, 12, 13), set(10, 11, 12), set()).remove).toEqual(keys(13));
  });

  it('Umkehr über den Anker entfernt die Gegenseite und fügt die neue hinzu', () => {
    const r = rangeDiff(set(10, 11, 12, 13), set(8, 9, 10), set());
    expect(sorted(r.remove)).toEqual(sorted(keys(11, 12, 13)));
    expect(sorted(r.add)).toEqual(sorted(keys(8, 9, 10)));
  });

  it('entfernt nie Tage der Basis', () => {
    const r = rangeDiff(set(10, 11, 12, 13), set(10), set(11));
    expect(sorted(r.remove)).toEqual(sorted(keys(12, 13)));
  });

  it('kommt mit leeren Mengen und identischen Mengen zurecht', () => {
    expect(rangeDiff(set(), set(), set())).toEqual({ add: [], remove: [] });
    expect(rangeDiff(set(10, 11), set(10, 11), set()).remove).toEqual([]);
    expect(rangeDiff(set(10), set(), set()).remove).toEqual(keys(10));
  });
});

describe('Shift-Navigation: nextFocusDate + rangeKeys', () => {
  const range = (key: CalendarNavKey, from: Date) => rangeKeys(from, nextFocusDate(key, from, false));

  it('Shift+Pfeil: +-1 und +-7', () => {
    const from = new Date(2026, 9, 15);
    expect(range('ArrowRight', from)).toEqual(['2026-10-15', '2026-10-16']);
    expect(range('ArrowLeft', from)).toEqual(['2026-10-14', '2026-10-15']);
    expect(range('ArrowDown', from)).toHaveLength(8);
    expect(range('ArrowUp', from)).toHaveLength(8);
    expect(range('ArrowUp', from)[0]).toBe('2026-10-08');
  });

  it('Shift+Home/End: Montag bzw. Sonntag der Zeile, auf den Monat geklemmt', () => {
    // 15.10.2026 ist ein Donnerstag
    expect(range('Home', new Date(2026, 9, 15))).toEqual(['2026-10-12', '2026-10-13', '2026-10-14', '2026-10-15']);
    expect(range('End', new Date(2026, 9, 15))).toEqual(['2026-10-15', '2026-10-16', '2026-10-17', '2026-10-18']);
    // 1.10.2026 (Do): Home auf den Monatsersten geklemmt
    expect(range('Home', new Date(2026, 9, 1))).toEqual(['2026-10-01']);
    // 31.10.2026 (Sa): End auf den Monatsletzten geklemmt
    expect(range('End', new Date(2026, 9, 31))).toEqual(['2026-10-31']);
  });

  it('Shift+PageDown/PageUp: Monatswechsel mit allen Tagen dazwischen', () => {
    const down = range('PageDown', new Date(2026, 0, 31));
    expect(down[0]).toBe('2026-01-31');
    expect(down[down.length - 1]).toBe('2026-02-28');
    expect(down).toHaveLength(29);
    const up = range('PageUp', new Date(2026, 2, 31));
    expect(up[0]).toBe('2026-02-28');
    expect(up[up.length - 1]).toBe('2026-03-31');
  });

  it('Jahreswechsel und Schaltjahr', () => {
    expect(range('ArrowRight', new Date(2026, 11, 31))).toEqual(['2026-12-31', '2027-01-01']);
    expect(range('ArrowRight', new Date(2028, 1, 28))).toEqual(['2028-02-28', '2028-02-29']);
    expect(range('ArrowRight', new Date(2028, 1, 29))).toEqual(['2028-02-29', '2028-03-01']);
  });
});
