import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_work_time/data/models/yearly_leave_report_model.dart';
import 'package:flutter_work_time/domain/entities/yearly_leave_report.dart';

import '../../support/yearly_leave_report_fixture.dart';

void main() {
  group('yearlyLeaveReportFromJson (#284)', () {
    test('liest Summen, zwölf Monate und Zeiträume', () {
      final r = yearlyLeaveReportFromJson(yearlyLeaveReportJson(2026),
          requestedYear: 2026);
      expect(r.year, 2026);
      expect(r.vacationDaysPerYear, 30);
      expect(r.vacationDaysTaken, 14);
      expect(r.vacationDaysRemaining, 16);
      expect(r.sickDays, 4);
      expect(r.months, hasLength(12));
      expect(r.months[1],
          const YearlyLeaveMonth(month: 2, vacationDays: 0, sickDays: 3));
      expect(r.months[7],
          const YearlyLeaveMonth(month: 8, vacationDays: 12, sickDays: 0));
      expect(r.vacationPeriods, [
        LeavePeriod(
            start: DateTime(2026, 8, 3), end: DateTime(2026, 8, 14), days: 12),
        LeavePeriod(
            start: DateTime(2026, 12, 23),
            end: DateTime(2026, 12, 24),
            days: 2),
      ]);
      expect(r.sickPeriods, [
        LeavePeriod(
            start: DateTime(2026, 2, 10), end: DateTime(2026, 2, 12), days: 3),
        LeavePeriod(
            start: DateTime(2026, 11, 3), end: DateTime(2026, 11, 3), days: 1),
      ]);
      expect(r.isEmpty, isFalse);
    });

    test('älteres Backend ohne neue Felder: leere Listen', () {
      final r = yearlyLeaveReportFromJson({
        'year': 2026,
        'vacationDaysPerYear': 30,
        'vacationDaysTaken': 4,
        'vacationDaysRemaining': 26,
        'sickDays': 2,
      }, requestedYear: 2026);
      expect(r.vacationDaysTaken, 4);
      expect(r.sickDays, 2);
      expect(r.months, isEmpty);
      expect(r.vacationPeriods, isEmpty);
      expect(r.sickPeriods, isEmpty);
    });

    test('leere Antwort: Jahr aus der Anfrage, alles 0', () {
      final r = yearlyLeaveReportFromJson({}, requestedYear: 2025);
      expect(r.year, 2025);
      expect(r.vacationDaysPerYear, 0);
      expect(r.vacationDaysTaken, 0);
      expect(r.sickDays, 0);
      expect(r.isEmpty, isTrue);
    });

    test('Monate werden auf 1–12 aufgefüllt, ungültige verworfen', () {
      final r = yearlyLeaveReportFromJson({
        'months': [
          {'month': 3, 'vacationDays': 2, 'sickDays': 1},
          {'month': 13, 'vacationDays': 9, 'sickDays': 9},
          {'month': 0, 'vacationDays': 9, 'sickDays': 9},
          'kaputt',
        ],
      }, requestedYear: 2026);
      expect(r.months.map((m) => m.month), [for (var i = 1; i <= 12; i++) i]);
      expect(r.months[2],
          const YearlyLeaveMonth(month: 3, vacationDays: 2, sickDays: 1));
      expect(r.months.where((m) => m.vacationDays > 0), hasLength(1));
    });

    test('Zeitraum mit ungültigem Datum wird verworfen', () {
      final r = yearlyLeaveReportFromJson({
        'vacationPeriods': [
          {'start': '2026-02-30', 'end': '2026-03-02', 'days': 3},
          {'start': '03.08.2026', 'end': '2026-08-04', 'days': 2},
          {'start': '2026-08-03', 'days': 1},
          {'start': '2026-08-10', 'end': '2026-08-10', 'days': 1},
        ],
      }, requestedYear: 2026);
      expect(r.vacationPeriods, [
        LeavePeriod(
            start: DateTime(2026, 8, 10), end: DateTime(2026, 8, 10), days: 1),
      ]);
    });
  });
}
