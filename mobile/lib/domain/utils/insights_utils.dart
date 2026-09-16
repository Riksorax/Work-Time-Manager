import '../entities/work_entry_entity.dart';

/// Durchschnittliche effektive Arbeitszeit an einem Wochentag sowie die
/// Abweichung vom Durchschnitt aller Wochentage. Siehe #134.
class WeekdayAverage {
  /// ISO-Wochentag (1 = Montag ... 7 = Sonntag).
  final int weekday;
  final Duration averageWorkDuration;
  final Duration deviationFromOverallAverage;
  final int sampleCount;

  const WeekdayAverage({
    required this.weekday,
    required this.averageWorkDuration,
    required this.deviationFromOverallAverage,
    required this.sampleCount,
  });
}

/// Ergebnis der Burnout-Streak-Erkennung (siehe #134).
class BurnoutStatus {
  /// Anzahl aufeinanderfolgender vertraglicher Arbeitstage mit
  /// Soll-Überschreitung, endend am letzten Tag im ausgewerteten Zeitraum.
  final int currentStreak;

  /// Längste im Zeitraum aufgetretene Serie.
  final int longestStreak;

  /// `true`, wenn [currentStreak] den Warnschwellwert erreicht/überschreitet.
  final bool isWarning;

  const BurnoutStatus({
    required this.currentStreak,
    required this.longestStreak,
    required this.isWarning,
  });
}

/// Ein Zeit-Bucket der Produktivitäts-Heatmap (siehe #134).
class StartTimeBucket {
  /// Stunde des Arbeitsbeginns (0-23).
  final int startHour;

  /// Durchschnittliche Abweichung der effektiven Arbeitszeit vom Tages-Soll
  /// für Einträge, die in dieser Stunde begonnen haben.
  final Duration averageOvertime;
  final int sampleCount;

  const StartTimeBucket({
    required this.startHour,
    required this.averageOvertime,
    required this.sampleCount,
  });
}

/// Effektive Arbeitszeit (Bruttozeit minus Pausen, nie negativ) für einen
/// abgeschlossenen Eintrag. Berechnet bewusst direkt aus [WorkEntryEntity.
/// totalBreakTime] statt über `effectiveWorkDuration`, da dieser Name sowohl
/// auf der Entität selbst als auch als Extension (`WorkEntryCalculations`)
/// existiert und Dart bei gleichzeitig importierter Extension den
/// Klassen-Getter bevorzugt - für abgeschlossene Einträge (workEnd != null)
/// sind beide Definitionen zwar äquivalent, die direkte Berechnung hier
/// vermeidet aber jede Mehrdeutigkeit.
Duration _effectiveDuration(WorkEntryEntity entry) {
  if (entry.workStart == null || entry.workEnd == null) return Duration.zero;
  final net = entry.workEnd!.difference(entry.workStart!) - entry.totalBreakTime;
  return net.isNegative ? Duration.zero : net;
}

Duration _average(Iterable<Duration> durations) {
  final list = durations.toList();
  if (list.isEmpty) return Duration.zero;
  final totalMicros = list.fold<int>(0, (sum, d) => sum + d.inMicroseconds);
  return Duration(microseconds: totalMicros ~/ list.length);
}

/// Berechnet je Wochentag die durchschnittliche effektive Arbeitszeit und
/// deren Abweichung vom Durchschnitt aller Wochentage - z.B. um Aussagen wie
/// "Du arbeitest mittwochs durchschnittlich 1,2h länger" zu ermöglichen.
/// Nur Einträge vom Typ [WorkEntryType.work] mit Start- und Endzeit fließen
/// ein; Wochentage ohne Daten fehlen im Ergebnis. Siehe #134.
List<WeekdayAverage> calculateWeekdayAverages(List<WorkEntryEntity> entries) {
  final byWeekday = <int, List<Duration>>{};
  for (final entry in entries) {
    if (entry.type != WorkEntryType.work || entry.workStart == null || entry.workEnd == null) {
      continue;
    }
    byWeekday.putIfAbsent(entry.date.weekday, () => []).add(_effectiveDuration(entry));
  }
  if (byWeekday.isEmpty) return [];

  final overallAverage = _average(byWeekday.values.expand((d) => d));

  final result = <WeekdayAverage>[];
  for (var weekday = 1; weekday <= 7; weekday++) {
    final durations = byWeekday[weekday];
    if (durations == null || durations.isEmpty) continue;
    final average = _average(durations);
    result.add(WeekdayAverage(
      weekday: weekday,
      averageWorkDuration: average,
      deviationFromOverallAverage: average - overallAverage,
      sampleCount: durations.length,
    ));
  }
  return result;
}

