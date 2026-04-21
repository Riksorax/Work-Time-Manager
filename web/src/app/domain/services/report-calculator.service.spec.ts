import { TestBed } from '@angular/core/testing';
import { ReportCalculatorService } from './report-calculator.service';
import { WorkEntry, WorkEntryType, UserSettings } from '../../shared/models/index';

const DEFAULT_SETTINGS: UserSettings = {
  weeklyTargetHours: 40,
  workdaysPerWeek: 5,
  notificationsEnabled: false,
  notificationTime: '08:00',
  notificationDays: [1, 2, 3, 4, 5],
  notifyWorkStart: false,
  notifyWorkEnd: false,
  notifyBreaks: false,
};

// 8h daily target (40h / 5d)
const DAILY_MS = 8 * 3600000;

function makeWorkEntry(overrides: Partial<WorkEntry> & { date: Date }): WorkEntry {
  return {
    id: crypto.randomUUID(),
    date: overrides.date,
    workStart: overrides.workStart,
    workEnd: overrides.workEnd,
    breaks: overrides.breaks ?? [],
    manualOvertimeMinutes: overrides.manualOvertimeMinutes,
    isManuallyEntered: false,
    description: undefined,
    type: overrides.type ?? WorkEntryType.Work,
    ...overrides,
  };
}

function d(year: number, month: number, day: number, h = 0, min = 0): Date {
  return new Date(year, month - 1, day, h, min);
}

