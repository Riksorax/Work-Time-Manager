import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/break_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/utils/open_entry_report_utils.dart';

void main() {
  // Feste Uhr, alles lokal konstruiert, kein DateTime.now().
  final now = DateTime(2026, 10, 5, 12);

  WorkEntryEntity entry({
    required DateTime day,
    DateTime? start,
    DateTime? end,
    List<BreakEntity> breaks = const [],
    WorkEntryType type = WorkEntryType.work,
  }) =>
      WorkEntryEntity(
        id: 'e',
        date: DateTime(day.year, day.month, day.day),
        workStart: start,
        workEnd: end,
        breaks: breaks,
        type: type,
      );

  group('reportNetDuration', () {
    test('abgeschlossener Eintrag: Ende - Start - Pausen', () {
      final e = entry(
        day: DateTime(2026, 10, 2),
        start: DateTime(2026, 10, 2, 8),
        end: DateTime(2026, 10, 2, 17),
        breaks: [
          BreakEntity(
            id: 'b',
            name: 'Mittag',
            start: DateTime(2026, 10, 2, 12),
            end: DateTime(2026, 10, 2, 12, 30),
          ),
        ],
      );
      expect(reportNetDuration(e, now: now),
          const Duration(hours: 8, minutes: 30));
    });

    test('abgeschlossener Eintrag vor heute zählt unabhängig von "jetzt"', () {
      final e = entry(
        day: DateTime(2026, 9, 1),
        start: DateTime(2026, 9, 1, 8),
        end: DateTime(2026, 9, 1, 16),
      );
      expect(reportNetDuration(e, now: now), const Duration(hours: 8));
    });

    test('offen und heute: live bis "jetzt"', () {
      final e = entry(
        day: DateTime(2026, 10, 5),
        start: DateTime(2026, 10, 5, 8),
      );
      expect(reportNetDuration(e, now: now), const Duration(hours: 4));
    });

    test('offen und heute: Sekunden der Uhr werden auf Minuten abgeschnitten',
        () {
      final e = entry(
        day: DateTime(2026, 10, 5),
        start: DateTime(2026, 10, 5, 8),
      );
      expect(reportNetDuration(e, now: DateTime(2026, 10, 5, 12, 0, 45)),
          const Duration(hours: 4));
    });

    test('offen und heute: geschlossene und offene Pause werden abgezogen', () {
      final e = entry(
        day: DateTime(2026, 10, 5),
        start: DateTime(2026, 10, 5, 8),
        breaks: [
          BreakEntity(
            id: 'b',
            name: 'a',
            start: DateTime(2026, 10, 5, 9),
            end: DateTime(2026, 10, 5, 9, 30),
          ),
          BreakEntity(id: 'b', name: 'b', start: DateTime(2026, 10, 5, 11)),
        ],
      );
      // 4h - 30min - 1h (offene Pause bis jetzt)
      expect(reportNetDuration(e, now: now),
          const Duration(hours: 2, minutes: 30));
    });

    test('Pausen werden auf [Start, Ende] geklemmt', () {
      final e = entry(
        day: DateTime(2026, 10, 5),
        start: DateTime(2026, 10, 5, 8),
        breaks: [
          // beginnt vor dem Start: nur 08:00-08:30 zählen
          BreakEntity(
            id: 'b',
            name: 'a',
            start: DateTime(2026, 10, 5, 7),
            end: DateTime(2026, 10, 5, 8, 30),
          ),
          // komplett vor dem Start: zählt nicht
          BreakEntity(
            id: 'b',
            name: 'b',
            start: DateTime(2026, 10, 5, 6),
            end: DateTime(2026, 10, 5, 7),
          ),
        ],
      );
      expect(reportNetDuration(e, now: now),
          const Duration(hours: 3, minutes: 30));
    });

    test('Pause über das Ende hinaus wird am Ende geklemmt', () {
      final e = entry(
        day: DateTime(2026, 10, 2),
        start: DateTime(2026, 10, 2, 8),
        end: DateTime(2026, 10, 2, 10),
        breaks: [
          BreakEntity(
            id: 'b',
            name: 'a',
            start: DateTime(2026, 10, 2, 9),
            end: DateTime(2026, 10, 2, 11),
          ),
        ],
      );
      expect(reportNetDuration(e, now: now), const Duration(hours: 1));
    });

    for (final past in [
      ('1 Tag vorher', DateTime(2026, 10, 4)),
      ('5 Tage vorher', DateTime(2026, 9, 30)),
      ('Vormonat', DateTime(2026, 9, 5)),
    ]) {
      test('offen vor heute (${past.$1}): 0, nicht "jetzt - Start"', () {
        final day = past.$2;
        final e = entry(
          day: day,
          start: DateTime(day.year, day.month, day.day, 8),
        );
        expect(reportNetDuration(e, now: now), Duration.zero);
      });
    }

    test(
        'offen vor heute mit geschlossener Pause: 0 (Pause wird nicht negativ)',
        () {
      final e = entry(
        day: DateTime(2026, 10, 2),
        start: DateTime(2026, 10, 2, 8),
        breaks: [
          BreakEntity(
            id: 'b',
            name: 'a',
            start: DateTime(2026, 10, 2, 12),
            end: DateTime(2026, 10, 2, 12, 30),
          ),
        ],
      );
      expect(reportNetDuration(e, now: now), Duration.zero);
    });

    test('offen heute, aber "jetzt" vor Start (Uhrsprung): nicht negativ', () {
      final e = entry(
        day: DateTime(2026, 10, 5),
        start: DateTime(2026, 10, 5, 13),
        breaks: [
          BreakEntity(id: 'b', name: 'a', start: DateTime(2026, 10, 5, 13, 10)),
        ],
      );
      expect(reportNetDuration(e, now: now), Duration.zero);
    });

    test('ohne Start: 0', () {
      final e = entry(day: DateTime(2026, 10, 5));
      expect(reportNetDuration(e, now: now), Duration.zero);
    });

    test('Mitternachtsgrenze: derselbe Eintrag wechselt von live zu 0', () {
      final e = entry(
        day: DateTime(2026, 10, 5),
        start: DateTime(2026, 10, 5, 22),
      );
      expect(reportNetDuration(e, now: DateTime(2026, 10, 5, 23, 59)),
          const Duration(hours: 1, minutes: 59));
      expect(reportNetDuration(e, now: DateTime(2026, 10, 6, 0, 1)),
          Duration.zero);
    });

    test('Tag des Eintrags zählt lokal, nicht die Uhrzeit von date', () {
      // date mit Uhrzeit kurz vor Mitternacht bleibt derselbe lokale Tag.
      final e = WorkEntryEntity(
        id: 'e',
        date: DateTime(2026, 10, 5, 23, 30),
        workStart: DateTime(2026, 10, 5, 8),
      );
      expect(reportNetDuration(e, now: now), const Duration(hours: 4));
    });
  });

  group('isOpenBeforeToday', () {
    final open = DateTime(2026, 10, 4, 8);

    test('offener Arbeitseintrag am Vortag: true', () {
      expect(
          isOpenBeforeToday(
              entry(day: DateTime(2026, 10, 4), start: open), now),
          isTrue);
    });

    test('offener Arbeitseintrag heute: false', () {
      expect(
          isOpenBeforeToday(
              entry(
                  day: DateTime(2026, 10, 5), start: DateTime(2026, 10, 5, 8)),
              now),
          isFalse);
    });

    test('offener Eintrag in der Zukunft: kein "Unvollständig", Netto 0', () {
      final e =
          entry(day: DateTime(2026, 10, 6), start: DateTime(2026, 10, 6, 8));
      expect(isOpenBeforeToday(e, now), isFalse);
      expect(reportNetDuration(e, now: now), Duration.zero);
    });

    test('Mitternachtsgrenze: gleicher Eintrag ab 00:00 des Folgetags true',
        () {
      final e =
          entry(day: DateTime(2026, 10, 5), start: DateTime(2026, 10, 5, 8));
      expect(isOpenBeforeToday(e, DateTime(2026, 10, 5, 23, 59)), isFalse);
      expect(isOpenBeforeToday(e, DateTime(2026, 10, 6)), isTrue);
    });

    test('abgeschlossener Eintrag: false', () {
      expect(
          isOpenBeforeToday(
              entry(
                  day: DateTime(2026, 10, 4),
                  start: open,
                  end: DateTime(2026, 10, 4, 16)),
              now),
          isFalse);
    });

    test('ohne Start: false', () {
      expect(
          isOpenBeforeToday(entry(day: DateTime(2026, 10, 4)), now), isFalse);
    });

    for (final type in [
      WorkEntryType.vacation,
      WorkEntryType.sick,
      WorkEntryType.holiday,
    ]) {
      test('$type ohne Ende ist nie "offen": false und Netto 0', () {
        final e = entry(day: DateTime(2026, 10, 4), start: open, type: type);
        expect(isOpenBeforeToday(e, now), isFalse);
        expect(reportNetDuration(e, now: now), Duration.zero);
      });
    }
  });
}
