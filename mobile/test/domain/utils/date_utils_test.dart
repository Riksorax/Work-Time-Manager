import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/utils/date_utils.dart';

void main() {
  void expectMidnight(DateTime d, int y, int m, int day) {
    expect(d.year, y);
    expect(d.month, m);
    expect(d.day, day);
    expect(d.hour, 0);
    expect(d.minute, 0);
  }

  group('addCalendarDays', () {
    test('Frühjahrs-Umstellung: 30.03.2025 +1', () {
      expectMidnight(addCalendarDays(DateTime(2025, 3, 30), 1), 2025, 3, 31);
    });

    test('Herbst-Umstellung: 26.10.2025 +1', () {
      expectMidnight(addCalendarDays(DateTime(2025, 10, 26), 1), 2025, 10, 27);
    });

    test('29.03.2025 +7', () {
      expectMidnight(addCalendarDays(DateTime(2025, 3, 29), 7), 2025, 4, 5);
    });

    test('31.03.2025 -7', () {
      expectMidnight(addCalendarDays(DateTime(2025, 3, 31), -7), 2025, 3, 24);
    });

    test('27.10.2025 -7', () {
      expectMidnight(addCalendarDays(DateTime(2025, 10, 27), -7), 2025, 10, 20);
    });

    test('Jahreswechsel: 31.12.2025 +1', () {
      expectMidnight(addCalendarDays(DateTime(2025, 12, 31), 1), 2026, 1, 1);
    });

    test('normalisiert eine Uhrzeit auf Mitternacht', () {
      expectMidnight(
          addCalendarDays(DateTime(2025, 10, 25, 15, 30), 1), 2025, 10, 26);
    });
  });

  group('datesInRange', () {
    test('24.10.-28.10.2025 liefert 5 Tage inkl. Endtag', () {
      final days = datesInRange(DateTime(2025, 10, 24), DateTime(2025, 10, 28));
      expect(days.length, 5);
      for (var i = 0; i < 5; i++) {
        expectMidnight(days[i], 2025, 10, 24 + i);
      }
    });

    test('28.03.-01.04.2025 liefert 5 Tage inkl. Endtag', () {
      final days = datesInRange(DateTime(2025, 3, 28), DateTime(2025, 4, 1));
      expect(days.length, 5);
      expectMidnight(days.last, 2025, 4, 1);
      for (final d in days) {
        expect(d.hour, 0);
      }
    });

    test('vertauschte Reihenfolge liefert gleiches Ergebnis', () {
      final a = datesInRange(DateTime(2025, 10, 24), DateTime(2025, 10, 28));
      final b = datesInRange(DateTime(2025, 10, 28), DateTime(2025, 10, 24));
      expect(b, a);
    });

    test('Start = Ende liefert einen Tag', () {
      final days = datesInRange(DateTime(2025, 5, 5), DateTime(2025, 5, 5, 14));
      expect(days.length, 1);
      expectMidnight(days.first, 2025, 5, 5);
    });

    test('Endtag ist Umstellungstag 26.10.2025', () {
      final days = datesInRange(DateTime(2025, 10, 24), DateTime(2025, 10, 26));
      expect(days.length, 3);
      expectMidnight(days.last, 2025, 10, 26);
    });
  });

  group('shiftWeekStart', () {
    void check(DateTime from, int weeks, int y, int m, int d) {
      final r = shiftWeekStart(from, weeks);
      expectMidnight(r, y, m, d);
      expect(r.weekday, 1);
    }

    test('Mo 20.10.2025 +1 -> Mo 27.10.2025', () {
      check(DateTime(2025, 10, 20), 1, 2025, 10, 27);
    });

    test('Mo 31.03.2025 -1 -> Mo 24.03.2025', () {
      check(DateTime(2025, 3, 31), -1, 2025, 3, 24);
    });

    test('Mo 24.03.2025 +1 -> Mo 31.03.2025', () {
      check(DateTime(2025, 3, 24), 1, 2025, 3, 31);
    });

    test('Mo 27.10.2025 -1 -> Mo 20.10.2025', () {
      check(DateTime(2025, 10, 27), -1, 2025, 10, 20);
    });
  });
}
