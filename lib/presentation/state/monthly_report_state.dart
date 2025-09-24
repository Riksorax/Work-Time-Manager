import 'package:flutter/foundation.dart';

@immutable
class MonthlyReportState {
  final Duration totalWorkDuration;
  final Duration totalBreakDuration;
  final Duration totalNetWorkDuration;
  final Duration averageWorkDuration;
  final Duration overtime;
  final Duration totalOvertime; // Überstunden inkl. heute
  final int workDays;
  final Map<int, Duration> weeklyWork;
  final Map<DateTime, Duration> dailyWork;

  const MonthlyReportState({
    this.totalWorkDuration = Duration.zero,
    this.totalBreakDuration = Duration.zero,
    this.totalNetWorkDuration = Duration.zero,
    this.averageWorkDuration = Duration.zero,
    this.overtime = Duration.zero,
    this.totalOvertime = Duration.zero,
    this.workDays = 0,
    this.weeklyWork = const {},
    this.dailyWork = const {},
  });

  /// Durchschnittliche Arbeitszeit pro Tag
  Duration get avgWorkDurationPerDay {
    if (workDays == 0) return Duration.zero;
    return Duration(minutes: totalWorkDuration.inMinutes ~/ workDays);
  }

  /// Durchschnittliche Arbeitszeit pro Woche
  Duration get avgWorkDurationPerWeek {
    if (workDays == 0) return Duration.zero;
    // Berechne die Anzahl der Wochen (Arbeitstage / 5)
    double weeks = workDays / 5;
    return Duration(minutes: (totalWorkDuration.inMinutes / weeks).round());
  }

  static const MonthlyReportState initial = MonthlyReportState(
    totalOvertime: Duration.zero,
  );
}
