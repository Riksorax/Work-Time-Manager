import '../../domain/entities/trend_report.dart';
import '../../domain/utils/entry_day.dart';

/// Lesegrenze der Trend-Antwort (#531, `TrendReportDto`): JSON → Entity.
///
/// `start`/`end` sind UTC-Mitternacht des Kalendertags (`…T00:00:00+00:00`)
/// und werden wie alle Berichtstage über die UTC-Felder gelesen
/// ([calendarDateFromUtcMidnight]), nie über `.toLocal()`: westlich von UTC
/// wäre das der Vortag (#418). Dauern kommen in Millisekunden. Fehlende Felder
/// gelten als 0 bzw. `false`; unbekannte Felder werden ignoriert.
TrendReport trendReportFromJson(
  Map<String, dynamic> json, {
  required TrendGranularity requested,
}) {
  final g = json['granularity'];
  final granularity =
      TrendGranularity.values.where((v) => v.apiValue == g).firstOrNull ??
          requested;
  final buckets = (json['buckets'] as List<dynamic>? ?? [])
      .map((b) => _bucketFromJson(b as Map<String, dynamic>))
      .toList();
  final wt = json['weeklyTrend'];
  return TrendReport(
    granularity: granularity,
    buckets: buckets,
    weeklyTrend: wt is Map<String, dynamic> ? _weeklyTrendFromJson(wt) : null,
  );
}

Duration _ms(dynamic v) => Duration(milliseconds: (v as num?)?.toInt() ?? 0);

DateTime _day(dynamic v) =>
    calendarDateFromUtcMidnight(DateTime.parse(v as String));

TrendBucket _bucketFromJson(Map<String, dynamic> j) => TrendBucket(
      key: (j['key'] as String?) ?? '',
      start: _day(j['start']),
      end: _day(j['end']),
      worked: _ms(j['workedMs']),
      target: _ms(j['targetMs']),
      overtime: _ms(j['overtimeMs']),
      cumulativeOvertime: _ms(j['cumulativeOvertimeMs']),
      hasData: (j['hasData'] as bool?) ?? false,
    );

WeeklyTrend _weeklyTrendFromJson(Map<String, dynamic> j) => WeeklyTrend(
      lastWeekKey: (j['lastWeekKey'] as String?) ?? '',
      lastWeekWorked: _ms(j['lastWeekWorkedMs']),
      averageWorked: _ms(j['averageWorkedMs']),
      delta: _ms(j['deltaMs']),
      comparedWeeks: (j['comparedWeeks'] as num?)?.toInt() ?? 0,
    );
