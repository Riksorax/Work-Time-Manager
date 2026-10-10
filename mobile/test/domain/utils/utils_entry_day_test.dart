import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/utils/insights_utils.dart';
import 'package:flutter_work_time/domain/utils/leave_balance_utils.dart';
import 'package:flutter_work_time/domain/utils/open_entry_report_utils.dart';
import 'package:flutter_work_time/domain/utils/overtime_utils.dart';
import 'package:flutter_work_time/domain/utils/yearly_report_utils.dart';

/// Block B (#418), Utils: Der Tag eines Eintrags kommt aus der Id, nicht aus
/// `date`. Fixtures sind **inkonsistent** (Id Montag 2026-10-05, KW 41, `date`
/// am Sonntag 2026-10-04, KW 40), zonenunabhaengig. Uhr: Mo 05.10.2026 12:00.
WorkEntryEntity _mondayWithSundayDate({
  DateTime? start,
  DateTime? end,
  WorkEntryType type = WorkEntryType.work,
}) =>
    WorkEntryEntity(
      id: '2026-10-05',
      date: DateTime(2026, 10, 4),
      workStart: start ?? DateTime(2026, 10, 5, 8),
      workEnd: end,
      type: type,
    );

final _now = DateTime(2026, 10, 5, 12);
const _workdays = [1, 2, 3, 4, 5];

void main() {
  group('overtime_utils', () {
    test('getEffectiveWorkDays zaehlt den Montag (Arbeitstag Mo-Fr)', () {
      final e = _mondayWithSundayDate(end: DateTime(2026, 10, 5, 16));
      expect(getEffectiveWorkDays(entries: [e], workdays: _workdays), 1);
    });

    test('getWeekEntriesForDate: Montag gehoert in KW 41, nicht in KW 40', () {
      final e = _mondayWithSundayDate(end: DateTime(2026, 10, 5, 16));
      expect(getWeekEntriesForDate(DateTime(2026, 10, 5), [e]), [e]);
      expect(getWeekEntriesForDate(DateTime(2026, 10, 11), [e]), [e]);
      expect(getWeekEntriesForDate(DateTime(2026, 10, 4), [e]), isEmpty);
    });

    test('canResumeOpenEntry: der heutige Eintrag ist kein Vortag', () {
      final e = _mondayWithSundayDate();
      expect(
          canResumeOpenEntry(entry: e, now: _now, todayIsEmpty: true), isFalse);
    });

    test('canResumeOpenEntry: der Vortag laut Id ist fortsetzbar', () {
      final e = WorkEntryEntity(
        id: '2026-10-04',
        date: DateTime(2026, 10, 5), // inkonsistent, wuerde "heute" sein
        workStart: DateTime(2026, 10, 4, 22),
      );
      expect(
          canResumeOpenEntry(entry: e, now: _now, todayIsEmpty: true), isTrue);
    });
  });

  group('open_entry_report_utils', () {
    test('isOpenBeforeToday: heutiger offener Eintrag ist nicht "vor heute"',
        () {
      expect(isOpenBeforeToday(_mondayWithSundayDate(), _now), isFalse);
    });

    test('isOpenBeforeToday: Vortag laut Id ist "vor heute"', () {
      final e = WorkEntryEntity(
        id: '2026-10-04',
        date: DateTime(2026, 10, 5),
        workStart: DateTime(2026, 10, 4, 22),
      );
      expect(isOpenBeforeToday(e, _now), isTrue);
      expect(reportNetDuration(e, now: _now), Duration.zero);
    });

    test('reportNetDuration: heutiger offener Eintrag zaehlt live', () {
      expect(reportNetDuration(_mondayWithSundayDate(), now: _now),
          const Duration(hours: 4));
    });
  });

  group('leave_balance_utils', () {
    test('Urlaub am 01.01.2026 (Id) zaehlt fuer 2026, nicht fuer 2025', () {
      final e = WorkEntryEntity(
        id: '2026-01-01',
        date: DateTime(2025, 12, 31),
        type: WorkEntryType.vacation,
      );
      expect(calculateLeaveBalance([e], 2026, 30).taken, 1);
      expect(calculateLeaveBalance([e], 2025, 30).taken, 0);
    });
  });

  group('insights_utils', () {
    test('Wochentag-Bucket ist der Montag', () {
      final e = _mondayWithSundayDate(end: DateTime(2026, 10, 5, 16));
      final result = calculateWeekdayAverages([e]);
      expect(result.map((r) => r.weekday), [DateTime.monday]);
    });

    test('Ueberstunden-Streak zaehlt den Montag als Arbeitstag', () {
      final e = _mondayWithSundayDate(end: DateTime(2026, 10, 5, 18));
      final status = detectOvertimeStreak(
        entries: [e],
        workdays: _workdays,
        dailyTarget: const Duration(hours: 8),
      );
      expect(status.currentStreak, 1);
      expect(status.longestStreak, 1);
    });
  });

  group('yearly_report_utils', () {
    test('Montag 05.10. (Id) und Dienstag 06.10. liegen beide in KW 41', () {
      final monday = _mondayWithSundayDate(end: DateTime(2026, 10, 5, 16));
      final tuesday = WorkEntryEntity(
        id: '2026-10-06',
        date: DateTime(2026, 10, 6),
        workStart: DateTime(2026, 10, 6, 8),
        workEnd: DateTime(2026, 10, 6, 16),
      );
      final summary = calculateMonthSummary(
        month: 10,
        entriesForMonth: [monday, tuesday],
        workdays: _workdays,
        targetWeeklyHours: 40,
      );
      expect(summary.workDays, 2);
      // 2 Arbeitstage x 8 h Soll = 16 h, geleistet 16 h.
      expect(summary.overtime, Duration.zero);
    });
  });
}
