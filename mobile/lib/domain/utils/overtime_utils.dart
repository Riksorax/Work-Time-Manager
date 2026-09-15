import '../entities/work_entry_entity.dart';

/// Bestimmt das effektive Tages-Soll für einen bestimmten Tag.
///
/// Tage, deren Wochentag zur Menge der konfigurierten Arbeitstage
/// [workdays] gehört (ISO-Wochentage, 1 = Montag ... 7 = Sonntag), erhalten
/// das reguläre Tages-Soll. Alle anderen Tage - auch wenn dort gearbeitet
/// wurde - erhalten ein Tages-Soll von 0, die dort geleistete Arbeit zählt
/// vollständig als Überstunden. Ersetzt die frühere rein ordinale Zählung
/// ("die ersten N Arbeitstage der Woche"), die bei nicht-Montag-startenden
/// Arbeitswochen (z.B. Di-Sa) falsche Tage als Soll-Tage behandelte (#217).
Duration getEffectiveDailyTarget({
  required DateTime date,
  required List<int> workdays,
  required Duration regularDailyTarget,
}) {
  return workdays.contains(date.weekday) ? regularDailyTarget : Duration.zero;
}

/// Berechnet die effektive Anzahl der Arbeitstage für die Soll-Berechnung.
///
/// Zählt nur die Tage, deren Wochentag zur Menge der konfigurierten
/// Arbeitstage [workdays] gehört - Zusatztage an anderen Wochentagen
/// erhöhen das Soll nicht (siehe #217).
int getEffectiveWorkDays({
  required List<WorkEntryEntity> entries,
  required List<int> workdays,
}) {
  final uniqueDays = entries
      .where((e) => e.workStart != null)
      .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
      .toSet();
  return uniqueDays.where((d) => workdays.contains(d.weekday)).length;
}

/// Ermittelt die Einträge für die Woche eines gegebenen Datums aus einer
/// Liste von Monatseinträgen.
List<WorkEntryEntity> getWeekEntriesForDate(
  DateTime date,
  List<WorkEntryEntity> monthlyEntries,
) {
  final normalizedDate = DateTime(date.year, date.month, date.day);
  final startOfWeek =
      normalizedDate.subtract(Duration(days: normalizedDate.weekday - 1));
  final endOfWeek = startOfWeek.add(const Duration(days: 6));

  return monthlyEntries.where((entry) {
    final entryDate =
        DateTime(entry.date.year, entry.date.month, entry.date.day);
    return !entryDate.isBefore(startOfWeek) && !entryDate.isAfter(endOfWeek);
  }).toList();
}
