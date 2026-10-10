import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Januar-Offsets (sommerzeitfest) der Zonen, die die `*_tz_test.dart`-Dateien
/// (#418) in CI und lokal abdecken.
const Map<String, Duration> _januaryOffsets = {
  'UTC': Duration.zero,
  'Europe/Berlin': Duration(hours: 1),
  'America/Los_Angeles': Duration(hours: -8),
  'Pacific/Auckland': Duration(hours: 13),
};

/// Registriert in einer `*_tz_test.dart` einen Canary-Test.
///
/// Die Zone der Dart-VM kommt ausschliesslich aus der Umgebungsvariable `TZ`
/// des Prozesses `flutter test`; es gibt keinen Weg, sie innerhalb eines Tests
/// zu setzen. Ist `TZ` gesetzt, aber auf dem Host unbekannt (fehlende tzdata,
/// Tippfehler), faellt libc **stillschweigend auf UTC** zurueck: ein Test, der
/// unter `America/Los_Angeles` rot sein muss, waere dann gruen und der CI-Schritt
/// wertlos. Der Canary prueft deshalb, dass die angeforderte Zone wirklich
/// wirkt. Ist `TZ` nicht gesetzt oder keine der bekannten Zonen, behauptet er
/// nichts (die Assertions der Tests gelten in jeder Zone).
void registerTimezoneCanary() {
  test('Zeitzonen-Canary: TZ wirkt im Testprozess', () {
    final tz = Platform.environment['TZ'];
    final expected = tz == null ? null : _januaryOffsets[tz];
    if (expected == null) return;
    expect(DateTime(2026, 1, 15, 12).timeZoneOffset, expected,
        reason: 'TZ=$tz ist gesetzt, wirkt aber nicht (tzdata fehlt?). '
            'Ein Lauf waere sonst still in UTC.');
  });
}
