import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/utils/home_office_stats.dart';
import 'package:flutter_work_time/domain/utils/yearly_report_utils.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Eintrag am Kalendertag [day] im Juni 2026 (Id `yyyy-MM-dd`, feste Zeiten,
/// keine Uhr und keine Zone beteiligt).
WorkEntryEntity entry(
  int day, {
  bool homeOffice = false,
  WorkEntryType type = WorkEntryType.work,
  bool withStart = true,
  bool withEnd = true,
}) {
  return WorkEntryEntity(
    id: '2026-06-${day.toString().padLeft(2, '0')}',
    date: DateTime(2026, 6, day),
    workStart: withStart ? DateTime(2026, 6, day, 8) : null,
    workEnd: withStart && withEnd ? DateTime(2026, 6, day, 16) : null,
    type: type,
    isHomeOffice: homeOffice,
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('de', null);
    await initializeDateFormatting('en', null);
  });

  group('calculateHomeOfficeStats', () {
    test('leere Liste: alles 0, Anteil null', () {
      final s = calculateHomeOfficeStats(const []);
      expect(s.homeOfficeDays, 0);
      expect(s.officeDays, 0);
      expect(s.totalDays, 0);
      expect(s.ratio, isNull);
      expect(s.homeOfficeDates, isEmpty);
    });

    test('nur Büro-Tage: Anteil 0,0 (nicht null)', () {
      final s = calculateHomeOfficeStats([entry(1), entry(2)]);
      expect(s.officeDays, 2);
      expect(s.homeOfficeDays, 0);
      expect(s.ratio, 0.0);
    });

    test('nur Home-Office: Anteil 1,0', () {
      final s = calculateHomeOfficeStats(
          [entry(1, homeOffice: true), entry(2, homeOffice: true)]);
      expect(s.homeOfficeDays, 2);
      expect(s.officeDays, 0);
      expect(s.ratio, 1.0);
    });

    test('gemischt: 3 Tage, 1 Home-Office', () {
      final s = calculateHomeOfficeStats(
          [entry(1), entry(2, homeOffice: true), entry(3)]);
      expect(s.homeOfficeDays, 1);
      expect(s.officeDays, 2);
      expect(s.totalDays, 3);
      expect(s.ratio, closeTo(1 / 3, 1e-9));
    });

    test('Urlaub, Krank, Feiertag zählen auch mit Flag nicht', () {
      final s = calculateHomeOfficeStats([
        entry(1, type: WorkEntryType.vacation, homeOffice: true),
        entry(2, type: WorkEntryType.sick, homeOffice: true),
        entry(3, type: WorkEntryType.holiday, homeOffice: true),
        entry(4, type: WorkEntryType.vacation),
      ]);
      expect(s.totalDays, 0);
      expect(s.homeOfficeDays, 0);
      expect(s.ratio, isNull);
    });

    test('work ohne workStart zählt nicht, auch mit Flag', () {
      final s = calculateHomeOfficeStats(
          [entry(1, withStart: false, homeOffice: true), entry(2)]);
      expect(s.homeOfficeDays, 0);
      expect(s.totalDays, 1);
    });

    test('offener Eintrag (Start ohne Ende) zählt', () {
      final s = calculateHomeOfficeStats([entry(1, withEnd: false)]);
      expect(s.totalDays, 1);
    });

    test('zwei Einträge am selben Kalendertag zählen einmal', () {
      final s = calculateHomeOfficeStats([
        entry(5),
        entry(5, homeOffice: true),
      ]);
      expect(s.totalDays, 1);
      expect(s.homeOfficeDays, 1);
      expect(s.officeDays, 0);
      expect(s.homeOfficeDates, [DateTime(2026, 6, 5)]);
    });

    test('homeOfficeDates aufsteigend sortiert, lokale Mitternacht', () {
      final s = calculateHomeOfficeStats([
        entry(20, homeOffice: true),
        entry(3, homeOffice: true),
        entry(11),
        entry(9, homeOffice: true),
      ]);
      expect(s.homeOfficeDates, [
        DateTime(2026, 6, 3),
        DateTime(2026, 6, 9),
        DateTime(2026, 6, 20),
      ]);
      for (final d in s.homeOfficeDates) {
        expect(d.isUtc, isFalse);
        expect(d.hour, 0);
      }
    });

    test('Tag kommt aus entryDay: Id gewinnt gegen inkonsistentes date', () {
      // Id 5. Juni, date (fälschlich) 4. Juni: gezählt wird der 5.
      final e = WorkEntryEntity(
        id: '2026-06-05',
        date: DateTime(2026, 6, 4),
        workStart: DateTime(2026, 6, 5, 8),
        isHomeOffice: true,
      );
      final s = calculateHomeOfficeStats([e]);
      expect(s.homeOfficeDates, [DateTime(2026, 6, 5)]);
    });

    test('totalDays entspricht calculateMonthSummary.workDays', () {
      final entries = [
        entry(1),
        entry(2, homeOffice: true),
        entry(2),
        entry(3, withEnd: false),
      ];
      final summary = calculateMonthSummary(
        month: 6,
        entriesForMonth: entries,
        workdays: const [1, 2, 3, 4, 5],
        targetWeeklyHours: 40,
      );
      expect(calculateHomeOfficeStats(entries).totalDays, summary.workDays);
    });
  });

  group('formatHomeOfficeRatio', () {
    String norm(String s) => s.replaceAll(' ', ' ');

    test('null -> Strich', () {
      expect(formatHomeOfficeRatio(null, 'de'), '-');
      expect(formatHomeOfficeRatio(null, 'en'), '-');
    });

    test('de: Dezimalkomma und Prozentzeichen', () {
      expect(norm(formatHomeOfficeRatio(1 / 3, 'de')), '33,3 %');
      expect(norm(formatHomeOfficeRatio(0, 'de')), '0,0 %');
      expect(norm(formatHomeOfficeRatio(1, 'de')), '100,0 %');
    });

    test('en: Dezimalpunkt', () {
      expect(norm(formatHomeOfficeRatio(1 / 3, 'en')), '33.3%');
      expect(norm(formatHomeOfficeRatio(1, 'en')), '100.0%');
    });
  });
}
