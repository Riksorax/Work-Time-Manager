import 'package:intl/intl.dart';

/// Formatiert eine Uhrzeit gemäß der Nutzer-Einstellung 24h/12h (siehe #218).
///
/// [use24HourFormat] kommt aus `SettingsEntity.use24HourFormat`
/// (`ref.watch(settingsViewModelProvider).value?.settings.use24HourFormat`).
///
/// Bewusst ohne expliziten Locale-Parameter: `DateFormat(pattern, 'de_DE')`
/// verlangt initialisierte de_DE-Locale-Daten (`initializeDateFormatting`),
/// die in schlanken Widget-Tests ohne vollen main()-Bootstrap nicht
/// vorhanden sind und dort eine LocaleDataException auslösen würden.
/// Ohne Locale-Argument nutzt DateFormat `Intl.defaultLocale` (in der
/// echten App per main.dart auf 'de_DE' gesetzt) bzw. sonst die immer
/// verfügbare Standard-Locale - genau wie das vorherige `DateFormat('HH:mm')`
/// ohne Locale-Argument, das nie eine Initialisierung brauchte.
String formatTime(DateTime time, {required bool use24HourFormat}) {
  final pattern = use24HourFormat ? 'HH:mm' : 'h:mm a';
  return DateFormat(pattern).format(time);
}
