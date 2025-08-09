import 'package:flutter/foundation.dart';

@immutable
class MonthlyReportState {
  final Duration totalWorkDuration;
  final Duration totalBreakDuration;
  final Duration totalNetWorkDuration;
  final Duration averageWorkDuration;
  final Duration overtime;
  final int workDays;

  const MonthlyReportState({
    this.totalWorkDuration = Duration.zero,
    this.totalBreakDuration = Duration.zero,
    this.totalNetWorkDuration = Duration.zero,
    this.averageWorkDuration = Duration.zero,
    this.overtime = Duration.zero,
    this.workDays = 0,
  });

  static const MonthlyReportState initial = MonthlyReportState();
}
