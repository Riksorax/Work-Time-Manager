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

  /// Brutto je Tag (`days[].workedMs`), Abwesenheit mit dem Tagessoll.
  final Map<DateTime, Duration> dailyWork;

  /// Netto je Tag (`days[].netWorkedMs`, #551): brutto − abgeschlossene
  /// Pausen, nicht bei 0 gekappt. Die Tageszeilen der Berichte und des PDFs
  /// zeigen diese Werte; ihre Summe ist [totalNetWorkDuration].
  final Map<DateTime, Duration> dailyNetWork;

  const WeeklyReportState({
    this.totalWorkDuration = Duration.zero,
    this.totalBreakDuration = Duration.zero,
    this.totalNetWorkDuration = Duration.zero,
    this.averageWorkDuration = Duration.zero,
    this.overtime = Duration.zero,
    this.workDays = 0,
    this.dailyWork = const {},
    this.dailyNetWork = const {},
  });

  Duration get avgWorkDurationPerDay => workDays > 0
      ? roundDurationToMinute(
          Duration(microseconds: totalWorkDuration.inMicroseconds ~/ workDays))
      : Duration.zero;

  static const WeeklyReportState initial = WeeklyReportState();
}
