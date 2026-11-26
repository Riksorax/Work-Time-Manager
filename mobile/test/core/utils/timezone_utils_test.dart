import 'package:flutter/services.dart';
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

    test(
        'fällt bei unbekannter Zeitzone auf die Systemzeitzone-Ermittlung zurück, '
        'die im Test ohne Plattform-Kanal wiederum auf Europe/Berlin/UTC zurückfällt',
        () async {
      await applyTimezone('Not/AZone');
      expect(['Europe/Berlin', 'UTC'], contains(tz.local.name));
    });

    test(
        'ohne Override wird die Systemzeitzone ermittelt (fällt im Test '
        'mangels Plattform-Kanal auf Europe/Berlin/UTC zurück)', () async {
      await applyTimezone(null);
      expect(['Europe/Berlin', 'UTC'], contains(tz.local.name));
    });
  });

  group('DeviceTimeZone (#537)', () {
    const channel = MethodChannel('flutter_timezone');
    TestWidgetsFlutterBinding.ensureInitialized();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('liefert die Systemzeitzone, nicht die manuelle Überschreibung',
        () async {
      messenger.setMockMethodCallHandler(
          channel, (call) async => 'America/Los_Angeles');
      tz.setLocalLocation(tz.getLocation('Europe/London')); // Override
      expect(await const DeviceTimeZone().ianaName(), 'America/Los_Angeles');
    });

    test('ohne Plattform-Kanal: tz.local', () async {
      tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));
      expect(await const DeviceTimeZone().ianaName(), 'Asia/Tokyo');
    });

    test('Fehler des Kanals: tz.local', () async {
      messenger.setMockMethodCallHandler(
          channel, (call) async => throw PlatformException(code: 'x'));
      tz.setLocalLocation(tz.getLocation('Europe/Berlin'));
      expect(await const DeviceTimeZone().ianaName(), 'Europe/Berlin');
    });
  });
}
