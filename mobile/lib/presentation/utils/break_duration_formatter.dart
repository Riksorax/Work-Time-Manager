import '../../l10n/app_localizations.dart';

/// Pausendauer in vollen Minuten (abgerundet, wie im restlichen Dashboard):
/// "< 1 Min", "30 Min", "1 Std 5 Min" bzw. englisch "< 1 min", "30 min", "1 h 5 min" (#504).
String formatBreakDuration(Duration d, AppLocalizations l10n) {
  final totalMinutes = d.isNegative ? 0 : d.inMinutes;
  if (totalMinutes < 1) return l10n.breakDurationLessThanMinute;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours < 1) return l10n.breakDurationMinutes(minutes);
  return l10n.breakDurationHoursMinutes(hours, minutes);
}
