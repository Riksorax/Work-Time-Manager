import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/data/datasources/remote/api_client.dart';
import 'package:flutter_work_time/data/models/trend_report_model.dart';
import 'package:flutter_work_time/domain/entities/trend_report.dart';
import 'package:flutter_work_time/domain/utils/iso_week.dart';

/// Antworten von `GET /api/reports/trend/{y}/{m}/{d}` (#531) im Format des
/// Backend-DTOs (`TrendReportDto`). Dieselben Werte wie `web/e2e/trend-data.ts`,
/// damit Web und Mobile vergleichbar sind. Reine Testdaten; die echte Rechnung
/// testet das Backend.

const int _hour = 3600000;

const weekHours = [
  38.5,
  41.0,
  40.0,
  36.5,
  42.5,
  39.0,
  40.0,
  44.0,
  37.5,
  40.5,
  41.5,
  22.0
];
const monthHours = [
  168.0,
  152.0,
  171.0,
  160.0,
  158.0,
  175.0,
  120.0,
  166.0,
  172.0,
  169.0,
  174.0,
  86.0
];

String _pad(int n) => n.toString().padLeft(2, '0');

/// UTC-Mitternacht des Kalendertags in der Schreibweise des Backends.
String utcMidnightIso(DateTime d) =>
    '${d.year}-${_pad(d.month)}-${_pad(d.day)}T00:00:00+00:00';

String isoWeekKey(DateTime d) => '${isoWeekYear(d)}-W${_pad(isoWeekNumber(d))}';

/// Antwort für den Bezugstag [ref] und [granularity] (`week`/`month`):
/// 12 Zeiträume, älteste zuerst. [gaps] = Indizes ohne Einträge (0 = älteste),
/// [workedHours] = Arbeitszeit je Zeitraum, [weeklyTrend] `false` = `null`.
Map<String, dynamic> trendJson(
  DateTime ref,
  String granularity, {
  Set<int> gaps = const {},
  List<double>? workedHours,
  bool weeklyTrend = true,
}) {
  final worked =
      workedHours ?? (granularity == 'week' ? weekHours : monthHours);
  var cumulative = 0;
  final buckets = <Map<String, dynamic>>[];
  for (var i = 0; i < 12; i++) {
    final back = 11 - i;
    final DateTime start;
    final DateTime end;
    final String key;
    final int targetH;
    if (granularity == 'week') {
      start =
          DateTime(ref.year, ref.month, ref.day - (ref.weekday - 1) - 7 * back);
      end = DateTime(start.year, start.month, start.day + 6);
      key = isoWeekKey(start);
      targetH = back == 0 ? 24 : 40;
    } else {
      start = DateTime(ref.year, ref.month - back, 1);
      end = DateTime(ref.year, ref.month - back + 1, 0);
      key = '${start.year}-${_pad(start.month)}';
      targetH = back == 0 ? 88 : 168;
    }
    final hasData = !gaps.contains(i);
    final workedMs = hasData ? (worked[i] * _hour).round() : 0;
    final targetMs = hasData ? targetH * _hour : 0;
    final overtimeMs = workedMs - targetMs;
    cumulative += overtimeMs;
    buckets.add({
      'key': key,
      'start': utcMidnightIso(start),
      'end': utcMidnightIso(end),
      'workedMs': workedMs,
      'targetMs': targetMs,
      'overtimeMs': overtimeMs,
      'cumulativeOvertimeMs': cumulative,
      'hasData': hasData,
    });
  }
  final lastMonday =
      DateTime(ref.year, ref.month, ref.day - (ref.weekday - 1) - 7);
  return {
    'granularity': granularity,
    'buckets': buckets,
    'weeklyTrend': weeklyTrend
        ? {
            'lastWeekKey': isoWeekKey(lastMonday),
            'lastWeekWorkedMs': (41.5 * _hour).round(),
            'averageWorkedMs': 39 * _hour,
            'deltaMs': (2.5 * _hour).round(),
            'comparedWeeks': 4,
          }
        : null,
  };
}

/// Kein Zeitraum mit Einträgen.
Map<String, dynamic> emptyTrendJson(DateTime ref, String granularity) =>
    trendJson(ref, granularity,
        gaps: {for (var i = 0; i < 12; i++) i}, weeklyTrend: false);

typedef TrendCall = ({
  DateTime date,
  TrendGranularity granularity,
  String? profileId
});

/// `ApiClient` nur für den Trend: zeichnet die Aufrufe auf und antwortet über
/// [handler] (JSON wie das Backend, gelesen über die echte Lesegrenze
/// `trendReportFromJson`). Ein `Completer` im Handler hält die Antwort an.
class FakeTrendApi extends Fake implements ApiClient {
  FakeTrendApi(this.handler);

  Future<Map<String, dynamic>> Function(TrendCall call) handler;

  final calls = <TrendCall>[];

  @override
  Future<TrendReport> getTrendReport(
      DateTime date, TrendGranularity granularity,
      {String? profileId}) async {
    final call = (date: date, granularity: granularity, profileId: profileId);
    calls.add(call);
    final json = await handler(call);
    return trendReportFromJson(json, requested: granularity);
  }
}
