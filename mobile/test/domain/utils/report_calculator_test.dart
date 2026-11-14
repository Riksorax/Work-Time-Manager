import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/break_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/utils/report_calculator.dart';

/// Gezielte Fälle der lokalen Berichtsrechnung (#535) zu den Abweichungen,
/// die vor dem Angleichen an das Backend bestanden. Die vollständige
/// Parität prüft `report_calculator_parity_tz_test.dart`.
///
/// Feste Daten: Mo 01.06.2026 … So 07.06.2026 (KW 23).
void main() {
  const fullTime = ReportSettings(
    weeklyTargetHours: 40,
    workdays: [1, 2, 3, 4, 5],
  );

  String id(int m, int d) =>
      '2026-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';

  WorkEntryEntity work(
    int day, {
    int month = 6,
    int startHour = 8,
    int? endHour = 16,
    int breakMinutes = 0,
    Duration? manual,
  }) {
    final start = DateTime(2026, month, day, startHour);
    return WorkEntryEntity(
      id: id(month, day),
      date: DateTime(2026, month, day),
      workStart: start,
      workEnd: endHour == null ? null : DateTime(2026, month, day, endHour),
      breaks: [
        if (breakMinutes > 0)
          BreakEntity(
            id: 'b',
            name: 'Pause',
            start: DateTime(2026, month, day, 12),
            end: DateTime(2026, month, day, 12, breakMinutes),
          ),
      ],
      manualOvertime: manual,
    );
  }

  WorkEntryEntity absence(int day, WorkEntryType type,
          {int month = 6, Duration? manual}) =>
      WorkEntryEntity(
        id: id(month, day),
        date: DateTime(2026, month, day),
        type: type,
        manualOvertime: manual,
      );

  group('1 – Wochenbericht zieht Pausen nur einmal ab', () {
    test('9 h brutto mit 1 h Pause = 8 h netto, keine Überstunden', () {
      final r = calculateWeeklyReport(
        [work(1, endHour: 17, breakMinutes: 60)],
        DateTime(2026, 6, 3),
        fullTime,
      );
      expect(r.totalWorked, const Duration(hours: 9));
      expect(r.totalBreaks, const Duration(hours: 1));
      expect(r.avgPerDayMs, const Duration(hours: 8).inMilliseconds);
      expect(r.overtime, Duration.zero);
      // Tageswerte brutto wie `days[].workedMs` im Backend.
      expect(r.days.single.worked, const Duration(hours: 9));
    });
  });

  group('2 – Urlaub/Krank/Feiertag zählen mit dem Tagessoll', () {
    test('Woche: Urlaub am Mo, Krank am Di, 8 h am Mi', () {
      final r = calculateWeeklyReport(
        [
          absence(1, WorkEntryType.vacation),
          absence(2, WorkEntryType.sick),
          work(3),
        ],
        DateTime(2026, 6, 3),
        fullTime,
      );
      expect(r.totalWorked, const Duration(hours: 24));
      expect(r.workDays, 3);
      expect(r.overtime, Duration.zero);
      expect(
          r.days.map((d) => d.worked), everyElement(const Duration(hours: 8)));
    });

    test('Feiertag am Samstag (freier Tag) bringt sein Soll mit', () {
      final r = calculateWeeklyReport(
        [work(5), absence(6, WorkEntryType.holiday)],
        DateTime(2026, 6, 6),
        fullTime,
      );
      expect(r.workDays, 2);
      expect(r.totalWorked, const Duration(hours: 16));
      expect(r.overtime, Duration.zero);
    });

    test('Monat: Urlaub zählt als Arbeitstag und geleistet', () {
      final r = calculateMonthlyReport(
        [absence(1, WorkEntryType.vacation), work(2)],
        DateTime(2026, 6),
        fullTime,
        Duration.zero,
      );
      expect(r.workDays, 2);
      expect(r.totalWorked, const Duration(hours: 16));
      expect(r.monthlyOvertime, Duration.zero);
    });

    test('Tag: Krank am Sonntag – Soll = geleistet = Tagessoll', () {
      final s = calculateDailyStat(
          [absence(7, WorkEntryType.sick)], DateTime(2026, 6, 7), fullTime);
      expect(s.target, const Duration(hours: 8));
      expect(s.worked, const Duration(hours: 8));
      expect(s.overtime, Duration.zero);
    });
  });

  group('3 – Tages-Überstunden = geleistet − Soll + manuell', () {
    test('Montag 9 h netto → +1 h', () {
      final s = calculateDailyStat([work(1, endHour: 17, breakMinutes: 0)],
          DateTime(2026, 6, 1), fullTime);
      expect(s.target, const Duration(hours: 8));
      expect(s.worked, const Duration(hours: 9));
      expect(s.overtime, const Duration(hours: 1));
    });

    test('Samstag (kein Vertragstag): Soll 0, alles Überstunden', () {
      final s = calculateDailyStat(
          [work(6, endHour: 10)], DateTime(2026, 6, 6), fullTime);
      expect(s.target, Duration.zero);
      expect(s.overtime, const Duration(hours: 2));
    });

    test('manuelle Überstunden kommen dazu', () {
      final s = calculateDailyStat(
          [work(1, manual: const Duration(minutes: 30))],
          DateTime(2026, 6, 1),
          fullTime);
      expect(s.overtime, const Duration(minutes: 30));
    });

    test('Vertragstag ohne Eintrag: −Tagessoll', () {
      final s = calculateDailyStat([], DateTime(2026, 6, 1), fullTime);
      expect(s.overtime, const Duration(hours: -8));
    });
  });

  group('4 – Monats-Gesamtüberstunden = gespeicherter Saldo', () {
    test('Saldo +1,5 h, Monatsüberstunden +1 h → gesamt 1,5 h', () {
      final r = calculateMonthlyReport(
        [work(1, endHour: 17)],
        DateTime(2026, 6),
        fullTime,
        const Duration(minutes: 90),
      );
      expect(r.monthlyOvertime, const Duration(hours: 1));
      expect(r.totalOvertime, const Duration(minutes: 90));
    });
  });

  group('5 – Arbeitstage und Durchschnitte', () {
    test('Woche: Eintrag ohne Ende zählt als Arbeitstag mit 0 h', () {
      final r = calculateWeeklyReport(
        [work(1), work(2, endHour: null)],
        DateTime(2026, 6, 2),
        fullTime,
      );
      expect(r.workDays, 2);
      expect(r.totalWorked, const Duration(hours: 8));
      expect(r.avgPerDayMs, const Duration(hours: 4).inMilliseconds);
      expect(r.overtime, const Duration(hours: -8));
      expect(r.days.map((d) => d.worked),
          [const Duration(hours: 8), Duration.zero]);
    });

    test('Monat: Ø je Woche = netto ÷ ISO-Wochen mit Tagen', () {
      // KW 23 (Mo 01.06.) und KW 24 (Mo 08.06.), je 8 h.
      final r = calculateMonthlyReport(
        [work(1), work(8), work(9, breakMinutes: 30)],
        DateTime(2026, 6),
        fullTime,
        Duration.zero,
      );
      expect(r.workDays, 3);
      final netMs = const Duration(hours: 23, minutes: 30).inMilliseconds;
      expect(r.avgPerDayMs, netMs / 3);
      expect(r.avgPerWeekMs, netMs / 2);
      expect(r.weeks.map((w) => (w.weekNumber, w.totalWorked)), [
        (23, const Duration(hours: 8)),
        (24, const Duration(hours: 16)),
      ]);
    });

    test('Monat ohne Einträge: alles 0, keine Division durch null', () {
      final r = calculateMonthlyReport(
          [], DateTime(2026, 6), fullTime, Duration.zero);
      expect(r.workDays, 0);
      expect(r.avgPerDayMs, 0);
      expect(r.avgPerWeekMs, 0);
      expect(r.weeks, isEmpty);
      expect(r.days, isEmpty);
    });

    test('Monatswochen nach Nummer sortiert (Januar: KW 53 hinter KW 1)', () {
      final r = calculateMonthlyReport(
        [
          WorkEntryEntity(
              id: '2027-01-01',
              date: DateTime(2027, 1, 1),
              type: WorkEntryType.holiday),
          WorkEntryEntity(
              id: '2027-01-04',
              date: DateTime(2027, 1, 4),
              workStart: DateTime(2027, 1, 4, 8),
              workEnd: DateTime(2027, 1, 4, 16)),
        ],
        DateTime(2027, 1),
        fullTime,
        Duration.zero,
      );
      expect(r.weeks.map((w) => w.weekNumber), [1, 53]);
    });
  });

  group('6 – Tagessoll auf die Minute, Perioden-Soll ohne zweite Rundung', () {
    test('37,5 h an 4 Tagen = 562,5 min → 563 min', () {
      expect(
        reportDailyTarget(const ReportSettings(
            weeklyTargetHours: 37.5, workdays: [1, 2, 3, 4])),
        const Duration(minutes: 563),
      );
    });

    test('39 h an 7 Tagen = 334,29 min → 334 min', () {
      expect(
        reportDailyTarget(const ReportSettings(
            weeklyTargetHours: 39, workdays: [1, 2, 3, 4, 5, 6, 7])),
        const Duration(minutes: 334),
      );
    });

    test('keine Arbeitstage: Tagessoll 0', () {
      expect(
          reportDailyTarget(
              const ReportSettings(weeklyTargetHours: 40, workdays: [])),
          Duration.zero);
    });

    test('Wochen-Soll = Tage × gerundetes Tagessoll (2 × 563 = 1126 min)', () {
      const settings =
          ReportSettings(weeklyTargetHours: 37.5, workdays: [1, 2, 3, 4]);
      final r = calculateWeeklyReport(
        [work(1, endHour: 16), work(2, endHour: 16)],
        DateTime(2026, 6, 1),
        settings,
      );
      // 16 h netto − 1126 min Soll; 2 × 562,5 = 1125 min wäre eine Minute weniger.
      expect(r.overtime, const Duration(minutes: 960 - 1126));
    });
  });
}
