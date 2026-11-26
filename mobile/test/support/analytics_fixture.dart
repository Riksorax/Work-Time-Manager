import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/utils/timezone_utils.dart';
import 'package:flutter_work_time/data/datasources/remote/api_client.dart';
import 'package:flutter_work_time/data/models/home_office_report_model.dart';
import 'package:flutter_work_time/data/models/insights_report_model.dart';
import 'package:flutter_work_time/data/models/trend_report_model.dart';
import 'package:flutter_work_time/domain/entities/trend_report.dart';
import 'package:flutter_work_time/domain/entities/home_office_report.dart';
import 'package:flutter_work_time/domain/entities/insights_report.dart';
import 'package:flutter_work_time/domain/utils/insights_utils.dart';

import 'trend_fixture.dart';

/// Testdaten Home-Office und Insights (#537), JSON wie das Backend
/// (`HomeOfficeReportDto`, `InsightsReportDto`).

/// Jahresantwort: Juni 5 Home-Office/10 Büro, März 1/2, sonst leer.
Map<String, dynamic> homeOfficeJson(int year) {
  Map<String, dynamic> month(int m, int ho, int office) => {
        'month': m,
        'homeOfficeDays': ho,
        'officeDays': office,
        'totalDays': ho + office,
        'homeOfficeRatio': ho + office == 0 ? null : ho / (ho + office),
      };
  return {
    'year': year,
    'homeOfficeDays': 6,
    'officeDays': 12,
    'totalDays': 18,
    'homeOfficeRatio': 6 / 18,
    'months': [
      for (var m = 1; m <= 12; m++)
        m == 6
            ? month(6, 5, 10)
            : m == 3
                ? month(3, 1, 2)
                : month(m, 0, 0),
    ],
    'homeOfficeDates': [
      '$year-03-10',
      '$year-06-02',
      '$year-06-09',
      '$year-06-16',
      '$year-06-23',
      '$year-06-30',
    ],
  };
}

/// Insights-Antwort zum Bezugstag [ref] (Fenster drei Monate).
Map<String, dynamic> insightsJson(
  DateTime ref, {
  bool warning = false,
  bool empty = false,
}) {
  String day(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
  final w = insightsWindow(ref);
  const h = 3600000;
  const m = 60000;
  return {
    'from': day(w.from),
    'to': day(w.to),
    'timeZone': 'Europe/Berlin',
    'dailyTargetMs': 8 * h,
    'weekdayAverages': empty
        ? <Map<String, dynamic>>[]
        : [
            {
              'weekday': 1,
              'averageWorkedMs': 8 * h + 12 * m,
              'deviationMs': -18 * m,
              'sampleCount': 11
            },
            {
              'weekday': 2,
              'averageWorkedMs': 8 * h + 41 * m,
              'deviationMs': 11 * m,
              'sampleCount': 12
            },
            {
              'weekday': 3,
              'averageWorkedMs': 9 * h + 5 * m,
              'deviationMs': 35 * m,
              'sampleCount': 12
            },
            {
              'weekday': 4,
              'averageWorkedMs': 8 * h + 30 * m,
              'deviationMs': 0,
              'sampleCount': 12
            },
            {
              'weekday': 5,
              'averageWorkedMs': 7 * h + 52 * m,
              'deviationMs': -38 * m,
              'sampleCount': 10
            },
          ],
    'overtimeStreak': {
      'currentStreak': warning ? 7 : 2,
      'longestStreak': warning ? 9 : 4,
      'isWarning': warning,
      'warningThresholdDays': 5,
    },
    'startTimeHeatmap': empty
        ? <Map<String, dynamic>>[]
        : [
            {'startHour': 7, 'averageOvertimeMs': 34 * m, 'sampleCount': 18},
            {'startHour': 8, 'averageOvertimeMs': 9 * m, 'sampleCount': 27},
            {'startHour': 9, 'averageOvertimeMs': -21 * m, 'sampleCount': 9},
          ],
  };
}

typedef HomeOfficeCall = ({int year, String? profileId});
typedef InsightsCall = ({DateTime date, String timeZone, String? profileId});

/// `ApiClient` nur für Home-Office und Insights: zeichnet Aufrufe auf und
/// antwortet über die Handler (JSON über die echten Lesegrenzen). Ohne
/// Handler gelten [homeOfficeJson] bzw. [insightsJson]. Der Trend oben im
/// Insights-Tab (#531) antwortet leer.
class FakeAnalyticsApi extends Fake implements ApiClient {
  FakeAnalyticsApi({this.onHomeOffice, this.onInsights});

  Future<Map<String, dynamic>> Function(HomeOfficeCall call)? onHomeOffice;
  Future<Map<String, dynamic>> Function(InsightsCall call)? onInsights;

  final homeOfficeCalls = <HomeOfficeCall>[];
  final insightsCalls = <InsightsCall>[];

  final trendCalls = <TrendCall>[];

  @override
  Future<TrendReport> getTrendReport(
      DateTime date, TrendGranularity granularity,
      {String? profileId}) async {
    trendCalls
        .add((date: date, granularity: granularity, profileId: profileId));
    return trendReportFromJson(emptyTrendJson(date, granularity.apiValue),
        requested: granularity);
  }

  @override
  Future<HomeOfficeReport> getHomeOfficeReport(int year,
      {String? profileId}) async {
    final call = (year: year, profileId: profileId);
    homeOfficeCalls.add(call);
    final json =
        await (onHomeOffice?.call(call) ?? Future.value(homeOfficeJson(year)));
    return homeOfficeReportFromJson(json, requestedYear: year);
  }

  @override
  Future<InsightsReport> getInsightsReport(DateTime date, String timeZone,
      {String? profileId}) async {
    final call = (date: date, timeZone: timeZone, profileId: profileId);
    insightsCalls.add(call);
    final json =
        await (onInsights?.call(call) ?? Future.value(insightsJson(date)));
    final w = insightsWindow(date);
    return insightsReportFromJson(json, fallbackFrom: w.from, fallbackTo: w.to);
  }
}

/// Feste Gerätezone für Tests (kein Plattformkanal).
class FixedTimeZone extends DeviceTimeZone {
  const FixedTimeZone([this.name = 'Europe/Berlin']);
  final String name;

  @override
  Future<String> ianaName() async => name;
}

/// Festes aktives Profil (`null` = Standard-Profil), ohne SharedPreferences.
class TestProfile extends ActiveWorkProfileIdNotifier {
  TestProfile([this.id]);
  final String? id;

  @override
  String? build() => id;

  /// Profilwechsel ohne Prefs.
  void select(String? profileId) => state = profileId;
}
