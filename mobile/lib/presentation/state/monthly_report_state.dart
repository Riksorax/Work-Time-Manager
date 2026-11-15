import 'package:flutter/foundation.dart';

@immutable
class MonthlyReportState {
  final Duration totalWorkDuration;
  final Duration totalBreakDuration;
  final Duration totalNetWorkDuration;
  final Duration
      averageWorkDuration; // This is effectively avgWorkDurationPerDay
  final Duration overtime;
  final Duration totalOvertime; // Überstunden inkl. heute
  final int workDays;

  /// Brutto je ISO-Woche (`weeks[].totalWorkedMs`), nur Tage des Monats.
  final Map<int, Duration> weeklyWork;

  /// Brutto je Tag (`days[].workedMs`), Abwesenheit mit dem Tagessoll.
  final Map<DateTime, Duration> dailyWork;

  /// Netto je ISO-Woche (`weeks[].netWorkedMs`, #551), nur Tage des Monats.
  /// Die Wochenzeilen der Berichte und des PDFs zeigen diese Werte.
  final Map<int, Duration> weeklyNetWork;

  /// Netto je Tag (`days[].netWorkedMs`, #551): brutto − abgeschlossene
  /// Pausen, nicht bei 0 gekappt. Die Tageszeilen der Berichte und des PDFs
  /// zeigen diese Werte; ihre Summe ist [totalNetWorkDuration].
  final Map<DateTime, Duration> dailyNetWork;
  final Duration avgWorkDurationPerWeek; // Added field

  const MonthlyReportState({
    this.totalWorkDuration = Duration.zero,
    this.totalBreakDuration = Duration.zero,
    this.totalNetWorkDuration = Duration.zero,
    this.averageWorkDuration =
        Duration.zero, // Remains as avgWorkDurationPerDay
    this.overtime = Duration.zero,
    this.totalOvertime = Duration.zero,
    this.workDays = 0,
    this.weeklyWork = const {},
    this.dailyWork = const {},
    this.weeklyNetWork = const {},
    this.dailyNetWork = const {},
    this.avgWorkDurationPerWeek = Duration.zero, // Added to constructor
  });

  /// Durchschnittliche Arbeitszeit pro Tag (getter for clarity, value is in averageWorkDuration)
  Duration get avgWorkDurationPerDay {
    // This getter can remain if it provides clarity,
    // or averageWorkDuration can be renamed to avgWorkDurationPerDay
    // For now, let's assume averageWorkDuration holds the per-day average.
    if (workDays == 0) return Duration.zero;
    // Recalculate if averageWorkDuration is not specifically per day
    // or ensure averageWorkDuration is correctly calculated as per day average
    return averageWorkDuration;
  }

  // Removed the old getter for avgWorkDurationPerWeek as it's now a field

  static const MonthlyReportState initial = MonthlyReportState(
    totalOvertime: Duration.zero,
    // avgWorkDurationPerWeek will use its default Duration.zero here
  );
}
