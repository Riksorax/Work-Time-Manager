import 'package:intl/intl.dart';

/// Formatiert eine Uhrzeit gemäß der Nutzer-Einstellung 24h/12h (siehe #218).
///
/// [use24HourFormat] kommt aus `SettingsEntity.use24HourFormat`
/// (`ref.watch(settingsViewModelProvider).value?.settings.use24HourFormat`).
String formatTime(DateTime time, {required bool use24HourFormat}) {
  final pattern = use24HourFormat ? 'HH:mm' : 'h:mm a';
  return DateFormat(pattern, 'de_DE').format(time);
}
