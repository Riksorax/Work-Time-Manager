import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/utils/yearly_report_utils.dart';

void main() {
  WorkEntryEntity workEntry(DateTime date, {int hours = 8}) {
    return WorkEntryEntity(
      id: date.toIso8601String(),
      date: date,
      workStart: DateTime(date.year, date.month, date.day, 8),
      workEnd: DateTime(date.year, date.month, date.day, 8 + hours),
    );
  }

  WorkEntryEntity specialEntry(DateTime date, WorkEntryType type) {
    return WorkEntryEntity(id: date.toIso8601String(), date: date, type: type);
  }

  group('calculateMonthSummary', () {
    test('leerer Monat liefert Nullwerte', () {
      final summary = calculateMonthSummary(
        month: 3,
        entriesForMonth: const [],
        workdaysPerWeek: 5,
        targetWeeklyHours: 40,
      );

      expect(summary.month, 3);
      expect(summary.netWorkDuration, Duration.zero);
      expect(summary.overtime, Duration.zero);
      expect(summary.workDays, 0);
      expect(summary.vacationDays, 0);
      expect(summary.sickDays, 0);
      expect(summary.holidayDays, 0);
    });

    test('5 volle 8h-Arbeitstage in einer Woche erfüllen exakt das Soll', () {
      // Mo 2024-01-01 - Fr 2024-01-05
      final entries = List.generate(
        5,
        (i) => workEntry(DateTime(2024, 1, 1 + i)),
      );

      final summary = calculateMonthSummary(
        month: 1,
        entriesForMonth: entries,
        workdaysPerWeek: 5,
        targetWeeklyHours: 40,
      );

      expect(summary.workDays, 5);
      expect(summary.netWorkDuration, const Duration(hours: 40));
      expect(summary.overtime, Duration.zero);
    });

    test('Zusatztag über workdaysPerWeek hinaus zählt voll als Überstunden', () {
      // Mo-Sa (6 Tage) bei einer 5-Tage-Woche
      final entries = List.generate(
        6,
        (i) => workEntry(DateTime(2024, 1, 1 + i)),
      );

      final summary = calculateMonthSummary(
        month: 1,
        entriesForMonth: entries,
        workdaysPerWeek: 5,
        targetWeeklyHours: 40,
      );

      // Soll bleibt bei 40h (5 Tage x 8h), IST ist 48h -> +8h Überstunden
      expect(summary.workDays, 6);
      expect(summary.netWorkDuration, const Duration(hours: 48));
      expect(summary.overtime, const Duration(hours: 8));
    });

    test('Urlaub/Krank/Feiertag werden gezählt, aber nicht als Arbeitstage', () {
      final entries = [
        specialEntry(DateTime(2024, 6, 3), WorkEntryType.vacation),
        specialEntry(DateTime(2024, 6, 4), WorkEntryType.vacation),
        specialEntry(DateTime(2024, 6, 5), WorkEntryType.sick),
        specialEntry(DateTime(2024, 6, 6), WorkEntryType.holiday),
        workEntry(DateTime(2024, 6, 7)),
      ];

      final summary = calculateMonthSummary(
        month: 6,
        entriesForMonth: entries,
        workdaysPerWeek: 5,
        targetWeeklyHours: 40,
      );

      expect(summary.workDays, 1);
      expect(summary.vacationDays, 2);
      expect(summary.sickDays, 1);
      expect(summary.holidayDays, 1);
    });

    test('manuelle Überstunden-Korrektur fließt ein', () {
      final entry = workEntry(DateTime(2024, 2, 1)).copyWith(
        manualOvertime: const Duration(hours: 2),
      );

      final summary = calculateMonthSummary(
        month: 2,
        entriesForMonth: [entry],
        workdaysPerWeek: 5,
        targetWeeklyHours: 40,
      );

      // Soll für 1 Arbeitstag: 8h, IST: 8h + 2h manuell = +2h Überstunden
      expect(summary.overtime, const Duration(hours: 2));
    });
  });
}
