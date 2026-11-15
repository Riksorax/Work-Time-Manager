import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_work_time/core/utils/api_errors.dart';
import 'package:flutter_work_time/data/datasources/remote/api_client.dart';

import '../../../support/fake_signed_in_auth.dart';
import '../../../support/yearly_leave_report_fixture.dart';

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
    http_.nextResponse =
        http.Response(jsonEncode(yearlyLeaveReportJson(2026)), 200);
  });

  group('getYearlyLeaveReport (#284)', () {
    test('Pfad ohne Profil: keine Query', () async {
      await api.getYearlyLeaveReport(2026);
      expect(http_.lastUri!.path, '/api/reports/yearly/2026');
      expect(http_.lastUri!.queryParameters, isEmpty);
    });

    test('zusätzliches Profil hängt ?profileId= an, Standard nicht', () async {
      await api.getYearlyLeaveReport(2025, profileId: 'p1');
      expect(http_.lastUri!.path, '/api/reports/yearly/2025');
      expect(http_.lastUri!.queryParameters, {'profileId': 'p1'});
      await api.getYearlyLeaveReport(2025, profileId: 'default');
      expect(http_.lastUri!.queryParameters, isEmpty);
    });

    test('liest die Antwort über die Lesegrenze', () async {
      final r = await api.getYearlyLeaveReport(2026);
      expect(r.vacationDaysTaken, 14);
      expect(r.months, hasLength(12));
      expect(r.vacationPeriods, hasLength(2));
      expect(r.sickPeriods, hasLength(2));
    });

    test('Fehlerstatus als ApiException', () async {
      http_.nextResponse = http.Response('', 503);
      await expectLater(
        api.getYearlyLeaveReport(2026),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 503)
            .having((e) => e.operation, 'operation', 'getYearlyLeaveReport')),
      );
    });

    test('ohne Anmeldung: NotSignedInException, kein Request', () async {
      auth.signedIn = false;
      await expectLater(
          api.getYearlyLeaveReport(2026), throwsA(isA<NotSignedInException>()));
      expect(http_.lastUri, isNull);
    });
  });
}
