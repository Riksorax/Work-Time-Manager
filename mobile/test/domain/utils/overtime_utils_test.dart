import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/utils/overtime_utils.dart';

void main() {
  const regularTarget = Duration(hours: 8);

  WorkEntryEntity makeEntry(DateTime date, {bool withWork = true}) {
    return WorkEntryEntity(
      id: date.toIso8601String(),
      date: date,
      workStart: withWork ? date.add(const Duration(hours: 8)) : null,
      workEnd: withWork ? date.add(const Duration(hours: 16)) : null,
    );
  }

  group('getEffectiveDailyTarget', () {
    const monFri = [1, 2, 3, 4, 5];

    test('Mo-Fr-Vertrag: jeder Wochentag Mo-Fr erhält reguläres Soll', () {
      for (final date in [
        DateTime(2023, 10, 23), // Mo
        DateTime(2023, 10, 24), // Di
        DateTime(2023, 10, 25), // Mi
        DateTime(2023, 10, 26), // Do
        DateTime(2023, 10, 27), // Fr
      ]) {
        final target = getEffectiveDailyTarget(
          date: date,
          workdays: monFri,
          regularDailyTarget: regularTarget,
        );
        expect(target, regularTarget, reason: '$date sollte reguläres Soll haben');
      }
    });

    test('Mo-Fr-Vertrag: Samstag und Sonntag sind Zusatztage', () {
      expect(
        getEffectiveDailyTarget(
          date: DateTime(2023, 10, 28), // Sa
          workdays: monFri,
          regularDailyTarget: regularTarget,
        ),
        Duration.zero,
      );
      expect(
        getEffectiveDailyTarget(
          date: DateTime(2023, 10, 29), // So
          workdays: monFri,
          regularDailyTarget: regularTarget,
        ),
        Duration.zero,
      );
    });

    test('Di-Sa-Vertrag: Montag ist Zusatztag, Samstag ist Soll-Tag (Bug-Fix #217)', () {
      const tueSat = [2, 3, 4, 5, 6];

      // Der ursprüngliche Bug: bei ordinaler Zählung ("erste N Tage der
      // Woche") bekam Montag fälschlich ein Soll und Samstag keins.
      expect(
        getEffectiveDailyTarget(
          date: DateTime(2023, 10, 23), // Mo
          workdays: tueSat,
          regularDailyTarget: regularTarget,
        ),
        Duration.zero,
        reason: 'Montag ist bei Di-Sa-Vertrag kein Soll-Tag',
      );
      expect(
        getEffectiveDailyTarget(
          date: DateTime(2023, 10, 28), // Sa
          workdays: tueSat,
          regularDailyTarget: regularTarget,
        ),
        regularTarget,
        reason: 'Samstag ist bei Di-Sa-Vertrag ein Soll-Tag',
      );
    });

    test('4-Tage-Woche (Mo-Do): Freitag ist Zusatztag', () {
      final target = getEffectiveDailyTarget(
        date: DateTime(2023, 10, 27), // Fr
        workdays: const [1, 2, 3, 4],
        regularDailyTarget: const Duration(hours: 10),
      );
      expect(target, Duration.zero);
    });

    test('gilt unabhängig davon, ob an dem Tag tatsächlich gearbeitet wurde', () {
      // Die Funktion braucht keine Einträge mehr - nur den Wochentag.
      final target = getEffectiveDailyTarget(
        date: DateTime(2023, 10, 25), // Mi, kein Eintrag vorhanden
        workdays: monFri,
        regularDailyTarget: regularTarget,
      );
      expect(target, regularTarget);
    });
  });

  group('getEffectiveWorkDays', () {
    test('zählt nur Tage, deren Wochentag zu den Arbeitstagen gehört', () {
      final entries = [
        makeEntry(DateTime(2023, 10, 23)), // Mo
        makeEntry(DateTime(2023, 10, 24)), // Di
        makeEntry(DateTime(2023, 10, 25)), // Mi
        makeEntry(DateTime(2023, 10, 26)), // Do
        makeEntry(DateTime(2023, 10, 27)), // Fr
        makeEntry(DateTime(2023, 10, 28)), // Sa - kein Vertragstag
      ];

      final effective = getEffectiveWorkDays(entries: entries, workdays: const [1, 2, 3, 4, 5]);
      expect(effective, 5);
    });

    test('Di-Sa-Vertrag: Arbeit an einem Montag zählt nicht mit (Bug-Fix #217)', () {
      final entries = [
        makeEntry(DateTime(2023, 10, 23)), // Mo - kein Vertragstag
        makeEntry(DateTime(2023, 10, 24)), // Di
        makeEntry(DateTime(2023, 10, 25)), // Mi
      ];

      final effective = getEffectiveWorkDays(entries: entries, workdays: const [2, 3, 4, 5, 6]);
      expect(effective, 2);
    });

    test('weniger Einträge als Vertragstage gibt tatsächliche Anzahl zurück', () {
      final entries = [
        makeEntry(DateTime(2023, 10, 23)),
        makeEntry(DateTime(2023, 10, 24)),
        makeEntry(DateTime(2023, 10, 25)),
      ];

      final effective = getEffectiveWorkDays(entries: entries, workdays: const [1, 2, 3, 4, 5]);
      expect(effective, 3);
    });

    test('Einträge ohne workStart werden ignoriert', () {
      final entries = [
        makeEntry(DateTime(2023, 10, 23)),
        makeEntry(DateTime(2023, 10, 24), withWork: false),
      ];

      final effective = getEffectiveWorkDays(entries: entries, workdays: const [1, 2, 3, 4, 5]);
      expect(effective, 1);
    });
  });

  group('getWeekEntriesForDate', () {
    test('filtert korrekt für die Woche eines Datums', () {
      final allEntries = [
        makeEntry(DateTime(2023, 10, 20)), // Vorherige Woche (Fr)
        makeEntry(DateTime(2023, 10, 23)), // Mo (aktuelle Woche)
        makeEntry(DateTime(2023, 10, 24)), // Di
        makeEntry(DateTime(2023, 10, 25)), // Mi
        makeEntry(DateTime(2023, 10, 30)), // Nächste Woche (Mo)
      ];

      final weekEntries = getWeekEntriesForDate(DateTime(2023, 10, 25), allEntries);
      expect(weekEntries.length, 3);
      expect(weekEntries[0].date, DateTime(2023, 10, 23));
      expect(weekEntries[1].date, DateTime(2023, 10, 24));
      expect(weekEntries[2].date, DateTime(2023, 10, 25));
    });
  });
}
