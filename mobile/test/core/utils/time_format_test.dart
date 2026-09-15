import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/utils/time_format.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('de_DE', null);
  });

  group('formatTime', () {
    test('24-Stunden-Format zeigt HH:mm', () {
      final time = DateTime(2026, 1, 15, 18, 5);
      expect(formatTime(time, use24HourFormat: true), '18:05');
    });

    test('24-Stunden-Format am Vormittag mit führender Null', () {
      final time = DateTime(2026, 1, 15, 8, 0);
      expect(formatTime(time, use24HourFormat: true), '08:00');
    });

    test('12-Stunden-Format zeigt AM/PM-Variante für Nachmittag', () {
      final time = DateTime(2026, 1, 15, 18, 5);
      final formatted = formatTime(time, use24HourFormat: false);
      // 18:05 -> 6:05 nachmittags. Genaues AM/PM-Kürzel hängt von der
      // ICU-Locale-Daten-Version ab (z.B. "PM" oder "nachm."), daher wird
      // nur die Stunden-/Minuten-Umrechnung geprüft.
      expect(formatted, startsWith('6:05'));
    });

    test('12-Stunden-Format zeigt 12 für Mitternacht', () {
      final time = DateTime(2026, 1, 15, 0, 30);
      final formatted = formatTime(time, use24HourFormat: false);
      expect(formatted, startsWith('12:30'));
    });

    test('12-Stunden-Format zeigt 12 für Mittag', () {
      final time = DateTime(2026, 1, 15, 12, 0);
      final formatted = formatTime(time, use24HourFormat: false);
      expect(formatted, startsWith('12:00'));
    });
  });
}
