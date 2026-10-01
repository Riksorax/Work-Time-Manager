import '../../domain/utils/break_names.dart';
import '../../l10n/app_localizations.dart';

/// Anzeigename einer Pause in der App-Sprache. Standardnamen werden übersetzt,
/// frei vergebene Namen bleiben unverändert (siehe #346).
String localizedBreakName(String name, AppLocalizations l10n) {
  final parsed = parseDefaultBreakName(name);
  if (parsed == null) return name;
  return switch (parsed.kind) {
    DefaultBreakNameKind.plain => l10n.breakDefaultName,
    DefaultBreakNameKind.numbered => l10n.breakNumberedName(parsed.number!),
    DefaultBreakNameKind.automatic => l10n.breakAutomaticName,
    DefaultBreakNameKind.lunch => l10n.breakLunchName,
    DefaultBreakNameKind.short => l10n.breakShortName,
  };
}
