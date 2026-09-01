import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/utils/time_precision.dart';

void main() {
  group('roundToMinute', () {
    test('schneidet Sekunden unter 30 ab', () {
      expect(
        roundToMinute(DateTime(2024, 5, 6, 8, 0, 29, 999)),
        DateTime(2024, 5, 6, 8, 0),
      );
    });

    test('schneidet auch ab genau 30 Sekunden ab statt aufzurunden', () {
      expect(
        roundToMinute(DateTime(2024, 5, 6, 8, 0, 30)),
        DateTime(2024, 5, 6, 8, 0),
      );
    });

    test('schneidet auch kurz vor der nächsten Minute ab', () {
      expect(
        roundToMinute(DateTime(2024, 5, 6, 8, 0, 59, 999)),
        DateTime(2024, 5, 6, 8, 0),
      );
    });

    test('lässt eine volle Minute unverändert', () {
      final exact = DateTime(2024, 5, 6, 8, 0);
      expect(roundToMinute(exact), exact);
    });

    test('rundet nie über die Stunden- oder Tagesgrenze auf', () {
      expect(
        roundToMinute(DateTime(2024, 5, 6, 8, 59, 45)),
        DateTime(2024, 5, 6, 8, 59),
      );
      expect(
        roundToMinute(DateTime(2024, 5, 6, 23, 59, 45)),
        DateTime(2024, 5, 6, 23, 59),
      );
    });

    test('entfernt auch Millisekunden und Mikrosekunden', () {
      expect(
        roundToMinute(DateTime(2024, 5, 6, 8, 0, 10, 500, 250)),
        DateTime(2024, 5, 6, 8, 0),
      );
    });
  });

  group('roundToMinuteOrNull', () {
    test('gibt null für null zurück', () {
      expect(roundToMinuteOrNull(null), isNull);
    });

    test('schneidet einen vorhandenen Wert ab, statt ihn aufzurunden', () {
      expect(
        roundToMinuteOrNull(DateTime(2024, 5, 6, 8, 0, 40)),
        DateTime(2024, 5, 6, 8, 0),
      );
    });
  });

  group('nowToMinute', () {
    test('liefert immer einen Zeitstempel ohne Sekundenanteil', () {
      final now = nowToMinute();
      expect(now.second, 0);
      expect(now.millisecond, 0);
      expect(now.microsecond, 0);
    });
  });

  group('roundDurationToMinute', () {
    test('rundet positive Dauern kaufmännisch', () {
      expect(
        roundDurationToMinute(const Duration(minutes: 5, seconds: 29)),
        const Duration(minutes: 5),
      );
      expect(
        roundDurationToMinute(const Duration(minutes: 5, seconds: 30)),
        const Duration(minutes: 6),
      );
    });

    test('rundet negative Dauern symmetrisch', () {
      expect(
        roundDurationToMinute(const Duration(minutes: -5, seconds: -29)),
        const Duration(minutes: -5),
      );
      expect(
        roundDurationToMinute(const Duration(minutes: -5, seconds: -30)),
        const Duration(minutes: -6),
      );
    });
  });

  group('toStoredMinutes', () {
    test('gibt gerundete volle Minuten zurück', () {
      expect(toStoredMinutes(const Duration(hours: 1, seconds: 31)), 61);
      expect(toStoredMinutes(const Duration(hours: -1, seconds: -31)), -61);
    });
  });
}
