import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_work_time/core/utils/api_errors.dart';
import 'package:flutter_work_time/data/datasources/remote/api_client.dart';
import 'package:flutter_work_time/domain/entities/home_office_report.dart';

import '../../../support/analytics_fixture.dart';
import '../../../support/fake_signed_in_auth.dart';

class _RecordingHttpClient extends Fake implements http.Client {
  Uri? lastUri;
  Map<String, String>? lastHeaders;
  int calls = 0;
  http.Response nextResponse = http.Response('{}', 200);

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    lastUri = url;
    lastHeaders = headers;
    calls++;
    return nextResponse;
  }
}

/// Home-Office und Insights (#537): URL, Profil, Zone, Lesegrenze, Fehler.
void main() {
  late _RecordingHttpClient http_;
  late FakeSignedInAuth auth;
  late ApiClient api;

  setUp(() {
    http_ = _RecordingHttpClient();
    auth = FakeSignedInAuth();
    api = ApiClient(auth, http_);
  });

  group('getHomeOfficeReport', () {
    setUp(() => http_.nextResponse =
        http.Response(jsonEncode(homeOfficeJson(2026)), 200));

    test('URL ohne Profil, mit Token', () async {
      await api.getHomeOfficeReport(2026);
      expect(http_.lastUri!.path, endsWith('/api/reports/home-office/2026'));
      expect(http_.lastUri!.queryParameters, isEmpty);
      expect(http_.lastHeaders!['Authorization'], 'Bearer test-token');
    });

    test('Zusatzprofil als profileId, Standard-Profil ohne', () async {
      await api.getHomeOfficeReport(2026, profileId: 'p1');
      expect(http_.lastUri!.queryParameters, {'profileId': 'p1'});
      await api.getHomeOfficeReport(2026, profileId: 'default');
      expect(http_.lastUri!.queryParameters, isEmpty);
    });

    test('Abbildung: Jahr, Monate, Tage', () async {
      final r = await api.getHomeOfficeReport(2026);
      expect(r.year, 2026);
      expect(
          r.total,
          const HomeOfficeCounts(
              homeOfficeDays: 6, officeDays: 12, totalDays: 18, ratio: 6 / 18));
      expect(r.months, hasLength(12));
      expect(r.month(6).homeOfficeDays, 5);
      expect(r.month(6).ratio, 5 / 15);
      expect(r.month(1), HomeOfficeCounts.empty);
      expect(r.homeOfficeDates.first, DateTime(2026, 3, 10));
      expect(r.datesInMonth(6), hasLength(5));
      expect(r.datesInMonth(3), [DateTime(2026, 3, 10)]);
    });

    test('fehlende Felder: 0, null, leere Listen, zwölf Monate', () async {
      http_.nextResponse = http.Response('{}', 200);
      final r = await api.getHomeOfficeReport(2025);
      expect(r.year, 2025);
      expect(r.total, HomeOfficeCounts.empty);
      expect(r.months, List.filled(12, HomeOfficeCounts.empty));
      expect(r.homeOfficeDates, isEmpty);
    });

    test('ungültige Monate und Tage werden verworfen, Tage sortiert', () async {
      http_.nextResponse = http.Response(
          jsonEncode({
            'year': 2026,
            'months': [
              {'month': 13, 'homeOfficeDays': 9},
              {'month': 2, 'homeOfficeDays': 1, 'totalDays': 1},
              'kaputt',
            ],
            'homeOfficeDates': [
              '2026-05-04',
              '2026-02-30',
              'x',
              7,
              '2026-01-02T00:00:00',
            ],
          }),
          200);
      final r = await api.getHomeOfficeReport(2026);
      expect(r.month(2).homeOfficeDays, 1);
      expect(r.months.where((m) => m != HomeOfficeCounts.empty), hasLength(1));
      expect(r.homeOfficeDates, [DateTime(2026, 1, 2), DateTime(2026, 5, 4)]);
    });

    test('Fehlerstatus ergibt ApiException mit Status', () async {
      http_.nextResponse = http.Response('kaputt', 503);
      expect(
          api.getHomeOfficeReport(2026),
          throwsA(isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 503)));
    });

    test('nicht angemeldet: NotSignedInException, kein Request', () async {
      auth.signedIn = false;
      await expectLater(
          api.getHomeOfficeReport(2026), throwsA(isA<NotSignedInException>()));
      expect(http_.calls, 0);
    });
  });

  group('getInsightsReport', () {
    setUp(() => http_.nextResponse =
        http.Response(jsonEncode(insightsJson(DateTime(2026, 11, 15))), 200));

    test('URL aus den Kalenderfeldern, tz als Query', () async {
      await api.getInsightsReport(DateTime(2026, 3, 5), 'Europe/Berlin');
      expect(http_.lastUri!.path, endsWith('/api/reports/insights/2026/3/5'));
      expect(http_.lastUri!.queryParameters, {'tz': 'Europe/Berlin'});
    });

    test('Zusatzprofil und Zone zusammen', () async {
      await api.getInsightsReport(DateTime(2026, 11, 15), 'America/Los_Angeles',
          profileId: 'p1');
      expect(http_.lastUri!.queryParameters,
          {'profileId': 'p1', 'tz': 'America/Los_Angeles'});
      expect(http_.lastUri.toString(), contains('tz=America%2FLos_Angeles'));
    });

    test('Abbildung: Dauern in ms, Serie, Heatmap, Fenster', () async {
      final r = await api.getInsightsReport(DateTime(2026, 11, 15), 'UTC');
      expect(r.from, DateTime(2026, 9, 1));
      expect(r.to, DateTime(2026, 11, 30));
      expect(r.dailyTarget, const Duration(hours: 8));
      expect(r.weekdayAverages.map((w) => w.weekday), [1, 2, 3, 4, 5]);
      expect(r.weekdayAverages.first.averageWorkDuration,
          const Duration(hours: 8, minutes: 12));
      expect(r.weekdayAverages.first.deviationFromOverallAverage,
          const Duration(minutes: -18));
      expect(r.weekdayAverages.first.sampleCount, 11);
      expect(r.burnoutStatus.currentStreak, 2);
      expect(r.burnoutStatus.longestStreak, 4);
      expect(r.burnoutStatus.isWarning, isFalse);
      expect(r.warningThresholdDays, 5);
      expect(r.heatmap.map((b) => b.startHour), [7, 8, 9]);
      expect(r.heatmap.last.averageOvertime, const Duration(minutes: -21));
      expect(r.heatmap.first.sampleCount, 18);
    });

    test('Millisekunden bleiben erhalten (keine Rundung)', () async {
      http_.nextResponse = http.Response(
          jsonEncode({
            'weekdayAverages': [
              {
                'weekday': 3,
                'averageWorkedMs': 29700999,
                'deviationMs': -1999,
                'sampleCount': 3
              },
            ],
          }),
          200);
      final r = await api.getInsightsReport(DateTime(2026, 11, 15), 'UTC');
      expect(r.weekdayAverages.single.averageWorkDuration,
          const Duration(milliseconds: 29700999));
      expect(r.weekdayAverages.single.deviationFromOverallAverage,
          const Duration(milliseconds: -1999));
    });

    test('fehlende Felder: leer, Serie 0/0, Fenster aus dem Bezugstag',
        () async {
      http_.nextResponse = http.Response('{}', 200);
      final r = await api.getInsightsReport(DateTime(2027, 1, 20), 'UTC');
      expect(r.weekdayAverages, isEmpty);
      expect(r.heatmap, isEmpty);
      expect(r.burnoutStatus.currentStreak, 0);
      expect(r.burnoutStatus.isWarning, isFalse);
      expect(r.warningThresholdDays, 5);
      expect(r.from, DateTime(2026, 11, 1));
      expect(r.to, DateTime(2027, 1, 31));
    });

    test('ungültige Wochentage und Stunden werden verworfen', () async {
      http_.nextResponse = http.Response(
          jsonEncode({
            'weekdayAverages': [
              {'weekday': 0},
              {'weekday': 8},
              {'weekday': 7, 'averageWorkedMs': 1000, 'sampleCount': 1},
            ],
            'startTimeHeatmap': [
              {'startHour': 24},
              {'startHour': -1},
              {'averageOvertimeMs': 5},
              {'startHour': 0, 'averageOvertimeMs': 60000, 'sampleCount': 2},
            ],
          }),
          200);
      final r = await api.getInsightsReport(DateTime(2026, 11, 15), 'UTC');
      expect(r.weekdayAverages.single.weekday, 7);
      expect(r.heatmap.single.startHour, 0);
    });

    test('Fehlerstatus (z. B. 400 bei unbekannter Zone) ergibt ApiException',
        () async {
      http_.nextResponse = http.Response('bad tz', 400);
      expect(
          api.getInsightsReport(DateTime(2026, 11, 15), 'Mars/Olympus'),
          throwsA(isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)));
    });

    test('nicht angemeldet: NotSignedInException, kein Request', () async {
      auth.signedIn = false;
      await expectLater(api.getInsightsReport(DateTime(2026, 11, 15), 'UTC'),
          throwsA(isA<NotSignedInException>()));
      expect(http_.calls, 0);
    });
  });
}
