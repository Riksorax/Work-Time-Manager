import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/utils/insights_utils.dart';

void main() {
  WorkEntryEntity makeEntry(
    DateTime date, {
    int startHour = 8,
    int endHour = 16,
    WorkEntryType type = WorkEntryType.work,
  }) {
    return WorkEntryEntity(
      id: date.toIso8601String(),
      date: date,
      workStart: DateTime(date.year, date.month, date.day, startHour),
      workEnd: DateTime(date.year, date.month, date.day, endHour),
      type: type,
    );
  }

  group('calculateWeekdayAverages', () {
    test('berechnet Durchschnitt und Abweichung je Wochentag', () {
      final entries = [
        // Mittwoch: durchgehend 9h
        makeEntry(DateTime(2024, 1, 3), endHour: 17), // Mi
        makeEntry(DateTime(2024, 1, 10), endHour: 17), // Mi
        // Montag: durchgehend 8h
        makeEntry(DateTime(2024, 1, 1), endHour: 16), // Mo
        makeEntry(DateTime(2024, 1, 8), endHour: 16), // Mo
      ];

      final result = calculateWeekdayAverages(entries);

      expect(result.length, 2);
      final wednesday = result.firstWhere((w) => w.weekday == DateTime.wednesday);
      final monday = result.firstWhere((w) => w.weekday == DateTime.monday);

      expect(wednesday.averageWorkDuration, const Duration(hours: 9));
      expect(monday.averageWorkDuration, const Duration(hours: 8));
      // Gesamtdurchschnitt: (9+9+8+8)/4 = 8,5h -> Mi weicht um +0,5h ab, Mo um -0,5h
      expect(wednesday.deviationFromOverallAverage, const Duration(minutes: 30));
      expect(monday.deviationFromOverallAverage, const Duration(minutes: -30));
    });

    test('ignoriert Urlaub/Krank/Feiertag und Einträge ohne Endzeit', () {
      final entries = [
        makeEntry(DateTime(2024, 1, 1), type: WorkEntryType.vacation),
        WorkEntryEntity(
          id: 'running',
          date: DateTime(2024, 1, 2),
          workStart: DateTime(2024, 1, 2, 8),
        ),
      ];

      expect(calculateWeekdayAverages(entries), isEmpty);
    });

    test('leere Liste liefert leeres Ergebnis', () {
      expect(calculateWeekdayAverages([]), isEmpty);
    });
  });

  group('detectOvertimeStreak', () {
    const monFri = [1, 2, 3, 4, 5];
    const target = Duration(hours: 8);

    test('erkennt eine laufende Serie über dem Soll', () {
      final entries = [
        makeEntry(DateTime(2024, 1, 1), endHour: 17), // Mo, 9h
        makeEntry(DateTime(2024, 1, 2), endHour: 17), // Di, 9h
        makeEntry(DateTime(2024, 1, 3), endHour: 17), // Mi, 9h
      ];

      final status = detectOvertimeStreak(
        entries: entries,
        workdays: monFri,
        dailyTarget: target,
        warningThresholdDays: 3,
      );

      expect(status.currentStreak, 3);
      expect(status.longestStreak, 3);
      expect(status.isWarning, isTrue);
    });

    test('ein Tag exakt am Soll unterbricht die Serie', () {
      final entries = [
        makeEntry(DateTime(2024, 1, 1), endHour: 17), // Mo, 9h
        makeEntry(DateTime(2024, 1, 2), endHour: 16), // Di, exakt 8h
        makeEntry(DateTime(2024, 1, 3), endHour: 17), // Mi, 9h
      ];

      final status = detectOvertimeStreak(entries: entries, workdays: monFri, dailyTarget: target);

      expect(status.currentStreak, 1);
      expect(status.longestStreak, 1);
    });

    test('Wochenende unterbricht die Serie nicht (kein Vertragstag)', () {
      final entries = [
        makeEntry(DateTime(2024, 1, 5), endHour: 17), // Fr, 9h
        // Sa/So: kein Eintrag, aber auch kein Vertragstag
        makeEntry(DateTime(2024, 1, 8), endHour: 17), // Mo, 9h
      ];

      final status = detectOvertimeStreak(entries: entries, workdays: monFri, dailyTarget: target);

      expect(status.currentStreak, 2);
    });

    test('fehlender Eintrag an einem Vertragstag unterbricht die Serie', () {
      final entries = [
        makeEntry(DateTime(2024, 1, 1), endHour: 17), // Mo, 9h
        // Di fehlt komplett
        makeEntry(DateTime(2024, 1, 3), endHour: 17), // Mi, 9h
      ];

      final status = detectOvertimeStreak(entries: entries, workdays: monFri, dailyTarget: target);

      expect(status.currentStreak, 1);
      expect(status.longestStreak, 1);
    });

    test('leere Liste liefert keine Warnung', () {
      final status = detectOvertimeStreak(entries: [], workdays: monFri, dailyTarget: target);
      expect(status.currentStreak, 0);
      expect(status.isWarning, isFalse);
    });
  });

  group('buildStartTimeHeatmap', () {
    const target = Duration(hours: 8);

    test('gruppiert nach Startstunde und berechnet die durchschnittliche Abweichung', () {
      final entries = [
        makeEntry(DateTime(2024, 1, 1), startHour: 7, endHour: 16), // 9h, Start 7 Uhr
        makeEntry(DateTime(2024, 1, 2), startHour: 7, endHour: 15), // 8h, Start 7 Uhr
        makeEntry(DateTime(2024, 1, 3), startHour: 9, endHour: 16), // 7h, Start 9 Uhr
        makeEntry(DateTime(2024, 1, 4), startHour: 9, endHour: 16), // 7h, Start 9 Uhr
      ];

      final buckets = buildStartTimeHeatmap(entries: entries, dailyTarget: target, minSampleCount: 2);

      expect(buckets.length, 2);
      final sevenOClock = buckets.firstWhere((b) => b.startHour == 7);
      final nineOClock = buckets.firstWhere((b) => b.startHour == 9);

      expect(sevenOClock.averageOvertime, const Duration(minutes: 30)); // (9h+8h)/2 - 8h
      expect(nineOClock.averageOvertime, const Duration(hours: -1)); // 7h - 8h
      expect(sevenOClock.sampleCount, 2);
    });

    test('Buckets unter minSampleCount werden ausgeschlossen', () {
      final entries = [
        makeEntry(DateTime(2024, 1, 1), startHour: 7, endHour: 16),
      ];

      final buckets = buildStartTimeHeatmap(entries: entries, dailyTarget: target, minSampleCount: 2);

      expect(buckets, isEmpty);
    });

    test('Ergebnis ist nach Startstunde sortiert', () {
      final entries = [
        makeEntry(DateTime(2024, 1, 1), startHour: 9, endHour: 16),
        makeEntry(DateTime(2024, 1, 2), startHour: 9, endHour: 16),
        makeEntry(DateTime(2024, 1, 3), startHour: 6, endHour: 14),
        makeEntry(DateTime(2024, 1, 4), startHour: 6, endHour: 14),
      ];

      final buckets = buildStartTimeHeatmap(entries: entries, dailyTarget: target, minSampleCount: 2);

      expect(buckets.map((b) => b.startHour).toList(), [6, 9]);
    });
  });
}