/// Ermittelt, wie viele aufeinanderfolgende vertragliche Arbeitstage
/// (Wochentage aus [workdays]) die effektive Arbeitszeit das Tages-Soll
/// [dailyTarget] überschritten hat. Nicht-vertragliche Wochentage
/// unterbrechen die Serie nicht; ein vertraglicher Arbeitstag ohne
/// Überschreitung (oder ganz ohne Eintrag) beendet sie. [currentStreak]
/// bezieht sich auf den letzten Tag im durch [entries] abgedeckten Zeitraum.
/// Siehe #134.
BurnoutStatus detectOvertimeStreak({
  required List<WorkEntryEntity> entries,
  required List<int> workdays,
  required Duration dailyTarget,
  int warningThresholdDays = 5,
}) {
  if (entries.isEmpty || workdays.isEmpty) {
    return const BurnoutStatus(currentStreak: 0, longestStreak: 0, isWarning: false);
  }

  final overTargetDays = <DateTime>{};
  DateTime? minDate;
  DateTime? maxDate;
  for (final entry in entries) {
    if (entry.type != WorkEntryType.work) continue;
    final day = DateTime(entry.date.year, entry.date.month, entry.date.day);
    if (minDate == null || day.isBefore(minDate)) minDate = day;
    if (maxDate == null || day.isAfter(maxDate)) maxDate = day;
    if (_effectiveDuration(entry) > dailyTarget) {
      overTargetDays.add(day);
    }
  }
  if (minDate == null || maxDate == null) {
    return const BurnoutStatus(currentStreak: 0, longestStreak: 0, isWarning: false);
  }

  var streak = 0;
  var longest = 0;
  for (var day = minDate; !day.isAfter(maxDate); day = day.add(const Duration(days: 1))) {
    if (!workdays.contains(day.weekday)) continue;
    if (overTargetDays.contains(day)) {
      streak++;
      if (streak > longest) longest = streak;
    } else {
      streak = 0;
    }
  }

  return BurnoutStatus(
    currentStreak: streak,
    longestStreak: longest,
    isWarning: streak >= warningThresholdDays,
  );
}

/// Gruppiert Arbeitseinträge nach der Startstunde und berechnet je Bucket
/// die durchschnittliche Abweichung der effektiven Arbeitszeit vom
/// Tages-Soll [dailyTarget] - zeigt, zu welcher Startzeit im Schnitt am
/// produktivsten gearbeitet wurde. Buckets mit weniger als
/// [minSampleCount] Einträgen werden ausgeschlossen (zu wenig Datenbasis
/// für eine verlässliche Aussage). Siehe #134.
List<StartTimeBucket> buildStartTimeHeatmap({
  required List<WorkEntryEntity> entries,
  required Duration dailyTarget,
  int minSampleCount = 2,
}) {
  final byHour = <int, List<Duration>>{};
  for (final entry in entries) {
    if (entry.type != WorkEntryType.work || entry.workStart == null) continue;
    final overtime = _effectiveDuration(entry) - dailyTarget;
    byHour.putIfAbsent(entry.workStart!.hour, () => []).add(overtime);
  }

  final buckets = <StartTimeBucket>[];
  for (final MapEntry(key: hour, value: overtimes) in byHour.entries) {
    if (overtimes.length < minSampleCount) continue;
    buckets.add(StartTimeBucket(
      startHour: hour,
      averageOvertime: _average(overtimes),
      sampleCount: overtimes.length,
    ));
  }
  buckets.sort((a, b) => a.startHour.compareTo(b.startHour));
  return buckets;
}
