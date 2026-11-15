import '../../domain/entities/trend_report.dart';
import '../../domain/utils/entry_day.dart';

/// Lesegrenze der Trend-Antwort (#531, `TrendReportDto`): JSON → Entity.
///
/// `start`/`end` sind UTC-Mitternacht des Kalendertags (`…T00:00:00+00:00`)
/// und werden wie alle Berichtstage über die UTC-Felder gelesen
/// ([calendarDateFromUtcMidnight]), nie über `.toLocal()`: westlich von UTC
/// wäre das der Vortag (#418). Dauern kommen in Millisekunden. Fehlende Felder
/// gelten als 0 bzw. `false`; unbekannte Felder werden ignoriert.
///
/// `forecast` (#532): fehlt das Feld (älteres Backend), ist es kein Objekt
/// oder ist `targetDate` kein gültiger Kalendertag, gilt `null`. `targetDate`
/// (`yyyy-MM-dd`, ein Zeitanteil wird ignoriert) wird in seine Teile zerlegt
/// und als lokale Mitternacht gebaut, nie über eine Zeitzone gelesen.
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
    forecast: _forecastFromJson(json['forecast']),
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

OvertimeForecast? _forecastFromJson(dynamic j) {
  if (j is! Map<String, dynamic>) return null;
  final raw = j['targetDate'];
  final targetDate = raw is String && raw.length >= 10
      ? localDateFromEntryId(raw.substring(0, 10))
      : null;
  if (targetDate == null) return null;
  return OvertimeForecast(
    targetDate: targetDate,
    currentBalance: _ms(j['currentBalanceMs']),
    averageWeeklyOvertime: _ms(j['averageWeeklyOvertimeMs']),
    weeksUsed: (j['weeksUsed'] as num?)?.toInt() ?? 0,
    remainingWeeks: (j['remainingWeeks'] as num?)?.toDouble() ?? 0,
    projectedBalance: _ms(j['projectedBalanceMs']),
  );
}
