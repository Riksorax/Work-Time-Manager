import 'package:flutter/foundation.dart';
import 'package:flutter_work_time/core/utils/time_precision.dart';

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
      ? roundDurationToMinute(
          Duration(microseconds: totalWorkDuration.inMicroseconds ~/ workDays))
      : Duration.zero;

  static const WeeklyReportState initial = WeeklyReportState();
}
