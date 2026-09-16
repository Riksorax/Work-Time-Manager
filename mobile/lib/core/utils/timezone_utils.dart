import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;

import 'logger.dart';

/// SharedPreferences-Schlüssel für die manuelle Zeitzone-Überschreibung.
/// Zentral definiert, da sowohl `main.dart` (App-Start) als auch das
/// Settings-Repository ihn lesen/schreiben müssen. Siehe #221.
const String timezoneOverridePrefsKey = 'timezone_override';

/// Setzt die lokale Zeitzone für [tz.local] anhand einer manuellen
/// Überschreibung ([override], IANA-Kennung) oder, falls `null`, anhand der
/// vom Betriebssystem gemeldeten Systemzeitzone. Siehe #221.
///
/// Fällt bei Fehlern (unbekannte Kennung, Plattform ohne Systemzeitzonen-
/// Auskunft) auf `Europe/Berlin` bzw. zuletzt `UTC` zurück, damit die App in
/// jedem Fall eine gültige Zeitzone hat.
Future<void> applyTimezone(String? override) async {
  if (override != null) {
    try {
      tz.setLocalLocation(tz.getLocation(override));
      return;
    } catch (e) {
      logger.w('[Timezone] Unbekannte manuelle Zeitzone "$override", falle zurück: $e');
    }
  }

  try {
    final systemTimezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(systemTimezone.toString()));
  } catch (e) {
    logger.w('[Timezone] Systemzeitzone nicht ermittelbar, falle auf Europe/Berlin/UTC zurück: $e');
    try {
      tz.setLocalLocation(tz.getLocation('Europe/Berlin'));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }
}
