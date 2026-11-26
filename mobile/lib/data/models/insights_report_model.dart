import '../../domain/entities/insights_report.dart';
import '../../domain/utils/entry_day.dart';
import '../../domain/utils/insights_utils.dart';

/// Schwelle der Serien-Warnung, falls die Antwort sie nicht nennt (#134).
const int defaultInsightsWarningThresholdDays = 5;

/// Lesegrenze der Insights-Antwort (#537, `InsightsReportDto`): JSON → Entity.
///
/// Dauern kommen in Millisekunden. `from`/`to` sind Kalendertage
/// `yyyy-MM-dd` und werden zur lokalen Mitternacht zerlegt, nie über eine Zone
/// gelesen (#418); fehlen sie oder sind sie ungültig, gilt [fallbackFrom] bzw.
/// [fallbackTo]. Fehlende Listen sind leer, eine fehlende Serie 0/0 ohne
/// Warnung. Wochentage außerhalb 1–7 und Stunden außerhalb 0–23 werden
/// verworfen; die Reihenfolge der Antwort bleibt (das Backend sortiert).
InsightsReport insightsReportFromJson(
  Map<String, dynamic> json, {
  required DateTime fallbackFrom,
  required DateTime fallbackTo,
}) {
  final streak = json['overtimeStreak'];
  final s = streak is Map<String, dynamic> ? streak : const <String, dynamic>{};
  return InsightsReport(
    from: _day(json['from']) ?? fallbackFrom,
    to: _day(json['to']) ?? fallbackTo,
    dailyTarget: _ms(json['dailyTargetMs']),
    weekdayAverages: [
      for (final w in (json['weekdayAverages'] as List<dynamic>? ?? const []))
        if (w is Map<String, dynamic> &&
            _int(w['weekday']) >= 1 &&
            _int(w['weekday']) <= 7)
          WeekdayAverage(
            weekday: _int(w['weekday']),
            averageWorkDuration: _ms(w['averageWorkedMs']),
            deviationFromOverallAverage: _ms(w['deviationMs']),
            sampleCount: _int(w['sampleCount']),
          ),
    ],
    burnoutStatus: BurnoutStatus(
      currentStreak: _int(s['currentStreak']),
      longestStreak: _int(s['longestStreak']),
      isWarning: s['isWarning'] == true,
    ),
    warningThresholdDays: s['warningThresholdDays'] is num
        ? _int(s['warningThresholdDays'])
        : defaultInsightsWarningThresholdDays,
    heatmap: [
      for (final b in (json['startTimeHeatmap'] as List<dynamic>? ?? const []))
        if (b is Map<String, dynamic> &&
            b['startHour'] is num &&
            _int(b['startHour']) >= 0 &&
            _int(b['startHour']) <= 23)
          StartTimeBucket(
            startHour: _int(b['startHour']),
            averageOvertime: _ms(b['averageOvertimeMs']),
            sampleCount: _int(b['sampleCount']),
          ),
    ],
  );
}

Duration _ms(dynamic v) => Duration(milliseconds: v is num ? v.toInt() : 0);

int _int(dynamic v) => v is num ? v.toInt() : 0;

DateTime? _day(dynamic v) {
  if (v is! String || v.length < 10) return null;
  return localDateFromEntryId(v.substring(0, 10));
}
