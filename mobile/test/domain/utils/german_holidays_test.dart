import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/bundesland.dart';
import 'package:flutter_work_time/domain/utils/german_holidays.dart';

void main() {
  group('getGermanHolidays - bundesweite Feiertage', () {
    test('enthält alle 9 bundesweiten Feiertage 2024', () {
      final holidays = getGermanHolidays(2024, Bundesland.hamburg);
      // Hamburg hat zusätzlich den Reformationstag -> 10 statt 9.
      expect(holidays, contains(DateTime(2024, 1, 1))); // Neujahr
      expect(holidays, contains(DateTime(2024, 3, 29))); // Karfreitag (Ostern 31.3.)
      expect(holidays, contains(DateTime(2024, 4, 1))); // Ostermontag
      expect(holidays, contains(DateTime(2024, 5, 1))); // Tag der Arbeit
      expect(holidays, contains(DateTime(2024, 5, 9))); // Christi Himmelfahrt
      expect(holidays, contains(DateTime(2024, 5, 20))); // Pfingstmontag
      expect(holidays, contains(DateTime(2024, 10, 3))); // Tag der Deutschen Einheit
      expect(holidays, contains(DateTime(2024, 12, 25)));
      expect(holidays, contains(DateTime(2024, 12, 26)));
      expect(holidays.length, 10);
    });

    test('Ostersonntag-Berechnung stimmt für 2025 (verifizierter Referenzwert)', () {
      // Christi Himmelfahrt = Ostern + 39 Tage. Ostern 2025 ist der 20. April.
      final holidays = getGermanHolidays(2025, Bundesland.hamburg);
      expect(holidays, contains(DateTime(2025, 5, 29))); // Christi Himmelfahrt
      expect(holidays, contains(DateTime(2025, 4, 18))); // Karfreitag
      expect(holidays, contains(DateTime(2025, 4, 21))); // Ostermontag
    });
  });

  group('getGermanHolidays - landesspezifische Feiertage', () {
    test('Bayern hat Heilige Drei Könige, Fronleichnam, Mariä Himmelfahrt, Allerheiligen', () {
      final holidays = getGermanHolidays(2024, Bundesland.bayern);
      expect(holidays, contains(DateTime(2024, 1, 6)));
      expect(holidays, contains(DateTime(2024, 5, 30))); // Fronleichnam (Ostern+60)
      expect(holidays, contains(DateTime(2024, 8, 15)));
      expect(holidays, contains(DateTime(2024, 11, 1)));
      expect(holidays.length, 9 + 4);
    });

    test('Nordrhein-Westfalen hat nur Fronleichnam und Allerheiligen zusätzlich', () {
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
      expect(holidays, contains(DateTime(2024, 11, 20))); // Buß- und Bettag 2024
      expect(holidays.length, 9 + 2);
    });

    test('Buß- und Bettag liegt immer zwischen dem 16. und 22. November', () {
      for (final year in [2023, 2024, 2025, 2026, 2027, 2028]) {
        final holidays = getGermanHolidays(year, Bundesland.sachsen);
        final bussUndBettag =
            holidays.firstWhere((d) => d.month == 11 && d.day != 1 && d.weekday == DateTime.wednesday);
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
}
