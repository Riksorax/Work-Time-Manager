import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/utils/entry_day.dart';

import '../../support/timezone_guard.dart';

/// Unit-Tests der Lesegrenzen-Helfer (#418). Die Assertions pruefen Kalendertage
/// und gelten in jeder Zone; lokal ausserdem
/// `TZ=America/Los_Angeles flutter test <datei>` (und Auckland/Berlin/UTC).
void main() {
  registerTimezoneCanary();

  group('localDateFromEntryId', () {
    test('gueltige Id ergibt die lokale Mitternacht des Tages', () {
      final d = localDateFromEntryId('2026-10-05')!;
      expect(d, DateTime(2026, 10, 5));
      expect(d.isUtc, isFalse);
      expect(d.hour, 0);
      expect(d.minute, 0);
      expect(d.weekday, DateTime.monday);
    });

    test('Monatserster, Jahresgrenze, Schaltjahr', () {
      expect(localDateFromEntryId('2026-11-01'), DateTime(2026, 11, 1));
      expect(localDateFromEntryId('2026-01-01'), DateTime(2026, 1, 1));
      expect(localDateFromEntryId('2026-12-31'), DateTime(2026, 12, 31));
      expect(localDateFromEntryId('2024-02-29'), DateTime(2024, 2, 29));
    });

    test('Sommerzeitwechsel-Tage bleiben lokale Mitternacht', () {
      expect(localDateFromEntryId('2026-03-29'), DateTime(2026, 3, 29));
      expect(localDateFromEntryId('2026-10-25'), DateTime(2026, 10, 25));
    });

    test('ungueltige Ids liefern null', () {
      const invalid = [
        '',
        '1',
        '2026-3-2', // nicht nullaufgefuellt
        '2026-10-05T12:30:00.000', // ISO-Zeitpunkt (DashboardState.initial)
        '2026-10-05 ',
        ' 2026-10-05',
        '2026-10',
        '20261005',
        '2026-13-45', // Ueberlauf
        '2026-02-30', // Ueberlauf
        '2026-00-10',
        '2026-10-00',
        '2026-10-32',
        '2026-02-29', // kein Schaltjahr
        'abcd-ef-gh',
      ];
      for (final id in invalid) {
        expect(localDateFromEntryId(id), isNull, reason: '"$id"');
      }
    });
  });

  group('calendarDateFromUtcMidnight', () {
    test('UTC-Mitternacht ergibt den Kalendertag als lokale Mitternacht', () {
      final d = calendarDateFromUtcMidnight(DateTime.utc(2026, 10, 5));
      expect(d, DateTime(2026, 10, 5));
      expect(d.isUtc, isFalse);
      expect(d.hour, 0);
    });

    test('geparste Zeichenketten mit Z und +00:00', () {
      expect(
          calendarDateFromUtcMidnight(DateTime.parse('2026-10-05T00:00:00Z')),
          DateTime(2026, 10, 5));
      expect(
          calendarDateFromUtcMidnight(
              DateTime.parse('2026-10-05T00:00:00.000+00:00')),
          DateTime(2026, 10, 5));
    });

    test('nicht-UTC-Eingabe wird ueber toUtc() gelesen', () {
      final local = DateTime.utc(2026, 10, 5).toLocal();
      expect(local.isUtc, isFalse);
      expect(calendarDateFromUtcMidnight(local), DateTime(2026, 10, 5));
    });

    test('Monatserster und Jahresgrenze', () {
      expect(calendarDateFromUtcMidnight(DateTime.utc(2026, 11, 1)),
          DateTime(2026, 11, 1));
      expect(calendarDateFromUtcMidnight(DateTime.utc(2026, 1, 1)),
          DateTime(2026, 1, 1));
    });

    test('Zeitanteil wird verworfen (nur die UTC-Felder zaehlen)', () {
      expect(calendarDateFromUtcMidnight(DateTime.utc(2026, 10, 5, 22, 30)),
          DateTime(2026, 10, 5));
    });
  });
}
