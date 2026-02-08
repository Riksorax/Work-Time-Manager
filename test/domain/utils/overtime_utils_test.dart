import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/utils/overtime_utils.dart';

void main() {
  const regularTarget = Duration(hours: 8);

  WorkEntryEntity _makeEntry(DateTime date, {bool withWork = true}) {
    return WorkEntryEntity(
      id: date.toIso8601String(),
      date: date,
      workStart: withWork ? date.add(const Duration(hours: 8)) : null,
      workEnd: withWork ? date.add(const Duration(hours: 16)) : null,
    );
  }

  group('getEffectiveDailyTarget', () {
    test('5 Arbeitstage in 5-Tage-Woche: alle regulär', () {
      // Mo 2023-10-23 bis Fr 2023-10-27
      final entries = [
        _makeEntry(DateTime(2023, 10, 23)), // Mo
        _makeEntry(DateTime(2023, 10, 24)), // Di
        _makeEntry(DateTime(2023, 10, 25)), // Mi
        _makeEntry(DateTime(2023, 10, 26)), // Do
        _makeEntry(DateTime(2023, 10, 27)), // Fr
      ];

      for (final entry in entries) {
        final target = getEffectiveDailyTarget(
          date: entry.date,
          weekEntries: entries,
          workdaysPerWeek: 5,
          regularDailyTarget: regularTarget,
        );
        expect(target, regularTarget,
            reason: 'Tag ${entry.date.weekday} sollte reguläres Soll haben');
      }
    });

    test('6 Arbeitstage in 5-Tage-Woche: 6. Tag ist Zusatztag', () {
      final entries = [
        _makeEntry(DateTime(2023, 10, 23)), // Mo
        _makeEntry(DateTime(2023, 10, 24)), // Di
        _makeEntry(DateTime(2023, 10, 25)), // Mi
        _makeEntry(DateTime(2023, 10, 26)), // Do
        _makeEntry(DateTime(2023, 10, 27)), // Fr
        _makeEntry(DateTime(2023, 10, 28)), // Sa (Zusatztag)
      ];

      // Mo-Fr: reguläres Soll
      for (int i = 0; i < 5; i++) {
        final target = getEffectiveDailyTarget(
          date: entries[i].date,
          weekEntries: entries,
          workdaysPerWeek: 5,
          regularDailyTarget: regularTarget,
        );
        expect(target, regularTarget,
            reason: 'Tag ${entries[i].date.day} sollte reguläres Soll haben');
      }

      // Sa: Zusatztag, Soll = 0
      final satTarget = getEffectiveDailyTarget(
        date: DateTime(2023, 10, 28),
        weekEntries: entries,
        workdaysPerWeek: 5,
        regularDailyTarget: regularTarget,
      );
      expect(satTarget, Duration.zero);
    });

    test('7 Arbeitstage in 5-Tage-Woche: Sa und So sind Zusatztage', () {
      final entries = [
        _makeEntry(DateTime(2023, 10, 23)), // Mo
        _makeEntry(DateTime(2023, 10, 24)), // Di
        _makeEntry(DateTime(2023, 10, 25)), // Mi
        _makeEntry(DateTime(2023, 10, 26)), // Do
        _makeEntry(DateTime(2023, 10, 27)), // Fr
        _makeEntry(DateTime(2023, 10, 28)), // Sa
        _makeEntry(DateTime(2023, 10, 29)), // So
      ];

      expect(
        getEffectiveDailyTarget(
          date: DateTime(2023, 10, 28),
          weekEntries: entries,
          workdaysPerWeek: 5,
          regularDailyTarget: regularTarget,
        ),
        Duration.zero,
      );
      expect(
        getEffectiveDailyTarget(
          date: DateTime(2023, 10, 29),
          weekEntries: entries,
          workdaysPerWeek: 5,
          regularDailyTarget: regularTarget,
        ),
        Duration.zero,
      );
    });

    test('3 Arbeitstage in 5-Tage-Woche: alle regulär', () {
      final entries = [
        _makeEntry(DateTime(2023, 10, 23)), // Mo
        _makeEntry(DateTime(2023, 10, 25)), // Mi
        _makeEntry(DateTime(2023, 10, 27)), // Fr
      ];

      for (final entry in entries) {
        final target = getEffectiveDailyTarget(
          date: entry.date,
          weekEntries: entries,
          workdaysPerWeek: 5,
          regularDailyTarget: regularTarget,
        );
        expect(target, regularTarget);
      }
    });

    test('Tag nicht in Einträgen: reguläres Soll', () {
      final entries = [
        _makeEntry(DateTime(2023, 10, 23)), // Mo
        _makeEntry(DateTime(2023, 10, 24)), // Di
      ];

      // Mi ist nicht in den Einträgen
      final target = getEffectiveDailyTarget(
        date: DateTime(2023, 10, 25),
        weekEntries: entries,
        workdaysPerWeek: 5,
        regularDailyTarget: regularTarget,
      );
      expect(target, regularTarget);
    });

    test('Einträge ohne workStart werden ignoriert', () {
      final entries = [
        _makeEntry(DateTime(2023, 10, 23)), // Mo (mit Arbeit)
        _makeEntry(DateTime(2023, 10, 24)), // Di (mit Arbeit)
        _makeEntry(DateTime(2023, 10, 25)), // Mi (mit Arbeit)
        _makeEntry(DateTime(2023, 10, 26)), // Do (mit Arbeit)
        _makeEntry(DateTime(2023, 10, 27)), // Fr (mit Arbeit)
        _makeEntry(DateTime(2023, 10, 28), withWork: false), // Sa (ohne Arbeit)
      ];

      // Sa ohne workStart sollte nicht als Arbeitstag zählen
      // => Nur 5 echte Arbeitstage, kein Zusatztag
      final satTarget = getEffectiveDailyTarget(
        date: DateTime(2023, 10, 28),
        weekEntries: entries,
        workdaysPerWeek: 5,
        regularDailyTarget: regularTarget,
      );
      // Der Tag ist nicht in den "workDays" (kein workStart), also reguläres Soll
      expect(satTarget, regularTarget);
    });

    test('4-Tage-Woche: 5. Tag ist Zusatztag', () {
      final entries = [
        _makeEntry(DateTime(2023, 10, 23)), // Mo
        _makeEntry(DateTime(2023, 10, 24)), // Di
        _makeEntry(DateTime(2023, 10, 25)), // Mi
        _makeEntry(DateTime(2023, 10, 26)), // Do
        _makeEntry(DateTime(2023, 10, 27)), // Fr (Zusatztag bei 4-Tage-Woche)
      ];

      final target = getEffectiveDailyTarget(
        date: DateTime(2023, 10, 27),
        weekEntries: entries,
        workdaysPerWeek: 4,
        regularDailyTarget: const Duration(hours: 10),
      );
      expect(target, Duration.zero);
    });
  });

  group('getEffectiveWorkDays', () {
    test('begrenzt auf workdaysPerWeek', () {
      final entries = [
        _makeEntry(DateTime(2023, 10, 23)),
        _makeEntry(DateTime(2023, 10, 24)),
        _makeEntry(DateTime(2023, 10, 25)),
        _makeEntry(DateTime(2023, 10, 26)),
        _makeEntry(DateTime(2023, 10, 27)),
        _makeEntry(DateTime(2023, 10, 28)), // 6. Tag
      ];

      final effective = getEffectiveWorkDays(entries: entries, workdaysPerWeek: 5);
      expect(effective, 5);
    });

    test('weniger als workdaysPerWeek gibt tatsächliche Anzahl zurück', () {
      final entries = [
        _makeEntry(DateTime(2023, 10, 23)),
        _makeEntry(DateTime(2023, 10, 24)),
        _makeEntry(DateTime(2023, 10, 25)),
      ];

      final effective = getEffectiveWorkDays(entries: entries, workdaysPerWeek: 5);
      expect(effective, 3);
    });
  });

  group('getWeekEntriesForDate', () {
    test('filtert korrekt für die Woche eines Datums', () {
      final allEntries = [
        _makeEntry(DateTime(2023, 10, 20)), // Vorherige Woche (Fr)
        _makeEntry(DateTime(2023, 10, 23)), // Mo (aktuelle Woche)
        _makeEntry(DateTime(2023, 10, 24)), // Di
        _makeEntry(DateTime(2023, 10, 25)), // Mi
        _makeEntry(DateTime(2023, 10, 30)), // Nächste Woche (Mo)
      ];

      final weekEntries = getWeekEntriesForDate(DateTime(2023, 10, 25), allEntries);
      expect(weekEntries.length, 3);
      expect(weekEntries[0].date, DateTime(2023, 10, 23));
      expect(weekEntries[1].date, DateTime(2023, 10, 24));
      expect(weekEntries[2].date, DateTime(2023, 10, 25));
    });
  });
}
