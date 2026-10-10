/// Kalendertag eines Arbeitseintrags (#418).
///
/// Schreibformat (unveraendert): `date` ist die **UTC-Mitternacht** des lokalen
/// Kalendertags (`WorkEntryModel.toMap`, `ApiClient._entryToJson`). Beim Lesen
/// darf daraus kein Zeitpunkt in lokalen Feldern werden: westlich von UTC
/// ergibt `.toLocal()` den Vortag (Los Angeles: 05.10. 00:00Z -> 04.10. 17:00).
///
/// Die Lesegrenzen nutzen deshalb diese Funktionen; danach ist
/// `WorkEntryEntity.date` die **lokale Mitternacht** des Kalendertags.
/// Reine Dart-Funktionen, kein Intl.
library;

final RegExp _entryIdPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// Kalendertag aus einer Eintrags-`id` im Format `yyyy-MM-dd` als lokale
/// Mitternacht, sonst `null`.
///
/// `null` bei jedem anderen Format (`'1'`, ISO-Zeitpunkt wie
/// `DashboardState.initial`, nicht aufgefuellt `'2026-3-2'`) und bei
/// ueberlaufenden Werten (`2026-13-45`, `2026-02-30`): `DateTime` normalisiert
/// solche Werte still, deshalb prueft die Funktion die Komponenten zurueck.
DateTime? localDateFromEntryId(String id) {
  if (!_entryIdPattern.hasMatch(id)) return null;
  final year = int.parse(id.substring(0, 4));
  final month = int.parse(id.substring(5, 7));
  final day = int.parse(id.substring(8, 10));
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

/// Lokale Mitternacht des Kalendertags, der in den **UTC-Feldern** von [d]
/// steht (Jahr/Monat/Tag nach `toUtc()`).
///
/// Nur fuer Lesegrenzen ohne Tages-Key (Fallback bei ungueltiger Id) und fuer
/// Berichtstage des Backends (`days[].date`, immer UTC-Mitternacht). Der
/// Zeitanteil wird verworfen.
DateTime calendarDateFromUtcMidnight(DateTime d) {
  final utc = d.toUtc();
  return DateTime(utc.year, utc.month, utc.day);
}
