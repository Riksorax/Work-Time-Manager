import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_work_time/core/utils/timezone_utils.dart';

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
  });

  group('applyTimezone', () {
    test('setzt tz.local auf die übergebene manuelle Zeitzone', () async {
      await applyTimezone('Europe/London');
      expect(tz.local.name, 'Europe/London');
    });

    test('fällt bei unbekannter Zeitzone auf die Systemzeitzone-Ermittlung zurück, '
        'die im Test ohne Plattform-Kanal wiederum auf Europe/Berlin/UTC zurückfällt', () async {
      await applyTimezone('Not/AZone');
      expect(['Europe/Berlin', 'UTC'], contains(tz.local.name));
    });

    test('ohne Override wird die Systemzeitzone ermittelt (fällt im Test '
        'mangels Plattform-Kanal auf Europe/Berlin/UTC zurück)', () async {
      await applyTimezone(null);
      expect(['Europe/Berlin', 'UTC'], contains(tz.local.name));
    });
  });
}
