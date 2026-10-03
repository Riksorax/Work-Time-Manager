import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/bundesland.dart';
import 'package:flutter_work_time/domain/utils/german_holidays.dart';

import 'german_holidays_fixture.dart';

void main() {
  group('getGermanHolidays - bundesweite Feiertage', () {
    test('enthält alle 9 bundesweiten Feiertage 2024', () {
      final holidays = getGermanHolidays(2024, Bundesland.hamburg);
      // Hamburg hat zusätzlich den Reformationstag -> 10 statt 9.
      expect(holidays, contains(DateTime(2024, 1, 1))); // Neujahr
      expect(holidays,
          contains(DateTime(2024, 3, 29))); // Karfreitag (Ostern 31.3.)
      expect(holidays, contains(DateTime(2024, 4, 1))); // Ostermontag
      expect(holidays, contains(DateTime(2024, 5, 1))); // Tag der Arbeit
      expect(holidays, contains(DateTime(2024, 5, 9))); // Christi Himmelfahrt
      expect(holidays, contains(DateTime(2024, 5, 20))); // Pfingstmontag
      expect(holidays,
          contains(DateTime(2024, 10, 3))); // Tag der Deutschen Einheit
      expect(holidays, contains(DateTime(2024, 12, 25)));
      expect(holidays, contains(DateTime(2024, 12, 26)));
      expect(holidays.length, 10);
    });

    test('Ostersonntag-Berechnung stimmt für 2025 (verifizierter Referenzwert)',
        () {
      // Christi Himmelfahrt = Ostern + 39 Tage. Ostern 2025 ist der 20. April.
      final holidays = getGermanHolidays(2025, Bundesland.hamburg);
      expect(holidays, contains(DateTime(2025, 5, 29))); // Christi Himmelfahrt
      expect(holidays, contains(DateTime(2025, 4, 18))); // Karfreitag
      expect(holidays, contains(DateTime(2025, 4, 21))); // Ostermontag
    });
  });

  group('getGermanHolidays - Zeitumstellung (DST)', () {
    void expectBeweglicheFeiertage(
      int year, {
      required DateTime karfreitag,
      required DateTime ostermontag,
      required DateTime himmelfahrt,
      required DateTime pfingstmontag,
      required DateTime fronleichnam,
    }) {
      final holidays = getGermanHolidays(year, Bundesland.bayern);
      expect(holidays, contains(karfreitag));
      expect(holidays, contains(ostermontag));
      expect(holidays, contains(himmelfahrt));
      expect(holidays, contains(pfingstmontag));
      expect(holidays, contains(fronleichnam));
    }

    test('2024 (Ostern am Umstellungstag)', () {
      expectBeweglicheFeiertage(
        2024,
        karfreitag: DateTime(2024, 3, 29),
        ostermontag: DateTime(2024, 4, 1),
        himmelfahrt: DateTime(2024, 5, 9),
        pfingstmontag: DateTime(2024, 5, 20),
        fronleichnam: DateTime(2024, 5, 30),
      );
    });

    test('2027 (Ostern 28.3.)', () {
      expectBeweglicheFeiertage(
        2027,
        karfreitag: DateTime(2027, 3, 26),
        ostermontag: DateTime(2027, 3, 29),
        himmelfahrt: DateTime(2027, 5, 6),
        pfingstmontag: DateTime(2027, 5, 17),
        fronleichnam: DateTime(2027, 5, 27),
      );
    });

    test('2008 (Ostern 23.3.)', () {
      expectBeweglicheFeiertage(
        2008,
        karfreitag: DateTime(2008, 3, 21),
        ostermontag: DateTime(2008, 3, 24),
        himmelfahrt: DateTime(2008, 5, 1),
        pfingstmontag: DateTime(2008, 5, 12),
        fronleichnam: DateTime(2008, 5, 22),
      );
    });

    test('alle Rückgabe-DateTimes sind lokale Mitternacht', () {
      for (final year in [2008, 2013, 2016, 2024, 2025, 2027, 2035]) {
        for (final land in [Bundesland.bayern, Bundesland.sachsen]) {
          for (final d in getGermanHolidays(year, land)) {
            final reason = '$year $land $d';
            expect(d.hour, 0, reason: reason);
            expect(d.minute, 0, reason: reason);
            expect(d.second, 0, reason: reason);
            expect(d.millisecond, 0, reason: reason);
            expect(d.isUtc, isFalse, reason: reason);
          }
        }
      }
    });

    test('getGermanHolidayNames: Schlüssel sind reine Datumswerte', () {
      for (final year in [2024, 2027]) {
        final names = getGermanHolidayNames(year, Bundesland.bayern);
        final easterMonday =
            year == 2024 ? DateTime(2024, 4, 1) : DateTime(2027, 3, 29);
        final himmelfahrt =
            year == 2024 ? DateTime(2024, 5, 9) : DateTime(2027, 5, 6);
        final pfingstmontag =
            year == 2024 ? DateTime(2024, 5, 20) : DateTime(2027, 5, 17);
        final fronleichnam =
            year == 2024 ? DateTime(2024, 5, 30) : DateTime(2027, 5, 27);
        expect(names[easterMonday], 'Ostermontag');
        expect(names[himmelfahrt], 'Christi Himmelfahrt');
        expect(names[pfingstmontag], 'Pfingstmontag');
        expect(names[fronleichnam], 'Fronleichnam');
      }
    });
  });

  group('getGermanHolidays - landesspezifische Feiertage', () {
    test(
        'Bayern hat Heilige Drei Könige, Fronleichnam, Mariä Himmelfahrt, Allerheiligen',
        () {
      final holidays = getGermanHolidays(2024, Bundesland.bayern);
      expect(holidays, contains(DateTime(2024, 1, 6)));
      expect(holidays,
          contains(DateTime(2024, 5, 30))); // Fronleichnam (Ostern+60)
      expect(holidays, contains(DateTime(2024, 8, 15)));
      expect(holidays, contains(DateTime(2024, 11, 1)));
      expect(holidays.length, 9 + 4);
    });

    test(
        'Nordrhein-Westfalen hat nur Fronleichnam und Allerheiligen zusätzlich',
        () {
      final holidays = getGermanHolidays(2024, Bundesland.nordrheinWestfalen);
      expect(holidays, contains(DateTime(2024, 5, 30)));
      expect(holidays, contains(DateTime(2024, 11, 1)));
      expect(holidays, isNot(contains(DateTime(2024, 1, 6))));
      expect(holidays.length, 9 + 2);
    });

    test('Berlin hat den Internationalen Frauentag zusätzlich', () {
      final holidays = getGermanHolidays(2024, Bundesland.berlin);
      expect(holidays, contains(DateTime(2024, 3, 8)));
      expect(holidays.length, 9 + 1);
    });

    test('Sachsen hat Reformationstag und Buß- und Bettag zusätzlich', () {
      final holidays = getGermanHolidays(2024, Bundesland.sachsen);
      expect(holidays, contains(DateTime(2024, 10, 31)));
      expect(
          holidays, contains(DateTime(2024, 11, 20))); // Buß- und Bettag 2024
      expect(holidays.length, 9 + 2);
    });

    test('Buß- und Bettag liegt immer zwischen dem 16. und 22. November', () {
      for (final year in [2023, 2024, 2025, 2026, 2027, 2028]) {
        final holidays = getGermanHolidays(year, Bundesland.sachsen);
        final bussUndBettag = holidays.firstWhere((d) =>
            d.month == 11 && d.day != 1 && d.weekday == DateTime.wednesday);
        expect(bussUndBettag.day, inInclusiveRange(16, 22));
      }
    });

    test('Thüringen hat Weltkindertag und Reformationstag zusätzlich', () {
      final holidays = getGermanHolidays(2024, Bundesland.thueringen);
      expect(holidays, contains(DateTime(2024, 9, 20)));
      expect(holidays, contains(DateTime(2024, 10, 31)));
      expect(holidays.length, 9 + 2);
    });
  });

  group('getGermanHolidayIds', () {
    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    test('Enum hat genau 17 Werte, Mapping deckt alle ab', () {
      expect(GermanHoliday.values.length, 17);
      expect(
          germanHolidayGermanNames.keys.toSet(), GermanHoliday.values.toSet());
    });

    for (final year in holidayDatesByYear.keys) {
      for (final land in Bundesland.values) {
        test('Fixture $year ${land.name}', () {
          final result = getGermanHolidayIds(year, land);
          final expected = expectedHolidays(year, land);
          expect(result.length, expected.length);
          for (final entry in result.entries) {
            // Schluessel sind lokale Mitternacht.
            expect(entry.key,
                DateTime(entry.key.year, entry.key.month, entry.key.day));
            expect(expected[fmt(entry.key)], entry.value,
                reason: '${fmt(entry.key)} ${entry.value}');
          }
        });

        test('Paritaet mit getGermanHolidayNames $year ${land.name}', () {
          final ids = getGermanHolidayIds(year, land);
          final names = getGermanHolidayNames(year, land);
          expect(ids.keys.toSet(), names.keys.toSet());
          for (final entry in ids.entries) {
            expect(germanHolidayGermanNames[entry.value], names[entry.key]);
          }
        });
      }
    }
  });
}
