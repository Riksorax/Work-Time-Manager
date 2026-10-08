import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/utils/overtime_utils.dart';

// Fr 2026-10-02. DST-Invarianten: 2026-10-25 (Ende Sommerzeit EU),
// 2026-03-29 (Beginn).
void main() {
  WorkEntryEntity entry({
    DateTime? date,
    DateTime? start,
    DateTime? end,
    WorkEntryType type = WorkEntryType.work,
  }) {
    final d = date ?? DateTime(2026, 10, 2);
    return WorkEntryEntity(
      id: 'x',
      date: DateTime(d.year, d.month, d.day),
      workStart: start,
      workEnd: end,
      type: type,
    );
  }

  final friStart = DateTime(2026, 10, 2, 22);
  final satMorning = DateTime(2026, 10, 3, 9);

  bool can(WorkEntryEntity e, DateTime now, {bool todayIsEmpty = true}) =>
      canResumeOpenEntry(entry: e, now: now, todayIsEmpty: todayIsEmpty);

  group('canResumeOpenEntry (#385)', () {
    test('Fr 22:00 offen, jetzt Sa 09:00, heute leer: zulässig', () {
      expect(can(entry(start: friStart), satMorning), isTrue);
    });

    test('heute nicht leer: nicht zulässig', () {
      expect(can(entry(start: friStart), satMorning, todayIsEmpty: false),
          isFalse);
    });

    for (final type in [
      WorkEntryType.vacation,
      WorkEntryType.sick,
      WorkEntryType.holiday,
    ]) {
      test('Typ $type: nicht zulässig', () {
        expect(can(entry(start: friStart, type: type), satMorning), isFalse);
      });
    }

    test('ohne Start: nicht zulässig', () {
      expect(can(entry(), satMorning), isFalse);
    });

    test('mit Ende: nicht zulässig', () {
      expect(
          can(entry(start: friStart, end: DateTime(2026, 10, 2, 23)),
              satMorning),
          isFalse);
    });

    test('Eintrag von heute: nicht zulässig', () {
      expect(
          can(
              entry(
                  date: DateTime(2026, 10, 3), start: DateTime(2026, 10, 3, 8)),
              satMorning),
          isFalse);
    });

    test('Eintrag in der Zukunft: nicht zulässig', () {
      expect(
          can(
              entry(
                  date: DateTime(2026, 10, 4), start: DateTime(2026, 10, 4, 8)),
              satMorning),
          isFalse);
    });

    test('Alter genau 24 h: zulässig (Grenze inklusiv)', () {
      final start = DateTime(2026, 10, 2, 9);
      expect(can(entry(start: start), start.add(openEntryMaxNowAge)), isTrue);
    });

    test('Alter 24 h + 1 min: nicht zulässig', () {
      final start = DateTime(2026, 10, 2, 9);
      expect(
          can(entry(start: start),
              start.add(openEntryMaxNowAge).add(const Duration(minutes: 1))),
          isFalse);
    });

    test('Mitternacht: 23:30 Starttag, jetzt 00:30 Folgetag: zulässig', () {
      expect(
          can(entry(start: DateTime(2026, 10, 2, 23, 30)),
              DateTime(2026, 10, 3, 0, 30)),
          isTrue);
    });

    test('Eintrag am selben Tag um 23:59, jetzt 23:59:30: nicht zulässig', () {
      expect(
          can(entry(start: DateTime(2026, 10, 2, 8)),
              DateTime(2026, 10, 2, 23, 59, 30)),
          isFalse);
    });

    test('DST-Ende 2026-10-25: Alter über absolute Differenz', () {
      // Start am Vortag lokal 2026-10-24 12:00; 24 h absolut später liegt
      // (je nach Zone) nicht auf derselben Wanduhrzeit. Invariante: die Grenze
      // folgt der absoluten Differenz.
      final start = DateTime(2026, 10, 24, 12);
      final limit = start.add(openEntryMaxNowAge);
      expect(can(entry(date: DateTime(2026, 10, 24), start: start), limit),
          isTrue);
      expect(
          can(entry(date: DateTime(2026, 10, 24), start: start),
              limit.add(const Duration(minutes: 1))),
          isFalse);
    });

    test('DST-Beginn 2026-03-29: Alter über absolute Differenz', () {
      final start = DateTime(2026, 3, 28, 12);
      final limit = start.add(openEntryMaxNowAge);
      expect(
          can(entry(date: DateTime(2026, 3, 28), start: start), limit), isTrue);
      expect(
          can(entry(date: DateTime(2026, 3, 28), start: start),
              limit.add(const Duration(minutes: 1))),
          isFalse);
    });
  });
}
