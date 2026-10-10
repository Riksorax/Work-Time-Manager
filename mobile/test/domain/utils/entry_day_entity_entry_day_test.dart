import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/utils/entry_day.dart';

/// Block B (#418): `entryDay`/`entryDayKey` sind die einzige Stelle, die den
/// Kalendertag eines Eintrags bildet. Zonenunabhaengig: die Fixtures sind
/// **inkonsistent** (Id Montag, `date` am Vortag), wie ihn eine fehlerhafte
/// Lesegrenze liefern wuerde.
WorkEntryEntity _entry(String id, DateTime date) =>
    WorkEntryEntity(id: id, date: date);

void main() {
  group('entryDay', () {
    test('gueltige Id gewinnt gegen ein abweichendes date', () {
      final e = _entry('2026-10-05', DateTime(2026, 10, 4));
      expect(entryDay(e), DateTime(2026, 10, 5));
      expect(entryDay(e).weekday, DateTime.monday);
    });

    test('Monats- und Jahresgrenze: Id gewinnt', () {
      expect(entryDay(_entry('2026-11-01', DateTime(2026, 10, 31))),
          DateTime(2026, 11, 1));
      expect(entryDay(_entry('2026-01-01', DateTime(2025, 12, 31))),
          DateTime(2026, 1, 1));
    });

    test('ungueltige Id: lokale Felder von date, Zeitanteil verworfen', () {
      for (final id in [
        '1',
        DateTime(2026, 10, 5, 13, 30).toIso8601String(),
        '2026-3-2',
        '',
      ]) {
        final e = _entry(id, DateTime(2026, 10, 5, 13, 30));
        expect(entryDay(e), DateTime(2026, 10, 5), reason: '"$id"');
      }
    });

    test('Fallback liest die lokalen Felder (nicht UTC)', () {
      // Nahe Mitternacht liegt der UTC-Tag in Berlin/LA/Auckland daneben.
      expect(entryDay(_entry('1', DateTime(2026, 10, 5, 0, 30))),
          DateTime(2026, 10, 5));
      expect(entryDay(_entry('1', DateTime(2026, 10, 5, 23, 30))),
          DateTime(2026, 10, 5));
    });

    test('Ergebnis ist lokale Mitternacht, nicht UTC', () {
      final d = entryDay(_entry('2026-10-05', DateTime(2026, 10, 4)));
      expect(d.isUtc, isFalse);
      expect(d.hour, 0);
      expect(d.minute, 0);
    });
  });

  group('entryDayKey', () {
    test('yyyy-MM-dd des Eintragstags', () {
      expect(entryDayKey(_entry('2026-10-05', DateTime(2026, 10, 4))),
          '2026-10-05');
      expect(entryDayKey(_entry('2026-11-01', DateTime(2026, 10, 31))),
          '2026-11-01');
      expect(entryDayKey(_entry('2026-01-01', DateTime(2025, 12, 31))),
          '2026-01-01');
    });

    test('Nullauffuellung bei ungueltiger Id (Fallback date)', () {
      expect(entryDayKey(_entry('1', DateTime(2026, 1, 5, 9))), '2026-01-05');
      expect(
          entryDayKey(_entry('2026-3-2', DateTime(2026, 3, 2))), '2026-03-02');
    });
  });
}
