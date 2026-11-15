import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_work_time/core/utils/api_errors.dart';
import 'package:flutter_work_time/data/datasources/remote/api_client.dart';
import 'package:flutter_work_time/domain/entities/trend_report.dart';

import '../../../support/fake_signed_in_auth.dart';
import '../../../support/trend_fixture.dart';

class _RecordingHttpClient extends Fake implements http.Client {
  Uri? lastUri;
  http.Response nextResponse = http.Response('{}', 200);

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    lastUri = url;
    return nextResponse;
  }
}

void main() {
  late _RecordingHttpClient http_;
  late FakeSignedInAuth auth;
  late ApiClient api;

  setUp(() {
    http_ = _RecordingHttpClient();
    auth = FakeSignedInAuth();
    api = ApiClient(auth, http_);
  });

  group('getTrendReport (#531)', () {
    test('URL: Bezugstag im Pfad, granularity als Query, ohne Profil',
        () async {
      http_.nextResponse = http.Response(
          jsonEncode(trendJson(DateTime(2026, 11, 12), 'week')), 200);
      await api.getTrendReport(DateTime(2026, 11, 12), TrendGranularity.week);
      final uri = http_.lastUri!;
      expect(uri.path, endsWith('/api/reports/trend/2026/11/12'));
      expect(uri.queryParameters, {'granularity': 'week'});
    });

    test('URL: Monat und zusätzliches Profil', () async {
      http_.nextResponse = http.Response(
          jsonEncode(trendJson(DateTime(2026, 1, 5), 'month')), 200);
      await api.getTrendReport(DateTime(2026, 1, 5), TrendGranularity.month,
          profileId: 'p1');
      final uri = http_.lastUri!;
      expect(uri.path, endsWith('/api/reports/trend/2026/1/5'));
      expect(uri.queryParameters, {'granularity': 'month', 'profileId': 'p1'});
    });

    test('Standard-Profil sendet keinen profileId-Parameter', () async {
      http_.nextResponse = http.Response(
          jsonEncode(trendJson(DateTime(2026, 11, 12), 'week')), 200);
      await api.getTrendReport(DateTime(2026, 11, 12), TrendGranularity.week,
          profileId: 'default');
      expect(http_.lastUri!.queryParameters, {'granularity': 'week'});
    });

    test('Abbildung: Werte, Lücken, Wochen-Trend', () async {
      http_.nextResponse = http.Response(
          jsonEncode(trendJson(DateTime(2026, 11, 12), 'week', gaps: {2})),
          200);
      final r = await api.getTrendReport(
          DateTime(2026, 11, 12), TrendGranularity.week);
      expect(r.granularity, TrendGranularity.week);
      expect(r.buckets, hasLength(12));
      final last = r.buckets.last;
      expect(last.key, '2026-W46');
      expect(last.weekNumber, 46);
      expect(last.start, DateTime(2026, 11, 9));
      expect(last.end, DateTime(2026, 11, 15));
      expect(last.worked, const Duration(hours: 22));
      expect(last.target, const Duration(hours: 24));
      expect(last.overtime, const Duration(hours: -2));
      expect(last.hasData, isTrue);
      expect(r.buckets[2].hasData, isFalse);
      expect(r.buckets[2].worked, Duration.zero);
      expect(r.buckets.first.cumulativeOvertime,
          const Duration(hours: -1, minutes: -30));
      final wt = r.weeklyTrend!;
      expect(wt.lastWeekKey, '2026-W45');
      expect(wt.lastWeekNumber, 45);
      expect(wt.lastWeekWorked, const Duration(hours: 41, minutes: 30));
      expect(wt.averageWorked, const Duration(hours: 39));
      expect(wt.delta, const Duration(hours: 2, minutes: 30));
      expect(wt.comparedWeeks, 4);
      expect(r.isEmpty, isFalse);
    });

    test('weeklyTrend null und leere Antwort', () async {
      http_.nextResponse = http.Response(
          jsonEncode(emptyTrendJson(DateTime(2026, 11, 12), 'month')), 200);
      final r = await api.getTrendReport(
          DateTime(2026, 11, 12), TrendGranularity.month);
      expect(r.weeklyTrend, isNull);
      expect(r.isEmpty, isTrue);
      expect(r.buckets.first.key, '2025-12');
      expect(r.buckets.first.start, DateTime(2025, 12, 1));
      expect(r.buckets.first.end, DateTime(2025, 12, 31));
    });

    test('fehlende Felder gelten als 0/false, unbekannte werden ignoriert',
        () async {
      http_.nextResponse = http.Response(
          jsonEncode({
            'buckets': [
              {
                'key': '2026-11',
                'start': '2026-11-01T00:00:00Z',
                'end': '2026-11-30T00:00:00+00:00',
                'extra': 1,
              }
            ],
            'weeklyTrend': null,
          }),
          200);
      final r = await api.getTrendReport(
          DateTime(2026, 11, 12), TrendGranularity.month);
      expect(r.granularity, TrendGranularity.month);
      final b = r.buckets.single;
      expect(b.worked, Duration.zero);
      expect(b.hasData, isFalse);
      expect(b.start, DateTime(2026, 11, 1));
      expect(b.weekNumber, isNull);
    });

    group('Prognose zum Jahresende (#532)', () {
      Future<TrendReport> read(Object? forecast, {bool omit = false}) async {
        final json = trendJson(DateTime(2026, 11, 12), 'week');
        if (omit) {
          json.remove('forecast');
        } else {
          json['forecast'] = forecast;
        }
        http_.nextResponse = http.Response(jsonEncode(json), 200);
        return api.getTrendReport(
            DateTime(2026, 11, 12), TrendGranularity.week);
      }

      test('gesetzt: alle Werte, Zieltag als Kalendertag', () async {
        final f = (await read(forecastJson(2026, remainingWeeks: 7.142857)))
            .forecast!;
        expect(f.targetDate, DateTime(2026, 12, 31));
        expect(f.currentBalance, const Duration(hours: 18, minutes: 45));
        expect(f.averageWeeklyOvertime, const Duration(hours: 1, minutes: 15));
        expect(f.weeksUsed, 6);
        expect(f.remainingWeeks, closeTo(7.142857, 1e-9));
        expect(f.projectedBalance, const Duration(hours: 27, minutes: 30));
      });

      test('negativ und Restwochen als ganze Zahl', () async {
        final f = (await read(forecastJson(2026, negative: true))).forecast!;
        expect(f.currentBalance, const Duration(hours: -2, minutes: -30));
        expect(f.averageWeeklyOvertime, const Duration(minutes: -45));
        expect(f.projectedBalance, const Duration(hours: -7, minutes: -45));
        expect(f.remainingWeeks, 7.0);
      });

      test('null: keine Prognose', () async {
        expect((await read(null)).forecast, isNull);
      });

      test('Feld fehlt (älteres Backend): keine Prognose', () async {
        final r = await read(null, omit: true);
        expect(r.forecast, isNull);
        expect(r.weeklyTrend, isNotNull);
      });

      test('Zieltag mit Zeitanteil zählt als Kalendertag', () async {
        final f = (await read(forecastJson(2026)
              ..['targetDate'] = '2026-12-31T00:00:00+00:00'))
            .forecast!;
        expect(f.targetDate, DateTime(2026, 12, 31));
      });

      for (final bad in [
        '31.12.2026',
        '2026-13-01',
        '2026-02-30',
        '',
        42,
        null
      ]) {
        test('unlesbarer Zieltag ($bad): keine Prognose, Rest bleibt',
            () async {
          final r = await read(forecastJson(2026)..['targetDate'] = bad);
          expect(r.forecast, isNull);
          expect(r.buckets, hasLength(12));
        });
      }

      test('kein Objekt: keine Prognose', () async {
        expect((await read('2026-12-31')).forecast, isNull);
      });

      test('fehlende Zahlen gelten als 0', () async {
        final f = (await read({'targetDate': '2027-12-31'})).forecast!;
        expect(f.targetDate, DateTime(2027, 12, 31));
        expect(f.currentBalance, Duration.zero);
        expect(f.weeksUsed, 0);
        expect(f.remainingWeeks, 0);
        expect(f.projectedBalance, Duration.zero);
      });
    });

    test('HTTP-Fehler: ApiException mit Status', () async {
      http_.nextResponse = http.Response('nope', 500);
      await expectLater(
        api.getTrendReport(DateTime(2026, 11, 12), TrendGranularity.week),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 500)
            .having((e) => e.operation, 'operation', 'getTrendReport')),
      );
    });

    test('ohne angemeldeten Nutzer: NotSignedInException, kein Request',
        () async {
      auth.signedIn = false;
      await expectLater(
        api.getTrendReport(DateTime(2026, 11, 12), TrendGranularity.week),
        throwsA(isA<NotSignedInException>()),
      );
      expect(http_.lastUri, isNull);
    });
  });
}
