import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_work_time/core/utils/api_errors.dart';
import 'package:flutter_work_time/data/datasources/remote/api_client.dart';

import '../../../support/fake_signed_in_auth.dart';
import '../../../support/yearly_comparison_fixture.dart';

class _RecordingHttpClient extends Fake implements http.Client {
  Uri? lastUri;
  int calls = 0;
  http.Response nextResponse = http.Response('{}', 200);

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    lastUri = url;
    calls++;
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
    http_.nextResponse =
        http.Response(jsonEncode(yearlyComparisonJson(2026)), 200);
  });

  group('getYearlyComparison (#530)', () {
    test('URL ohne Stichtag und ohne Profil: keine Query', () async {
      await api.getYearlyComparison(2025);
      final uri = http_.lastUri!;
      expect(uri.path, endsWith('/api/reports/yearly-comparison/2025'));
      expect(uri.queryParameters, isEmpty);
    });

    test('Stichtag als MM-dd mit führenden Nullen', () async {
      await api.getYearlyComparison(2026, until: DateTime(2026, 3, 5));
      expect(http_.lastUri!.queryParameters, {'until': '03-05'});
      await api.getYearlyComparison(2026, until: DateTime(2026, 11, 15));
      expect(http_.lastUri!.queryParameters, {'until': '11-15'});
    });

    test('Stichtag und zusätzliches Profil', () async {
      await api.getYearlyComparison(2026,
          until: DateTime(2026, 2, 28), profileId: 'p1');
      expect(http_.lastUri!.queryParameters,
          {'until': '02-28', 'profileId': 'p1'});
    });

    test('Standard-Profil sendet keinen profileId-Parameter', () async {
      await api.getYearlyComparison(2026, profileId: 'default');
      expect(http_.lastUri!.queryParameters, isEmpty);
    });

    test('Abbildung: Jahreswerte, Monate, Differenzen (Dauern in ms)',
        () async {
      http_.nextResponse = http.Response(
          jsonEncode(yearlyComparisonJson(2026, until: '11-15')), 200);
      final r =
          await api.getYearlyComparison(2026, until: DateTime(2026, 11, 15));
      expect(r.until, '11-15');
      expect(r.current.year, 2026);
      expect(r.current.hasData, isTrue);
      expect(r.current.totalWorked, const Duration(hours: 1498, minutes: 30));
      expect(r.current.totalBreaks, const Duration(hours: 95));
      expect(r.current.overtime, const Duration(hours: 18, minutes: 45));
      expect(r.current.workDays, 189);
      expect(r.current.vacationDays, 24);
      expect(r.current.sickDays, 3);
      expect(r.current.holidayDays, 9);
      expect(r.current.months, hasLength(12));
      expect(r.current.months.map((m) => m.month),
          [for (var m = 1; m <= 12; m++) m]);
      expect(r.current.months[11].worked, Duration.zero);
      expect(r.previous.year, 2025);
      expect(r.previous.overtime, -const Duration(hours: 4, minutes: 15));
      final d = r.delta!;
      expect(d.worked, const Duration(hours: 77, minutes: 30));
      expect(d.workedPercent, 5.5);
      expect(d.overtime, const Duration(hours: 23));
      expect(d.workDays, 6);
      expect(d.vacationDays, -3);
      expect(d.sickDays, -4);
      expect(d.holidayDays, 0);
    });

    test('Vorjahr ohne Daten: delta null, Prozent null bleibt null', () async {
      http_.nextResponse = http.Response(
          jsonEncode(yearlyComparisonJson(2026, previousEmpty: true)), 200);
      var r = await api.getYearlyComparison(2026);
      expect(r.previous.hasData, isFalse);
      expect(r.delta, isNull);

      http_.nextResponse = http.Response(
          jsonEncode(yearlyComparisonJson(2026, noPercent: true)), 200);
      r = await api.getYearlyComparison(2026);
      expect(r.delta!.workedPercent, isNull);
    });

    test('fehlende Felder = 0/false, unbekannte ignoriert, Monate aufgefüllt',
        () async {
      http_.nextResponse = http.Response(
          jsonEncode({
            'zukunft': 1,
            'current': {
              'months': [
                {'month': 3, 'workedMs': 3600000, 'neu': true},
                {'month': 13, 'workedMs': 1},
                'kaputt',
              ],
            },
            'delta': {'workedMs': 60000},
          }),
          200);
      final r = await api.getYearlyComparison(2026);
      expect(r.until, isNull);
      expect(r.current.year, 2026);
      expect(r.current.hasData, isFalse);
      expect(r.current.totalWorked, Duration.zero);
      expect(r.current.workDays, 0);
      expect(r.current.months, hasLength(12));
      expect(r.current.months[2].worked, const Duration(hours: 1));
      expect(r.current.months[2].workDays, 0);
      expect(r.current.months[0].worked, Duration.zero);
      expect(r.previous.year, 2025);
      expect(r.previous.months, hasLength(12));
      expect(r.delta!.worked, const Duration(minutes: 1));
      expect(r.delta!.workedPercent, isNull);
      expect(r.delta!.sickDays, 0);
    });

    test('negativer Prozentwert mit Nachkommastelle', () async {
      http_.nextResponse = http.Response(
          jsonEncode({
            ...yearlyComparisonJson(2026),
            'delta': {'workedMs': -1, 'workedPercent': -12.4},
          }),
          200);
      final r = await api.getYearlyComparison(2026);
      expect(r.delta!.workedPercent, -12.4);
    });

    test('Fehlerstatus ergibt ApiException mit Status', () async {
      http_.nextResponse = http.Response('bad', 400);
      expect(
          () => api.getYearlyComparison(2026),
          throwsA(isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)));
    });

    test('nicht angemeldet: NotSignedInException, kein Request', () async {
      auth.signedIn = false;
      await expectLater(
          api.getYearlyComparison(2026), throwsA(isA<NotSignedInException>()));
      expect(http_.calls, 0);
    });
  });
}
