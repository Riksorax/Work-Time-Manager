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
      logger.w(
          '[Timezone] Unbekannte manuelle Zeitzone "$override", falle zurück: $e');
    }
  }

  try {
    final systemTimezone = await FlutterTimezone.getLocalTimezone();
    // flutter_timezone 5.x liefert ein TimezoneInfo; `toString()` ist keine IANA-Kennung.
    tz.setLocalLocation(tz.getLocation(systemTimezone.identifier));
  } catch (e) {
    logger.w(
        '[Timezone] Systemzeitzone nicht ermittelbar, falle auf Europe/Berlin/UTC zurück: $e');
    try {
      tz.setLocalLocation(tz.getLocation('Europe/Berlin'));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }
}

/// IANA-Name der Zeitzone des Geräts für Anfragen ans Backend (#537, Insights:
/// Startstunde der Heatmap).
///
/// Bewusst die **Systemzeitzone** und nicht die manuelle Überschreibung
/// (`timezone_override`, wirkt nur auf [tz.local] für Benachrichtigungen):
/// Die App zeigt Uhrzeiten wie `DateTime.hour` in der Systemzeitzone, die
/// bisherige lokale Heatmap nutzte genau diese Stunde. Ist sie nicht
/// ermittelbar, gilt [tz.local], zuletzt `Europe/Berlin` (wie [applyTimezone]).
class DeviceTimeZone {
  const DeviceTimeZone();

  Future<String> ianaName() async {
    try {
      final id = (await FlutterTimezone.getLocalTimezone()).identifier;
      if (id.isNotEmpty) return id;
    } catch (e) {
      logger.i('[Timezone] Systemzeitzone nicht ermittelbar: ${e.runtimeType}');
    }
    try {
      return tz.local.name;
    } catch (_) {
      return 'Europe/Berlin';
    }
  }
}