describe('ReportCalculatorService', () => {
  let svc: ReportCalculatorService;

  beforeEach(() => {
    TestBed.configureTestingModule({});
    svc = TestBed.inject(ReportCalculatorService);
  });

  // ─── getIsoWeekNumber ───────────────────────────────────────────────────────

  describe('getIsoWeekNumber', () => {
    it('returns 1 for 2024-01-01 (Monday, first week)', () => {
      expect(svc.getIsoWeekNumber(d(2024, 1, 1))).toBe(1);
    });

    it('returns 1 for 2024-01-07 (Sunday, still week 1)', () => {
      expect(svc.getIsoWeekNumber(d(2024, 1, 7))).toBe(1);
    });

    it('returns 2 for 2024-01-08 (Monday, second week)', () => {
      expect(svc.getIsoWeekNumber(d(2024, 1, 8))).toBe(2);
    });

    it('returns 52 for 2023-12-31 (last week of 2023)', () => {
      expect(svc.getIsoWeekNumber(d(2023, 12, 31))).toBe(52);
    });

    it('returns 1 for 2026-01-01 (belongs to week 1 of 2026)', () => {
      // Jan 1, 2026 is Thursday → belongs to week 1
      expect(svc.getIsoWeekNumber(d(2026, 1, 1))).toBe(1);
    });

    it('returns 53 for 2015-12-31 (year with week 53)', () => {
      // 2015 had 53 ISO weeks
      expect(svc.getIsoWeekNumber(d(2015, 12, 31))).toBe(53);
    });
  });

  // ─── calculateDailyStat ────────────────────────────────────────────────────

  describe('calculateDailyStat', () => {
    it('returns zeros for empty entry list', () => {
      const stat = svc.calculateDailyStat([], d(2026, 4, 21), DEFAULT_SETTINGS);
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
      const stat = svc.calculateDailyStat(entries, d(2026, 4, 21), DEFAULT_SETTINGS);
      const expected = 8.5 * 3600000 - 30 * 60000; // 9h − 30min break
      expect(stat.worked).toBe(expected);
    });

    it('sets worked = target for Vacation entry', () => {
      const entries: WorkEntry[] = [
        makeWorkEntry({
          date: d(2026, 4, 21),
          type: WorkEntryType.Vacation,
        }),
      ];
      const stat = svc.calculateDailyStat(entries, d(2026, 4, 21), DEFAULT_SETTINGS);
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
      const stat = svc.calculateDailyStat(entries, d(2026, 4, 21), DEFAULT_SETTINGS);
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
      const stat = svc.calculateDailyStat(entries, d(2026, 4, 21), DEFAULT_SETTINGS);
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
      const stat = svc.calculateDailyStat(entries, d(2026, 4, 21), DEFAULT_SETTINGS);
      expect(stat.overtime).toBe(30 * 60000);
    });

    it('sets target = 0 for extra day beyond workdaysPerWeek', () => {
      // Mon–Fri already filled (5 days, workdaysPerWeek = 5)
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
      const stat = svc.calculateDailyStat(entries, saturday, DEFAULT_SETTINGS);
      expect(stat.target).toBe(0);
      expect(stat.overtime).toBeGreaterThan(0);
    });
  });

  // ─── calculateWeeklyReport ─────────────────────────────────────────────────

  describe('calculateWeeklyReport', () => {
    it('returns zero report for empty entries', () => {
      const report = svc.calculateWeeklyReport([], d(2026, 4, 21), DEFAULT_SETTINGS);
      expect(report.totalWorked).toBe(0);
      expect(report.overtime).toBe(0);
      expect(report.workDays).toBe(0);
    });

    it('calculates correct week boundaries (Mon–Sun)', () => {
      const report = svc.calculateWeeklyReport([], d(2026, 4, 22), DEFAULT_SETTINGS); // Wednesday
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
      const report = svc.calculateWeeklyReport(entries, d(2026, 4, 21), DEFAULT_SETTINGS);
      // 5 × 9h = 45h worked, 0 breaks, target 5 × 8h = 40h → overtime = 5h
      expect(report.totalWorked).toBe(5 * 9 * 3600000);
      expect(report.overtime).toBe(5 * 3600000);
      expect(report.workDays).toBe(5);
    });

    it('treats vacation days as target-hours contribution', () => {
      const entries: WorkEntry[] = [
        makeWorkEntry({ date: d(2026, 4, 21), type: WorkEntryType.Vacation }),
      ];
      const report = svc.calculateWeeklyReport(entries, d(2026, 4, 21), DEFAULT_SETTINGS);
      // 1 day, worked = target = 8h, overtime = 0
      expect(report.overtime).toBe(0);
      expect(report.workDays).toBe(1);
    });

    it('returns correct avgPerDay', () => {
      const entries: WorkEntry[] = [
        makeWorkEntry({ date: d(2026, 4, 21), workStart: d(2026, 4, 21, 8), workEnd: d(2026, 4, 21, 16) }),
        makeWorkEntry({ date: d(2026, 4, 22), workStart: d(2026, 4, 22, 8), workEnd: d(2026, 4, 22, 17) }),
      ];
      const report = svc.calculateWeeklyReport(entries, d(2026, 4, 21), DEFAULT_SETTINGS);
      // net: 8h + 9h = 17h, 2 days → avg = 8.5h
      expect(report.avgPerDay).toBeCloseTo(8.5 * 3600000, 0);
    });
  });

  // ─── calculateMonthlyReport ────────────────────────────────────────────────

  describe('calculateMonthlyReport', () => {
    it('returns zero report for empty entries', () => {
      const report = svc.calculateMonthlyReport([], d(2026, 4, 1), DEFAULT_SETTINGS, 0);
      expect(report.totalWorked).toBe(0);
      expect(report.monthlyOvertime).toBe(0);
      expect(report.totalOvertime).toBe(0);
    });

    it('includes stored overtime in totalOvertime', () => {
      const stored = 2 * 3600000; // 2h stored
      const report = svc.calculateMonthlyReport([], d(2026, 4, 1), DEFAULT_SETTINGS, stored);
      expect(report.totalOvertime).toBe(stored);
    });

    it('groups days into weeks and caps each week at workdaysPerWeek', () => {
      // 6 work entries in a single week → capped to 5
      const entries: WorkEntry[] = [1, 2, 3, 4, 5, 6].map(day =>
        makeWorkEntry({
          date: d(2026, 4, day + 19), // Mon(20)–Sat(25)
          workStart: d(2026, 4, day + 19, 8),
          workEnd:   d(2026, 4, day + 19, 16),
        })
      );
      const report = svc.calculateMonthlyReport(entries, d(2026, 4, 1), DEFAULT_SETTINGS, 0);
      // effectiveTotalWorkDays = min(6, 5) = 5 → monthTarget = 5 × 8h = 40h
      const monthTarget = 5 * DAILY_MS;
      const netWork = 6 * 8 * 3600000; // 6 × 8h, no breaks
      expect(report.monthlyOvertime).toBe(netWork - monthTarget);
    });

    it('sets month to first of month', () => {
      const report = svc.calculateMonthlyReport([], d(2026, 4, 15), DEFAULT_SETTINGS, 0);
      expect(report.month.getDate()).toBe(1);
      expect(report.month.getMonth()).toBe(3); // April = index 3
    });

    it('includes per-week summary in weeks array', () => {
      const entries: WorkEntry[] = [
        makeWorkEntry({ date: d(2026, 4, 21), workStart: d(2026, 4, 21, 8), workEnd: d(2026, 4, 21, 16) }),
      ];
      const report = svc.calculateMonthlyReport(entries, d(2026, 4, 1), DEFAULT_SETTINGS, 0);
      expect(report.weeks.length).toBe(1);
      expect(report.weeks[0].totalWorked).toBe(8 * 3600000);
    });
  });
});
