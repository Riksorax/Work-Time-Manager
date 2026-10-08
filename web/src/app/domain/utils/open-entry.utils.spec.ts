import { Break, WorkEntry, WorkEntryType } from '../../shared/models';
import { DashboardService } from '../../features/dashboard/dashboard.service';
import {
  OPEN_ENTRY_LONG_WARNING_MS,
  OPEN_ENTRY_MAX_NOW_AGE_MS,
  canResumeOpenEntry,
  closedBreakMs,
  effectiveTargetMsForDate,
  formatEntryDay,
  formatHm,
  isValidOpenEntryEnd,
  localDateFromEntryId,
  retroDeltaMs,
  suggestOpenEntryEnd,
} from './open-entry.utils';

const MIN = 60_000;
const HOUR = 60 * MIN;

/** Lokale Zeit (Monat 1-basiert). Keine Zonenannahme: alles lokal gebaut. */
function at(y: number, m: number, d: number, h = 0, min = 0, s = 0): Date {
  return new Date(y, m - 1, d, h, min, s);
}

function brk(start: Date, end?: Date): Break {
  return { id: `b${start.getTime()}`, name: 'Pause', start, end, isAutomatic: false };
}

function entry(partial: Partial<WorkEntry> = {}): WorkEntry {
  const start = partial.workStart ?? at(2026, 10, 2, 8, 0);
  return {
    id: '2026-10-02',
    date: at(2026, 10, 2),
    workStart: start,
    breaks: [],
    isManuallyEntered: false,
    type: WorkEntryType.Work,
    ...partial,
  };
}

