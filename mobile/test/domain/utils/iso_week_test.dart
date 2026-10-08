import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/utils/iso_week.dart';

void main() {
  // (Jahr, Monat, Tag, Woche, Wochenjahr)
  const cases = <(int, int, int, int, int)>[
    // Issue-Fall (Sommerzeit-Montag)
    (2026, 8, 31, 36, 2026),
    (2026, 9, 1, 36, 2026),
    (2026, 9, 6, 36, 2026),
    (2026, 9, 7, 37, 2026),
    // DST-Montage
    (2026, 3, 23, 13, 2026),
    (2026, 3, 30, 14, 2026),
    (2026, 10, 26, 44, 2026),
    // Jahreswechsel
    (2026, 1, 1, 1, 2026),
    (2025, 12, 29, 1, 2026),
    (2024, 12, 30, 1, 2025),
    (2024, 1, 1, 1, 2024),
    (2027, 1, 1, 53, 2026),
    (2027, 1, 3, 53, 2026),
    (2027, 1, 4, 1, 2027),
    (2021, 1, 3, 53, 2020),
    (2021, 1, 4, 1, 2021),
    // 53-Wochen-Jahre
    (2020, 12, 31, 53, 2020),
    (2026, 12, 31, 53, 2026),
    (2025, 12, 28, 52, 2025),
    (2026, 12, 28, 53, 2026),
    // Schaltjahr
    (2024, 2, 29, 9, 2024),
    (2024, 12, 31, 1, 2025),
  ];

  group('isoWeekNumber / isoWeekYear', () {
    for (final (y, m, d, week, weekYear) in cases) {
      test('$y-$m-$d -> KW $week / $weekYear', () {
        expect(isoWeekNumber(DateTime(y, m, d)), week);
        expect(isoWeekYear(DateTime(y, m, d)), weekYear);
        expect(isoWeekNumber(DateTime.utc(y, m, d)), week);
        expect(isoWeekYear(DateTime.utc(y, m, d)), weekYear);
      });
    }

    test('Uhrzeit wird ignoriert', () {
      expect(isoWeekNumber(DateTime(2026, 8, 31, 0, 0)), 36);
      expect(isoWeekNumber(DateTime(2026, 8, 31, 23, 59)), 36);
      expect(isoWeekNumber(DateTime.utc(2026, 8, 31, 23, 59)), 36);
    });

    test('Mo-So derselben Woche sind identisch nummeriert', () {
      var day = DateTime(2025, 12, 22); // Montag
      while (day.isBefore(DateTime(2027, 1, 10))) {
        final monday = DateTime(day.year, day.month, day.day);
        final expected = isoWeekNumber(monday);
        final expectedYear = isoWeekYear(monday);
        for (var i = 0; i < 7; i++) {
          final d = DateTime(monday.year, monday.month, monday.day + i);
          expect(isoWeekNumber(d), expected, reason: '$d');
          expect(isoWeekYear(d), expectedYear, reason: '$d');
        }
        day = DateTime(monday.year, monday.month, monday.day + 7);
      }
    });
  });
}
