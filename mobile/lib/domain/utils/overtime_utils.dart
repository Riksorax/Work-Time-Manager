import 'package:flutter_work_time/core/utils/time_precision.dart';

import '../entities/work_entry_entity.dart';
import 'date_utils.dart';

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
      addCalendarDays(normalizedDate, -(normalizedDate.weekday - 1));
  final endOfWeek = addCalendarDays(startOfWeek, 6);

  return monthlyEntries.where((entry) {
    final entryDate =
        DateTime(entry.date.year, entry.date.month, entry.date.day);
    return !entryDate.isBefore(startOfWeek) && !entryDate.isAfter(endOfWeek);
  }).toList();
}

/// Tages-Soll für [date] aus den Einstellungen (Arbeitstage, Wochenstunden).
///
/// Gleiche Formel wie im Dashboard: Wochenstunden / Anzahl Arbeitstage, auf
/// Minuten gerundet; Nicht-Arbeitstage und leere Arbeitstage ergeben 0.
Duration effectiveTargetForDate({
  required DateTime date,
  required List<int> workdays,
  required double weeklyHours,
}) {
  if (workdays.isEmpty) return Duration.zero;
  final regularDailyTarget = roundDurationToMinute(Duration(
    microseconds:
        (weeklyHours / workdays.length * Duration.microsecondsPerHour).round(),
  ));
  return getEffectiveDailyTarget(
    date: date,
    workdays: workdays,
    regularDailyTarget: regularDailyTarget,
  );
}

/// Ab diesem Alter wird "Jetzt" als Ende eines offenen Eintrags nicht mehr
/// angeboten (#385): es entstünde eine riesige Dauer.
const Duration openEntryMaxNowAge = Duration(hours: 24);

/// Vorschlag für das Ende eines offenen Eintrags vor heute (#385).
class OpenEntryEndSuggestion {
  const OpenEntryEndSuggestion({
    required this.expectedEnd,
    required this.suggestedEnd,
    required this.suggestedIsNow,
    required this.nowAllowed,
  });

  /// Start + Soll + geschlossene Pausen; `null` bei Soll = 0.
  final DateTime? expectedEnd;

  /// Vorbelegung im Dialog; `null` = keine sinnvolle Vorbelegung.
  final DateTime? suggestedEnd;

  /// `true`, wenn [suggestedEnd] "jetzt" (auf Minute abgeschnitten) ist.
  final bool suggestedIsNow;

  /// Ob "Jetzt" gewählt werden darf (Eintrag höchstens 24 h alt).
  final bool nowAllowed;
}

/// Berechnet den Ende-Vorschlag für [entry] (reine Funktion, per
/// Duration-Addition, also unabhängig von Sommerzeit-Wanduhrsprüngen).
///
/// Liegt das Soll-Ende vor [now], ist es der Vorschlag. Sonst "Jetzt", falls
/// der Eintrag höchstens 24 h alt ist, andernfalls keine Vorbelegung.
OpenEntryEndSuggestion suggestOpenEntryEnd({
  required WorkEntryEntity entry,
  required Duration dailyTarget,
  required DateTime now,
}) {
  final start = entry.workStart!;
  final closedBreaks = entry.breaks.fold<Duration>(Duration.zero,
      (sum, b) => sum + (b.end?.difference(b.start) ?? Duration.zero));
  final expectedEnd = dailyTarget > Duration.zero
      ? start.add(dailyTarget).add(closedBreaks)
      : null;
  final nowAllowed = now.difference(start) <= openEntryMaxNowAge;

  if (expectedEnd != null && expectedEnd.isBefore(now)) {
    return OpenEntryEndSuggestion(
      expectedEnd: expectedEnd,
      suggestedEnd: expectedEnd,
      suggestedIsNow: false,
      nowAllowed: nowAllowed,
    );
  }
  return OpenEntryEndSuggestion(
    expectedEnd: expectedEnd,
    suggestedEnd: nowAllowed ? roundToMinute(now) : null,
    suggestedIsNow: nowAllowed,
    nowAllowed: nowAllowed,
  );
}

/// Ob [end] ein gültiges Ende für den offenen [entry] ist (#385): nach dem
/// Start, nicht nach [now] und nicht vor dem Beginn einer Pause. Ein Ende, das
/// nicht auf Minuten gerundet ist, wird so geprüft, wie es übergeben wird.
bool isValidOpenEntryEnd({
  required WorkEntryEntity entry,
  required DateTime end,
  required DateTime now,
}) {
  if (!end.isAfter(entry.workStart!)) return false;
  if (end.isAfter(now)) return false;
  for (final b in entry.breaks) {
    if (end.isBefore(b.start)) return false;
  }
  return true;
}
