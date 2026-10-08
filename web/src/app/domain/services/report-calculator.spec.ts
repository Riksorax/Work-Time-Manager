import { getIsoWeekNumber, calculateDailyStat, calculateWeeklyReport, calculateMonthlyReport } from './report-calculator';
import { DEFAULT_SETTINGS, WorkEntry, WorkEntryType, UserSettings } from '../../shared/models/index';

// 8h daily target (40h / 5d)
const DAILY_MS = 8 * 3600000;

function makeWorkEntry(overrides: Partial<WorkEntry> & { date: Date }): WorkEntry {
  // Defaults zuerst, danach die Overrides — das abschließende Spread gewinnt.
  // Die Felder aus overrides hier zusätzlich einzeln aufzuführen wäre wirkungslos.
  return {
    id: crypto.randomUUID(),
    breaks: [],
    isManuallyEntered: false,
    description: undefined,
    type: WorkEntryType.Work,
    ...overrides,
  };
}

function d(year: number, month: number, day: number, h = 0, min = 0): Date {
  return new Date(year, month - 1, day, h, min);
}

describe('ReportCalculatorService', () => {

  // ─── getIsoWeekNumber ───────────────────────────────────────────────────────

  describe('getIsoWeekNumber', () => {
    it('returns 1 for 2024-01-01 (Monday, first week)', () => {
      expect(getIsoWeekNumber(d(2024, 1, 1))).toBe(1);
    });

    it('returns 1 for 2024-01-07 (Sunday, still week 1)', () => {
      expect(getIsoWeekNumber(d(2024, 1, 7))).toBe(1);
    });

    it('returns 2 for 2024-01-08 (Monday, second week)', () => {
      expect(getIsoWeekNumber(d(2024, 1, 8))).toBe(2);
    });

    it('returns 52 for 2023-12-31 (last week of 2023)', () => {
      expect(getIsoWeekNumber(d(2023, 12, 31))).toBe(52);
    });

    it('returns 1 for 2026-01-01 (belongs to week 1 of 2026)', () => {
      // Jan 1, 2026 is Thursday → belongs to week 1
      expect(getIsoWeekNumber(d(2026, 1, 1))).toBe(1);
    });

    it('returns 53 for 2015-12-31 (year with week 53)', () => {
      // 2015 had 53 ISO weeks
      expect(getIsoWeekNumber(d(2015, 12, 31))).toBe(53);
    });

    // Feste Daten, unabhaengig von Prozess-Zeitzone (lokale Kalenderfelder).
    // Montage direkt nach Sommerzeit-Umstellung waren frueher um eine Woche zu klein.
    it.each([
      [2026, 3, 30, 14],  // Mo nach Umstellung auf Sommerzeit
      [2026, 8, 31, 36],  // Mo in Sommerzeit
      [2026, 10, 26, 44], // Mo nach Rueckstellung auf Winterzeit
      [2026, 3, 29, 13],  // So (Umstellungstag)
      [2026, 10, 25, 43], // So (Rueckstellungstag)
      [2025, 3, 31, 14],
      [2025, 10, 27, 44],
    ])('KW fuer %i-%i-%i ist %i', (y, m, day, kw) => {
      expect(getIsoWeekNumber(d(y, m, day))).toBe(kw);
    });

    it.each([
      [2024, 12, 29, 52], [2024, 12, 30, 1], [2025, 1, 5, 1], [2025, 1, 6, 2],
      [2025, 12, 28, 52], [2025, 12, 29, 1], [2026, 1, 4, 1], [2026, 1, 5, 2],
      [2026, 12, 31, 53], [2027, 1, 1, 53], [2027, 1, 3, 53], [2027, 1, 4, 1],
      [2020, 12, 31, 53], [2021, 1, 1, 53], [2021, 1, 3, 53], [2021, 1, 4, 1],
      [2015, 12, 28, 53], [2016, 1, 3, 53], [2016, 1, 4, 1],
    ])('Jahreswechsel %i-%i-%i ist KW %i', (y, m, day, kw) => {
      expect(getIsoWeekNumber(d(y, m, day))).toBe(kw);
    });

    it('Mo-So einer Woche haben dieselbe KW (rund um beide Umstellungen)', () => {
      for (const [y, m, day] of [[2026, 3, 23], [2026, 3, 30], [2026, 10, 19], [2026, 10, 26]]) {
        const kws = new Set<number>();
        for (let i = 0; i < 7; i++) kws.add(getIsoWeekNumber(d(y, m, day + i)));
        expect(kws.size).toBe(1);
      }
    });

    it('ist unabhaengig von der Uhrzeit', () => {
      expect(getIsoWeekNumber(d(2026, 8, 31, 0, 0))).toBe(36);
      expect(getIsoWeekNumber(d(2026, 8, 31, 23, 59))).toBe(36);
      expect(getIsoWeekNumber(d(2026, 9, 6, 23, 59))).toBe(36);
    });

    it('jeder Tag 2020-2030: KW stimmt mit Donnerstag-Methode ueberein und waechst woechentlich', () => {
      let prev = -1;
      for (let t = Date.UTC(2020, 0, 1); t < Date.UTC(2031, 0, 1); t += 86400000) {
        const u = new Date(t);
        const local = new Date(u.getUTCFullYear(), u.getUTCMonth(), u.getUTCDate());
        const wd = u.getUTCDay() === 0 ? 7 : u.getUTCDay();
        const thu = new Date(Date.UTC(u.getUTCFullYear(), u.getUTCMonth(), u.getUTCDate() + 4 - wd));
        const expected = Math.floor((thu.getTime() - Date.UTC(thu.getUTCFullYear(), 0, 1)) / 86400000 / 7) + 1;
        const kw = getIsoWeekNumber(local);
        expect(kw).toBe(expected);
        if (wd === 1) prev = kw;
        else if (prev >= 0) expect(kw).toBe(prev);
      }
    });
  });

  describe('calculateWeeklyReport Wochengrenzen (DST)', () => {
    it.each([
      [2026, 3, 30], [2026, 3, 29], [2026, 4, 1], [2026, 10, 25], [2026, 10, 26], [2026, 10, 28],
    ])('%i-%i-%i: Woche beginnt Montag 0:00 und endet Sonntag (Kalendertage)', (y, m, day) => {
      const r = calculateWeeklyReport([], d(y, m, day), DEFAULT_SETTINGS);
      expect(r.start.getDay()).toBe(1);
      expect(r.end.getDay()).toBe(0);
      expect(r.start.getHours()).toBe(0);
      expect(r.end.getHours()).toBe(0);
      expect(r.weekNumber).toBe(getIsoWeekNumber(r.start));
      expect(getIsoWeekNumber(r.end)).toBe(r.weekNumber);
    });
  });

  // ─── calculateDailyStat ────────────────────────────────────────────────────

  describe('calculateDailyStat', () => {
    it('returns zeros for empty entry list', () => {
      const stat = calculateDailyStat([], d(2026, 4, 21), DEFAULT_SETTINGS);
      expect(stat.target).toBe(DAILY_MS);
      expect(stat.worked).toBe(0);
      expect(stat.overtime).toBe(-DAILY_MS);
    });

    it('calculates net work (gross − breaks) for a normal work entry', () => {
      const entries: WorkEntry[] = [
        makeWorkEntry({
          date: d(2026, 4, 21),
          workStart: d(2026, 4, 21, 8),
          workEnd:   d(2026, 4, 21, 17),
          breaks: [{
            id: '1',
            name: 'Pause',
            start: d(2026, 4, 21, 12),
            end:   d(2026, 4, 21, 12, 30),
            isAutomatic: false,
          }],
        }),
      ];
      const stat = calculateDailyStat(entries, d(2026, 4, 21), DEFAULT_SETTINGS);
      const expected = 9 * 3600000 - 30 * 60000; // 9h − 30min Pause = 8,5h
      expect(stat.worked).toBe(expected);
    });

    it('sets worked = target for Vacation entry', () => {
      const entries: WorkEntry[] = [
        makeWorkEntry({
          date: d(2026, 4, 21),
          type: WorkEntryType.Vacation,
        }),
      ];
      const stat = calculateDailyStat(entries, d(2026, 4, 21), DEFAULT_SETTINGS);
      expect(stat.worked).toBe(stat.target);
      expect(stat.overtime).toBe(0);
    });

    it('sets worked = target for Sick entry', () => {
      const entries: WorkEntry[] = [
        makeWorkEntry({
          date: d(2026, 4, 21),
          type: WorkEntryType.Sick,
        }),
      ];
      const stat = calculateDailyStat(entries, d(2026, 4, 21), DEFAULT_SETTINGS);
      expect(stat.worked).toBe(stat.target);
      expect(stat.overtime).toBe(0);
    });

    it('sets worked = target for Holiday entry', () => {
      const entries: WorkEntry[] = [
        makeWorkEntry({
          date: d(2026, 4, 21),
          type: WorkEntryType.Holiday,
        }),
      ];
      const stat = calculateDailyStat(entries, d(2026, 4, 21), DEFAULT_SETTINGS);
      expect(stat.worked).toBe(stat.target);
      expect(stat.overtime).toBe(0);
    });

    it('includes manualOvertimeMinutes in overtime', () => {
      const entries: WorkEntry[] = [
        makeWorkEntry({
          date: d(2026, 4, 21),
          workStart: d(2026, 4, 21, 8),
          workEnd:   d(2026, 4, 21, 16), // exact 8h
          manualOvertimeMinutes: 30,
        }),
      ];
      const stat = calculateDailyStat(entries, d(2026, 4, 21), DEFAULT_SETTINGS);
      expect(stat.overtime).toBe(30 * 60000);
    });

    it('sets target = 0 for extra day beyond workdays', () => {
      // Mon–Fri already filled (5 days, workdays = [1..5])
      // Saturday → target should be 0
      const monday = d(2026, 4, 20);
      const saturday = d(2026, 4, 25);
      const entries: WorkEntry[] = [
        makeWorkEntry({ date: d(2026, 4, 20), workStart: d(2026, 4, 20, 8), workEnd: d(2026, 4, 20, 16) }),
        makeWorkEntry({ date: d(2026, 4, 21), workStart: d(2026, 4, 21, 8), workEnd: d(2026, 4, 21, 16) }),
        makeWorkEntry({ date: d(2026, 4, 22), workStart: d(2026, 4, 22, 8), workEnd: d(2026, 4, 22, 16) }),
        makeWorkEntry({ date: d(2026, 4, 23), workStart: d(2026, 4, 23, 8), workEnd: d(2026, 4, 23, 16) }),
        makeWorkEntry({ date: d(2026, 4, 24), workStart: d(2026, 4, 24, 8), workEnd: d(2026, 4, 24, 16) }),
        makeWorkEntry({ date: saturday,        workStart: d(2026, 4, 25, 8), workEnd: d(2026, 4, 25, 16) }),
      ];
      void monday;
      const stat = calculateDailyStat(entries, saturday, DEFAULT_SETTINGS);
      expect(stat.target).toBe(0);
      expect(stat.overtime).toBeGreaterThan(0);
    });

    it('Di-Sa-Vertrag: Montag hat kein Soll, Samstag hat volles Soll (Bug-Fix #217)', () => {
      const tueSatSettings: UserSettings = { ...DEFAULT_SETTINGS, workdays: [2, 3, 4, 5, 6] };
      const monday = d(2026, 4, 20);
      const saturday = d(2026, 4, 25);

      const mondayStat = calculateDailyStat([], monday, tueSatSettings);
      expect(mondayStat.target).toBe(0);

      const saturdayStat = calculateDailyStat([], saturday, tueSatSettings);
      expect(saturdayStat.target).toBe(8 * 3600000);
    });
  });

  // ─── calculateWeeklyReport ─────────────────────────────────────────────────

  describe('calculateWeeklyReport', () => {
    it('returns zero report for empty entries', () => {
      const report = calculateWeeklyReport([], d(2026, 4, 21), DEFAULT_SETTINGS);
      expect(report.totalWorked).toBe(0);
      expect(report.overtime).toBe(0);
      expect(report.workDays).toBe(0);
    });

    it('calculates correct week boundaries (Mon–Sun)', () => {
      const report = calculateWeeklyReport([], d(2026, 4, 22), DEFAULT_SETTINGS); // Wednesday
      expect(report.start.getDay()).toBe(1); // Monday
      expect(report.end.getDay()).toBe(0);   // Sunday
    });

    it('calculates overtime for a full week', () => {
      const entries: WorkEntry[] = [1, 2, 3, 4, 5].map(day =>
        makeWorkEntry({
          date: d(2026, 4, day + 19), // Mon(20)–Fri(24)
          workStart: d(2026, 4, day + 19, 8),
          workEnd:   d(2026, 4, day + 19, 17), // 9h per day
        })
      );
      const report = calculateWeeklyReport(entries, d(2026, 4, 21), DEFAULT_SETTINGS);
      // 5 × 9h = 45h worked, 0 breaks, target 5 × 8h = 40h → overtime = 5h
      expect(report.totalWorked).toBe(5 * 9 * 3600000);
      expect(report.overtime).toBe(5 * 3600000);
      expect(report.workDays).toBe(5);
    });

    it('treats vacation days as target-hours contribution', () => {
      const entries: WorkEntry[] = [
        makeWorkEntry({ date: d(2026, 4, 21), type: WorkEntryType.Vacation }),
      ];
      const report = calculateWeeklyReport(entries, d(2026, 4, 21), DEFAULT_SETTINGS);
      // 1 day, worked = target = 8h, overtime = 0
      expect(report.overtime).toBe(0);
      expect(report.workDays).toBe(1);
    });

    it('returns correct avgPerDay', () => {
      const entries: WorkEntry[] = [
        makeWorkEntry({ date: d(2026, 4, 21), workStart: d(2026, 4, 21, 8), workEnd: d(2026, 4, 21, 16) }),
        makeWorkEntry({ date: d(2026, 4, 22), workStart: d(2026, 4, 22, 8), workEnd: d(2026, 4, 22, 17) }),
      ];
      const report = calculateWeeklyReport(entries, d(2026, 4, 21), DEFAULT_SETTINGS);
      // net: 8h + 9h = 17h, 2 days → avg = 8.5h
      expect(report.avgPerDay).toBeCloseTo(8.5 * 3600000, 0);
    });
  });

  // ─── calculateMonthlyReport ────────────────────────────────────────────────

  describe('calculateMonthlyReport', () => {
    it('returns zero report for empty entries', () => {
      const report = calculateMonthlyReport([], d(2026, 4, 1), DEFAULT_SETTINGS, 0);
      expect(report.totalWorked).toBe(0);
      expect(report.monthlyOvertime).toBe(0);
      expect(report.totalOvertime).toBe(0);
    });

    it('includes stored overtime in totalOvertime', () => {
      const stored = 2 * 3600000; // 2h stored
      const report = calculateMonthlyReport([], d(2026, 4, 1), DEFAULT_SETTINGS, stored);
      expect(report.totalOvertime).toBe(stored);
    });

    it('groups days into weeks and only counts days matching workdays', () => {
      // 6 work entries in a single week (Mon-Sat), only Mon-Fri are contract workdays → 5 count
      const entries: WorkEntry[] = [1, 2, 3, 4, 5, 6].map(day =>
        makeWorkEntry({
          date: d(2026, 4, day + 19), // Mon(20)–Sat(25)
          workStart: d(2026, 4, day + 19, 8),
          workEnd:   d(2026, 4, day + 19, 16),
        })
      );
      const report = calculateMonthlyReport(entries, d(2026, 4, 1), DEFAULT_SETTINGS, 0);
      // effectiveTotalWorkDays = 5 (Mon-Fri, Saturday excluded) → monthTarget = 5 × 8h = 40h
      const monthTarget = 5 * DAILY_MS;
      const netWork = 6 * 8 * 3600000; // 6 × 8h, no breaks
      expect(report.monthlyOvertime).toBe(netWork - monthTarget);
    });

    it('sets month to first of month', () => {
      const report = calculateMonthlyReport([], d(2026, 4, 15), DEFAULT_SETTINGS, 0);
      expect(report.month.getDate()).toBe(1);
      expect(report.month.getMonth()).toBe(3); // April = index 3
    });

    it('includes per-week summary in weeks array', () => {
      const entries: WorkEntry[] = [
        makeWorkEntry({ date: d(2026, 4, 21), workStart: d(2026, 4, 21, 8), workEnd: d(2026, 4, 21, 16) }),
      ];
      const report = calculateMonthlyReport(entries, d(2026, 4, 1), DEFAULT_SETTINGS, 0);
      expect(report.weeks.length).toBe(1);
      expect(report.weeks[0].totalWorked).toBe(8 * 3600000);
    });
  });
});
