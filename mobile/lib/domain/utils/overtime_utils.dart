import 'dart:math';

import '../entities/work_entry_entity.dart';

/// Bestimmt das effektive Tages-Soll für einen bestimmten Tag unter
/// Berücksichtigung der Wochenkontext.
///
/// Die ersten [workdaysPerWeek] Arbeitstage (chronologisch sortiert) einer
/// Woche erhalten das reguläre Tages-Soll. Alle weiteren Tage ("Zusatztage")
/// erhalten ein Tages-Soll von 0 — dort geleistete Arbeit zählt vollständig
/// als Überstunden.
Duration getEffectiveDailyTarget({
  required DateTime date,
  required List<WorkEntryEntity> weekEntries,
  required int workdaysPerWeek,
  required Duration regularDailyTarget,
}) {
  // Unique Arbeitstage der Woche ermitteln, chronologisch sortiert
  final workDays = weekEntries
      .where((e) => e.workStart != null)
      .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
      .toSet()
      .toList()
    ..sort();

  final normalizedDate = DateTime(date.year, date.month, date.day);
  final dayIndex = workDays.indexOf(normalizedDate);

  // Tag nicht in Einträgen → reguläres Soll (neuer Arbeitstag)
  if (dayIndex == -1) return regularDailyTarget;

  // Innerhalb der konfigurierten Arbeitstage → reguläres Soll
  if (dayIndex < workdaysPerWeek) return regularDailyTarget;

  // Zusatztag → kein Soll
  return Duration.zero;
}

/// Berechnet die effektive Anzahl der Arbeitstage für die Soll-Berechnung.
///
/// Begrenzt die Anzahl auf [workdaysPerWeek], damit das Wochen-Soll nicht
/// über das konfigurierte Wochensoll steigt.
int getEffectiveWorkDays({
  required List<WorkEntryEntity> entries,
  required int workdaysPerWeek,
}) {
  final uniqueDays = entries
      .where((e) => e.workStart != null)
      .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
      .toSet()
      .length;
  return min(uniqueDays, workdaysPerWeek);
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
