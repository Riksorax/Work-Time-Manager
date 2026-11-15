import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';

import 'package:flutter_work_time/data/datasources/remote/api_client.dart';
import 'package:flutter_work_time/presentation/widgets/yearly_comparison_card.dart';

import '../../../support/fake_signed_in_auth.dart';
import '../../../support/timezone_guard.dart';
import '../../../support/yearly_comparison_fixture.dart';

class _FixedHttpClient extends Fake implements http.Client {
  Uri? lastUri;

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    lastUri = url;
    return http.Response(jsonEncode(yearlyComparisonJson(2026)), 200);
  }
}

/// Jahresvergleich (#530): der Stichtag `until=MM-dd` entsteht aus den
/// lokalen Kalenderfeldern des heutigen Tags (`todayProvider`, lokale
/// Mitternacht). Über UTC gebildet, wäre es in Auckland (UTC+13 im Januar)
/// der Vortag; in Los Angeles würde ein später Abend zum Folgetag. Die
/// Assertions gelten in jeder Zone; CI fährt die Datei zusätzlich unter LA
/// und Auckland.
void main() {
  registerTimezoneCanary();
  setUpAll(() async {
    await initializeDateFormatting('de', null);
    await initializeDateFormatting('en', null);
  });

  Future<String?> untilFor(DateTime day) async {
    final http_ = _FixedHttpClient();
    final api = ApiClient(FakeSignedInAuth(), http_);
    await api.getYearlyComparison(day.year, until: day);
    return http_.lastUri!.queryParameters['until'];
  }

  test('lokale Mitternacht: Tag und Monat bleiben (Jahresanfang)', () async {
    expect(await untilFor(DateTime(2026, 1, 1)), '01-01');
  });

  test('Monatswechsel und Jahresende bleiben', () async {
    expect(await untilFor(DateTime(2026, 3, 1)), '03-01');
    expect(await untilFor(DateTime(2026, 12, 31)), '12-31');
  });

  test('später Abend bleibt am lokalen Tag', () async {
    expect(await untilFor(DateTime(2026, 11, 15, 23, 59)), '11-15');
  });

  test('Anzeige des Stichtags hängt nicht von der Zone ab', () {
    // `MM-dd` der Antwort wird ohne Uhr gelesen; 02-29 bleibt gültig.
    expect(formatComparisonUntil('01-01', 'de'), '01.01.');
    expect(formatComparisonUntil('03-05', 'de'), '05.03.');
    expect(formatComparisonUntil('03-05', 'en'), '03/05');
    expect(formatComparisonUntil('02-29', 'de'), '29.02.');
    expect(formatComparisonUntil('11-15', 'en'), '11/15');
    expect(formatComparisonUntil('11-15', 'de'), '15.11.');
    expect(formatComparisonUntil('02-30', 'de'), isNull);
    expect(formatComparisonUntil('2026-11-15', 'de'), isNull);
    expect(formatComparisonUntil(null, 'de'), isNull);
  });
}