describe('open-entry.utils', () => {
  describe('Konstanten', () => {
    it('24 h und 16 h in Millisekunden', () => {
      expect(OPEN_ENTRY_MAX_NOW_AGE_MS).toBe(24 * HOUR);
      expect(OPEN_ENTRY_LONG_WARNING_MS).toBe(16 * HOUR);
    });
  });

  describe('localDateFromEntryId', () => {
    it('einstellige und zweistellige Tage, lokale Mitternacht', () => {
      for (const [id, y, m, d] of [['2026-10-02', 2026, 10, 2], ['2026-10-21', 2026, 10, 21]] as const) {
        const date = localDateFromEntryId(id);
        expect([date.getFullYear(), date.getMonth() + 1, date.getDate()]).toEqual([y, m, d]);
        expect([date.getHours(), date.getMinutes(), date.getSeconds()]).toEqual([0, 0, 0]);
      }
    });

    it('Monatsgrenze und Jahreswechsel', () => {
      const a = localDateFromEntryId('2026-10-31');
      expect([a.getMonth() + 1, a.getDate()]).toEqual([10, 31]);
      const b = localDateFromEntryId('2025-12-31');
      expect([b.getFullYear(), b.getMonth() + 1, b.getDate()]).toEqual([2025, 12, 31]);
      const c = localDateFromEntryId('2026-01-01');
      expect([c.getFullYear(), c.getMonth() + 1, c.getDate()]).toEqual([2026, 1, 1]);
    });

    it('DST-Tage bleiben der angegebene Kalendertag', () => {
      for (const id of ['2026-10-25', '2026-03-29', '2026-11-01', '2026-03-08', '2026-09-27', '2026-04-05']) {
        const date = localDateFromEntryId(id);
        const [y, m, d] = id.split('-').map(Number);
        expect([date.getFullYear(), date.getMonth() + 1, date.getDate()]).toEqual([y, m, d]);
      }
    });
  });

  describe('effectiveTargetMsForDate', () => {
    const settings = { weeklyTargetHours: 40, workdays: [1, 2, 3, 4, 5] };

    it('Arbeitstag: 40 h / 5 Tage = 8 h', () => {
      // 2026-10-02 ist ein Freitag (ISO 5), 2026-10-05 ein Montag.
      expect(effectiveTargetMsForDate(settings, at(2026, 10, 2))).toBe(8 * HOUR);
      expect(effectiveTargetMsForDate(settings, at(2026, 10, 5))).toBe(8 * HOUR);
    });

    it('Nicht-Arbeitstag (Wochenende) ergibt 0', () => {
      expect(effectiveTargetMsForDate(settings, at(2026, 10, 3))).toBe(0);
      expect(effectiveTargetMsForDate(settings, at(2026, 10, 4))).toBe(0);
    });

    it('leere workdays ergeben 0', () => {
      expect(effectiveTargetMsForDate({ weeklyTargetHours: 40, workdays: [] }, at(2026, 10, 2))).toBe(0);
    });

    it('rundet das Tagessoll auf volle Minuten (40 h / 3 Tage)', () => {
      const s = { weeklyTargetHours: 40, workdays: [1, 3, 5] };
      expect(effectiveTargetMsForDate(s, at(2026, 10, 2))).toBe(13 * HOUR + 20 * MIN);
      const s7 = { weeklyTargetHours: 40, workdays: [1, 2, 3, 4, 5, 6, 7] };
      // 40 h / 7 = 5 h 42,857 min -> 5 h 43 min
      expect(effectiveTargetMsForDate(s7, at(2026, 10, 2))).toBe(5 * HOUR + 43 * MIN);
    });

    it('entspricht der Formel des Dashboards (_targetDailyMs)', () => {
      const dashboardTarget = (DashboardService.prototype as unknown as {
        _targetDailyMs: (s: { weeklyTargetHours: number; workdays: number[] }, d: Date) => number;
      })._targetDailyMs;
      const variants = [
        { weeklyTargetHours: 40, workdays: [1, 2, 3, 4, 5] },
        { weeklyTargetHours: 40, workdays: [1, 3, 5] },
        { weeklyTargetHours: 38.5, workdays: [1, 2, 3, 4, 5, 6] },
        { weeklyTargetHours: 20, workdays: [] },
      ];
      for (const s of variants) {
        for (let day = 1; day <= 14; day++) {
          const date = at(2026, 10, day);
          expect(effectiveTargetMsForDate(s, date)).toBe(dashboardTarget.call(null, s, date));
        }
      }
    });
  });

  describe('closedBreakMs', () => {
    it('summiert nur geschlossene Pausen', () => {
      const breaks = [
        brk(at(2026, 10, 2, 12, 0), at(2026, 10, 2, 12, 30)),
        brk(at(2026, 10, 2, 15, 0), at(2026, 10, 2, 15, 15)),
        brk(at(2026, 10, 2, 17, 0)),
      ];
      expect(closedBreakMs(breaks)).toBe(45 * MIN);
      expect(closedBreakMs([])).toBe(0);
    });
  });

  describe('suggestOpenEntryEnd', () => {
    const now = at(2026, 10, 3, 9, 0);

    it('Soll-Ende = Start + Soll + geschlossene Pausen; liegt es vor jetzt, ist es der Vorschlag', () => {
      const e = entry({
        workStart: at(2026, 10, 2, 8, 0),
        breaks: [brk(at(2026, 10, 2, 12, 0), at(2026, 10, 2, 12, 30))],
      });
      const s = suggestOpenEntryEnd(e, 8 * HOUR, now);
      expect(s.expectedEnd).toEqual(at(2026, 10, 2, 16, 30));
      expect(s.suggestedEnd).toEqual(at(2026, 10, 2, 16, 30));
      expect(s.suggestedIsNow).toBe(false);
    });

    it('offene Pause zaehlt nicht zum Soll-Ende', () => {
      const e = entry({
        workStart: at(2026, 10, 2, 8, 0),
        breaks: [brk(at(2026, 10, 2, 12, 0))],
      });
      expect(suggestOpenEntryEnd(e, 8 * HOUR, now).expectedEnd).toEqual(at(2026, 10, 2, 16, 0));
    });

    it('DST-Tage: expectedEnd - start = Soll + Pausen in Millisekunden', () => {
      for (const [y, m, d] of [[2026, 10, 25], [2026, 3, 29], [2026, 11, 1], [2026, 3, 8], [2026, 9, 27], [2026, 4, 5]]) {
        const start = at(y, m, d, 0, 30);
        const e = entry({
          id: `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`,
          workStart: start,
          breaks: [brk(at(y, m, d, 4, 0), at(y, m, d, 4, 45))],
        });
        const s = suggestOpenEntryEnd(e, 8 * HOUR, at(y, m, d + 3, 12, 0));
        expect(s.expectedEnd!.getTime() - start.getTime()).toBe(8 * HOUR + 45 * MIN);
      }
    });

    it('Soll 0: kein Soll-Ende, "Jetzt" (auf Minute abgeschnitten) bei Alter <= 24 h', () => {
      const e = entry({ workStart: at(2026, 10, 2, 22, 0) });
      const s = suggestOpenEntryEnd(e, 0, at(2026, 10, 3, 9, 0, 41));
      expect(s.expectedEnd).toBeNull();
      expect(s.nowAllowed).toBe(true);
      expect(s.suggestedIsNow).toBe(true);
      expect(s.suggestedEnd).toEqual(at(2026, 10, 3, 9, 0));
    });

    it('Soll-Ende >= jetzt und Alter <= 24 h: Vorschlag "Jetzt"', () => {
      const e = entry({ workStart: at(2026, 10, 3, 7, 0) });
      const s = suggestOpenEntryEnd(e, 8 * HOUR, at(2026, 10, 3, 9, 0, 30));
      expect(s.expectedEnd).toEqual(at(2026, 10, 3, 15, 0));
      expect(s.suggestedIsNow).toBe(true);
      expect(s.suggestedEnd).toEqual(at(2026, 10, 3, 9, 0));
    });

    it('Soll-Ende genau jetzt: kein "vor jetzt", also "Jetzt"', () => {
      const e = entry({ workStart: at(2026, 10, 3, 1, 0) });
      const s = suggestOpenEntryEnd(e, 8 * HOUR, at(2026, 10, 3, 9, 0));
      expect(s.suggestedIsNow).toBe(true);
    });

    it('genau 24 h: nowAllowed; 24 h + 1 min: nicht', () => {
      const start = at(2026, 10, 2, 9, 0);
      const e = entry({ workStart: start });
      const exactly = suggestOpenEntryEnd(e, 0, new Date(start.getTime() + OPEN_ENTRY_MAX_NOW_AGE_MS));
      expect(exactly.nowAllowed).toBe(true);
      expect(exactly.suggestedEnd).not.toBeNull();
      const over = suggestOpenEntryEnd(e, 0, new Date(start.getTime() + OPEN_ENTRY_MAX_NOW_AGE_MS + MIN));
      expect(over.nowAllowed).toBe(false);
      expect(over.suggestedEnd).toBeNull();
      expect(over.suggestedIsNow).toBe(false);
    });

    it('Soll-Ende vor jetzt bleibt Vorschlag, auch wenn "Jetzt" nicht erlaubt ist', () => {
      const e = entry({ workStart: at(2026, 10, 2, 8, 0) });
      const s = suggestOpenEntryEnd(e, 8 * HOUR, at(2026, 10, 6, 12, 0));
      expect(s.nowAllowed).toBe(false);
      expect(s.suggestedEnd).toEqual(at(2026, 10, 2, 16, 0));
    });
  });

  describe('isValidOpenEntryEnd', () => {
    const now = at(2026, 10, 3, 9, 0);
    const start = at(2026, 10, 2, 8, 0);

    it('Ende gleich Start ist ungueltig, danach gueltig', () => {
      const e = entry({ workStart: start });
      expect(isValidOpenEntryEnd(e, start, now)).toBe(false);
      expect(isValidOpenEntryEnd(e, at(2026, 10, 2, 8, 1), now)).toBe(true);
      expect(isValidOpenEntryEnd(e, at(2026, 10, 2, 7, 0), now)).toBe(false);
    });

    it('nach jetzt ungueltig, genau jetzt gueltig', () => {
      const e = entry({ workStart: start });
      expect(isValidOpenEntryEnd(e, new Date(now.getTime() + 1), now)).toBe(false);
      expect(isValidOpenEntryEnd(e, now, now)).toBe(true);
    });

    it('vor dem Ende einer geschlossenen Pause ungueltig, = Pausenende gueltig', () => {
      const e = entry({ workStart: start, breaks: [brk(at(2026, 10, 2, 12, 0), at(2026, 10, 2, 12, 30))] });
      expect(isValidOpenEntryEnd(e, at(2026, 10, 2, 12, 29), now)).toBe(false);
      expect(isValidOpenEntryEnd(e, at(2026, 10, 2, 12, 30), now)).toBe(true);
    });

    it('vor dem Beginn einer offenen Pause ungueltig, = Beginn gueltig', () => {
      const e = entry({ workStart: start, breaks: [brk(at(2026, 10, 2, 12, 0))] });
      expect(isValidOpenEntryEnd(e, at(2026, 10, 2, 11, 59), now)).toBe(false);
      expect(isValidOpenEntryEnd(e, at(2026, 10, 2, 12, 0), now)).toBe(true);
    });

    it('sekundengenaues Ende wird so geprueft, wie es uebergeben wird', () => {
      const e = entry({ workStart: start });
      expect(isValidOpenEntryEnd(e, at(2026, 10, 3, 9, 0, 30), now)).toBe(false);
      expect(isValidOpenEntryEnd(e, at(2026, 10, 3, 8, 59, 59), now)).toBe(true);
      expect(isValidOpenEntryEnd(e, at(2026, 10, 2, 8, 0, 30), now)).toBe(true);
    });

    it('Eintrag ohne Start ist nie gueltig', () => {
      const e = entry({ workStart: undefined });
      e.workStart = undefined;
      expect(isValidOpenEntryEnd(e, at(2026, 10, 2, 17, 0), now)).toBe(false);
    });
  });

  describe('retroDeltaMs', () => {
    it('Netto (mit geschlossener Pause) minus Soll', () => {
      const e = entry({
        workStart: at(2026, 10, 2, 8, 0),
        workEnd: at(2026, 10, 2, 17, 0),
        breaks: [brk(at(2026, 10, 2, 12, 0), at(2026, 10, 2, 12, 30))],
      });
      expect(retroDeltaMs(e, 8 * HOUR)).toBe(30 * MIN);
    });

    it('Samstag (Soll 0): gesamtes Netto ist Ueberstunden', () => {
      const e = entry({ workStart: at(2026, 10, 3, 9, 0), workEnd: at(2026, 10, 3, 12, 0) });
      expect(retroDeltaMs(e, 0)).toBe(3 * HOUR);
    });

    it('manualOvertimeMinutes positiv und negativ', () => {
      const base = { workStart: at(2026, 10, 2, 8, 0), workEnd: at(2026, 10, 2, 16, 0) };
      expect(retroDeltaMs(entry({ ...base, manualOvertimeMinutes: 20 }), 8 * HOUR)).toBe(20 * MIN);
      expect(retroDeltaMs(entry({ ...base, manualOvertimeMinutes: -15 }), 8 * HOUR)).toBe(-15 * MIN);
    });

    it('offene Pause im Eingang wird nicht eingerechnet (Aufrufer schliesst sie vorher)', () => {
      const e = entry({
        workStart: at(2026, 10, 2, 8, 0),
        workEnd: at(2026, 10, 2, 16, 0),
        breaks: [brk(at(2026, 10, 2, 12, 0))],
      });
      expect(retroDeltaMs(e, 8 * HOUR)).toBe(0);
    });

    it('ohne Ende: Fehler statt stillem Wert', () => {
      expect(() => retroDeltaMs(entry(), 8 * HOUR)).toThrow();
    });
  });

  describe('canResumeOpenEntry', () => {
    const now = at(2026, 10, 3, 9, 0);
    const base = (e: WorkEntry = entry({ workStart: at(2026, 10, 2, 22, 0) })) => ({
      entry: e,
      now,
      todayId: '2026-10-03',
      todayIsEmpty: true,
    });

    it('offener Vortag, heute leer: erlaubt', () => {
      expect(canResumeOpenEntry(base())).toBe(true);
    });

    it('heute nicht leer: nicht erlaubt', () => {
      expect(canResumeOpenEntry({ ...base(), todayIsEmpty: false })).toBe(false);
    });

    it('Typ ungleich work, ohne Start, mit Ende: nicht erlaubt', () => {
      const s = at(2026, 10, 2, 22, 0);
      for (const type of [WorkEntryType.Vacation, WorkEntryType.Sick, WorkEntryType.Holiday]) {
        expect(canResumeOpenEntry(base(entry({ workStart: s, type })))).toBe(false);
      }
      expect(canResumeOpenEntry(base({ ...entry(), workStart: undefined }))).toBe(false);
      expect(canResumeOpenEntry(base(entry({ workStart: s, workEnd: at(2026, 10, 2, 23, 0) })))).toBe(false);
    });

    it('nur Tage vor heute (id == heute und id > heute: nicht erlaubt)', () => {
      const s = at(2026, 10, 2, 22, 0);
      expect(canResumeOpenEntry(base(entry({ id: '2026-10-03', workStart: s })))).toBe(false);
      expect(canResumeOpenEntry(base(entry({ id: '2026-10-04', workStart: s })))).toBe(false);
    });

    it('Alter: genau 24 h erlaubt, + 1 ms und + 1 min nicht (Grenze inklusiv)', () => {
      const exact = new Date(now.getTime() - OPEN_ENTRY_MAX_NOW_AGE_MS);
      expect(canResumeOpenEntry(base(entry({ workStart: exact })))).toBe(true);
      expect(canResumeOpenEntry(base(entry({ workStart: new Date(exact.getTime() - 1) })))).toBe(false);
      expect(canResumeOpenEntry(base(entry({ workStart: new Date(exact.getTime() - MIN) })))).toBe(false);
    });

    it('Mitternachtsfall: jetzt 00:30, Start 23:30 am Vortag', () => {
      const n = at(2026, 10, 3, 0, 30);
      const e = entry({ workStart: at(2026, 10, 2, 23, 30) });
      expect(canResumeOpenEntry({ entry: e, now: n, todayId: '2026-10-03', todayIsEmpty: true })).toBe(true);
    });

    it('Tag nur aus der id, nicht aus date (UTC-Mitternacht)', () => {
      // date = UTC-Mitternacht des Folgetags: bliebe das id-Datum unbeachtet, wäre "heute" erreicht
      const e = entry({ id: '2026-10-02', date: new Date(Date.UTC(2026, 9, 3)), workStart: at(2026, 10, 2, 22, 0) });
      expect(canResumeOpenEntry(base(e))).toBe(true);
      const e2 = entry({ id: '2026-10-03', date: new Date(Date.UTC(2026, 9, 2)), workStart: at(2026, 10, 2, 22, 0) });
      expect(canResumeOpenEntry(base(e2))).toBe(false);
    });

    it('DST: Alter über absolute Differenz', () => {
      for (const [y, m, d] of [[2026, 10, 25], [2026, 3, 29], [2026, 11, 1], [2026, 3, 8], [2026, 4, 5]] as const) {
        const start = at(y, m, d, 12, 0);
        const todayId = `${new Date(y, m - 1, d + 1).getFullYear()}-${String(new Date(y, m - 1, d + 1).getMonth() + 1).padStart(2, '0')}-${String(new Date(y, m - 1, d + 1).getDate()).padStart(2, '0')}`;
        const id = `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
        const e = entry({ id, workStart: start });
        const edge = new Date(start.getTime() + OPEN_ENTRY_MAX_NOW_AGE_MS);
        expect(canResumeOpenEntry({ entry: e, now: edge, todayId, todayIsEmpty: true })).toBe(true);
        expect(canResumeOpenEntry({ entry: e, now: new Date(edge.getTime() + 1), todayId, todayIsEmpty: true })).toBe(false);
      }
    });
  });

  describe('formatEntryDay / formatHm', () => {
    it('formatiert den Tag aus der id lokalisiert (Wochentag kurz, Tag, Monat), unabhängig von der Zeitzone', () => {
      // 2026-10-02 ist ein Freitag
      expect(formatEntryDay('2026-10-02', 'de')).toMatch(/^Fr\.?,?\s*2\.\s*10\.?$/);
      expect(formatEntryDay('2026-10-02', 'en')).toContain('Fri');
      expect(formatEntryDay('2026-10-02', 'en')).not.toContain('Fr.');
      expect(formatEntryDay('2026-10-02', 'de')).not.toContain('Fri');
    });

    it('der Kalendertag bleibt auch am Monats- und Jahresrand der id', () => {
      expect(formatEntryDay('2025-12-31', 'en')).toContain('31');
      expect(formatEntryDay('2026-01-01', 'de')).toContain('1');
    });

    it('formatHm: HH:mm mit führenden Nullen', () => {
      expect(formatHm(at(2026, 10, 2, 5, 7, 59))).toBe('05:07');
      expect(formatHm(at(2026, 10, 2, 23, 59))).toBe('23:59');
    });
  });
});
