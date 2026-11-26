import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_work_time/data/datasources/remote/api_client.dart';

import '../../../support/fake_signed_in_auth.dart';
import '../../../support/timezone_guard.dart';

class _FixedHttpClient extends Fake implements http.Client {
  _FixedHttpClient(this.body);
  final Object body;
  Uri? lastUri;

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    lastUri = url;
    return http.Response(jsonEncode(body), 200);
  }
}

/// Home-Office und Insights (#537): Kalendertage (`yyyy-MM-dd`) werden zur
/// lokalen Mitternacht zerlegt, nie über eine Zone gelesen; der Bezugstag geht
/// mit seinen lokalen Kalenderfeldern in den Pfad. Die Assertions gelten in
/// jeder Zone; CI fährt die Datei zusätzlich unter LA und Auckland.
void main() {
  registerTimezoneCanary();

  test('homeOfficeDates: Monatserster und Jahresende bleiben am Tag', () async {
    final api = ApiClient(
        FakeSignedInAuth(),
        _FixedHttpClient({
          'year': 2026,
          'homeOfficeDates': ['2026-03-01', '2026-12-31', '2026-10-25'],
        }));
    final r = await api.getHomeOfficeReport(2026);
    expect(r.homeOfficeDates, [
      DateTime(2026, 3, 1),
      DateTime(2026, 10, 25),
      DateTime(2026, 12, 31),
    ]);
    expect(r.datesInMonth(3), [DateTime(2026, 3, 1)]);
    expect(r.datesInMonth(2), isEmpty);
    for (final d in r.homeOfficeDates) {
      expect((d.hour, d.minute), (0, 0));
    }
  });

  test('Insights: from/to lokale Mitternacht, Bezugstag aus lokalen Feldern',
      () async {
    final http_ = _FixedHttpClient({'from': '2026-09-01', 'to': '2026-11-30'});
    final api = ApiClient(FakeSignedInAuth(), http_);
    // Lokale Mitternacht des 1.11.: in UTC östlich von Greenwich (Auckland)
    // noch der 31.10. – der Pfad nimmt die lokalen Felder.
    final r = await api.getInsightsReport(DateTime(2026, 11, 1), 'UTC');
    expect(http_.lastUri!.path, endsWith('/reports/insights/2026/11/1'));
    expect(r.from, DateTime(2026, 9, 1));
    expect(r.to, DateTime(2026, 11, 30));
  });
}
