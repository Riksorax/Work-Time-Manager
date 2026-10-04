import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/break_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/utils/overtime_utils.dart';

const eight = Duration(hours: 8);

WorkEntryEntity entryAt(DateTime start,
        {List<BreakEntity> breaks = const []}) =>
    WorkEntryEntity(
      id: 'e',
      date: DateTime(start.year, start.month, start.day),
      workStart: start,
      breaks: breaks,
    );

BreakEntity closedBreak(DateTime start, Duration length) => BreakEntity(
    id: 'b${start.microsecondsSinceEpoch}',
    name: 'P',
    start: start,
    end: start.add(length));

void main() {
  group('effectiveTargetForDate', () {
    const workdays = [1, 2, 3, 4, 5];

    test('Arbeitstag -> Tagessoll (Fr 2026-10-02, 40 h / 5 Tage = 8 h)', () {
      expect(
          effectiveTargetForDate(
              date: DateTime(2026, 10, 2), workdays: workdays, weeklyHours: 40),
          eight);
    });

    test('Nicht-Arbeitstag (Sa 2026-10-03) -> 0', () {
      expect(
          effectiveTargetForDate(
              date: DateTime(2026, 10, 3), workdays: workdays, weeklyHours: 40),
          Duration.zero);
    });

    test('leere Arbeitstage -> 0', () {
      expect(
          effectiveTargetForDate(
              date: DateTime(2026, 10, 2), workdays: const [], weeklyHours: 40),
          Duration.zero);
    });

    test('Tagessoll wird wie im Dashboard auf Minuten gerundet', () {
      // 40 h / 7 Tage = 342,857 min -> 343 min
      expect(
          effectiveTargetForDate(
              date: DateTime(2026, 10, 3),
              workdays: const [1, 2, 3, 4, 5, 6, 7],
              weeklyHours: 40),
          const Duration(minutes: 343));
    });
  });

  group('suggestOpenEntryEnd', () {
    test('Soll-Ende = Start + Soll + geschlossene Pausen, liegt es vor jetzt',
        () {
      final start = DateTime(2026, 10, 2, 8);
      final suggestion = suggestOpenEntryEnd(
        entry: entryAt(start, breaks: [
          closedBreak(DateTime(2026, 10, 2, 12), const Duration(minutes: 30)),
        ]),
        dailyTarget: eight,
        now: DateTime(2026, 10, 3, 9),
      );
      expect(suggestion.expectedEnd, DateTime(2026, 10, 2, 16, 30));
      expect(suggestion.suggestedEnd, DateTime(2026, 10, 2, 16, 30));
      expect(suggestion.suggestedIsNow, isFalse);
    });

    test('offene Pause zählt nicht zum Soll-Ende', () {
      final start = DateTime(2026, 10, 2, 8);
      final suggestion = suggestOpenEntryEnd(
        entry: entryAt(start, breaks: [
          BreakEntity(
              id: 'o', name: 'P', start: DateTime(2026, 10, 2, 12), end: null),
        ]),
        dailyTarget: eight,
        now: DateTime(2026, 10, 3, 9),
      );
      expect(suggestion.expectedEnd, DateTime(2026, 10, 2, 16));
    });

    test('Soll-Ende ist Duration-Addition (Invariante über DST-Tag 2026-10-25)',
        () {
      final start = DateTime(2026, 10, 25, 0, 0);
      final suggestion = suggestOpenEntryEnd(
        entry: entryAt(start, breaks: [
          closedBreak(DateTime(2026, 10, 25, 1), const Duration(minutes: 30)),
        ]),
        dailyTarget: eight,
        now: start.add(const Duration(hours: 20)),
      );
      expect(suggestion.expectedEnd!.difference(start),
          const Duration(hours: 8, minutes: 30));
    });

    test('Soll-Ende nach jetzt und höchstens 24 h alt -> Vorschlag "Jetzt"',
        () {
      final start = DateTime(2026, 10, 2, 22);
      final now = DateTime(2026, 10, 3, 2, 0, 40);
      final suggestion = suggestOpenEntryEnd(
          entry: entryAt(start), dailyTarget: eight, now: now);
      expect(suggestion.expectedEnd, DateTime(2026, 10, 3, 6));
      expect(suggestion.suggestedEnd, DateTime(2026, 10, 3, 2, 0));
      expect(suggestion.suggestedIsNow, isTrue);
      expect(suggestion.nowAllowed, isTrue);
    });

    test('Soll = 0: kein Soll-Ende, "Jetzt" nur bei höchstens 24 h', () {
      final start = DateTime(2026, 10, 3, 10); // Samstag
      final young = suggestOpenEntryEnd(
          entry: entryAt(start),
          dailyTarget: Duration.zero,
          now: start.add(const Duration(hours: 5)));
      expect(young.expectedEnd, isNull);
      expect(young.suggestedEnd, start.add(const Duration(hours: 5)));
      expect(young.suggestedIsNow, isTrue);

      final old = suggestOpenEntryEnd(
          entry: entryAt(start),
          dailyTarget: Duration.zero,
          now: start.add(const Duration(days: 3)));
      expect(old.expectedEnd, isNull);
      expect(old.suggestedEnd, isNull);
      expect(old.nowAllowed, isFalse);
    });

    test('"Jetzt" zulässig bei genau 24 h, unzulässig bei 24 h + 1 min', () {
      final start = DateTime(2026, 10, 2, 22);
      bool allowed(Duration age) => suggestOpenEntryEnd(
              entry: entryAt(start),
              dailyTarget: Duration.zero,
              now: start.add(age))
          .nowAllowed;
      expect(allowed(const Duration(hours: 24)), isTrue);
      expect(allowed(const Duration(hours: 24, minutes: 1)), isFalse);
    });

    test('Soll-Ende nach jetzt und älter als 24 h -> keine Vorbelegung', () {
      final start = DateTime(2026, 10, 1, 8);
      final suggestion = suggestOpenEntryEnd(
          entry: entryAt(start),
          dailyTarget: const Duration(hours: 30),
          now: start.add(const Duration(hours: 25)));
      expect(suggestion.suggestedEnd, isNull);
      expect(suggestion.nowAllowed, isFalse);
    });
  });

  group('isValidOpenEntryEnd', () {
    final start = DateTime(2026, 10, 2, 8);
    final now = DateTime(2026, 10, 3, 9);
    final withBreak = entryAt(start, breaks: [
      closedBreak(DateTime(2026, 10, 2, 12), const Duration(minutes: 30)),
    ]);

    bool valid(WorkEntryEntity e, DateTime end) =>
        isValidOpenEntryEnd(entry: e, end: end, now: now);

    test('gültig zwischen Start und jetzt', () {
      expect(valid(entryAt(start), DateTime(2026, 10, 2, 16)), isTrue);
      expect(valid(entryAt(start), now), isTrue);
    });

    test('Ende <= Start ist ungültig', () {
      expect(valid(entryAt(start), start), isFalse);
      expect(valid(entryAt(start), DateTime(2026, 10, 2, 7)), isFalse);
    });

    test('Ende nach jetzt ist ungültig', () {
      expect(
          valid(entryAt(start), now.add(const Duration(minutes: 1))), isFalse);
    });

    test('Ende vor dem Ende einer geschlossenen Pause ist ungültig', () {
      expect(valid(withBreak, DateTime(2026, 10, 2, 11, 59)), isFalse);
      expect(valid(withBreak, DateTime(2026, 10, 2, 12)), isFalse);
      expect(valid(withBreak, DateTime(2026, 10, 2, 12, 29)), isFalse);
      expect(valid(withBreak, DateTime(2026, 10, 2, 12, 30)), isTrue);
    });

    test('offene Pause: Ende nicht vor ihrem Beginn, danach gültig', () {
      final open = entryAt(start, breaks: [
        BreakEntity(
            id: 'o', name: 'P', start: DateTime(2026, 10, 2, 15), end: null),
      ]);
      expect(valid(open, DateTime(2026, 10, 2, 14, 59)), isFalse);
      expect(valid(open, DateTime(2026, 10, 2, 15)), isTrue);
    });
  });
}
