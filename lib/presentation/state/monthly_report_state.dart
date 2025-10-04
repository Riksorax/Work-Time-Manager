import 'package:flutter/foundation.dart';

@immutable
class MonthlyReportState {
  final Duration totalWorkDuration;
  final Duration totalBreakDuration;
  final Duration totalNetWorkDuration;
  final Duration averageWorkDuration; // This is effectively avgWorkDurationPerDay
  final Duration overtime;
  final Duration totalOvertime; // Überstunden inkl. heute
  final int workDays;
  final Map<int, Duration> weeklyWork;
  final Map<DateTime, Duration> dailyWork;
  final Duration avgWorkDurationPerWeek; // Added field

  const MonthlyReportState({
    this.totalWorkDuration = Duration.zero,
    this.totalBreakDuration = Duration.zero,
    this.totalNetWorkDuration = Duration.zero,
    this.averageWorkDuration = Duration.zero, // Remains as avgWorkDurationPerDay
    this.overtime = Duration.zero,
    this.totalOvertime = Duration.zero,
    this.workDays = 0,
    this.weeklyWork = const {},
    this.dailyWork = const {},
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
