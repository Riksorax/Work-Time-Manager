import 'package:flutter/foundation.dart';

@immutable
class WeeklyReportState {
  final Duration totalWorkDuration;
  final Duration totalBreakDuration;
  final Duration totalNetWorkDuration;
  final Duration averageWorkDuration;
  final Duration overtime;
  final int workDays;
  final Map<DateTime, Duration> dailyWork;

  const WeeklyReportState({
    this.totalWorkDuration = Duration.zero,
    this.totalBreakDuration = Duration.zero,
    this.totalNetWorkDuration = Duration.zero,
    this.averageWorkDuration = Duration.zero,
    this.overtime = Duration.zero,
    this.workDays = 0,
    this.dailyWork = const {},
  });

  Duration get avgWorkDurationPerDay => workDays > 0 
      ? Duration(seconds: totalWorkDuration.inSeconds ~/ workDays) 
      : Duration.zero;

  static const WeeklyReportState initial = WeeklyReportState();
}
