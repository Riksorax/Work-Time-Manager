import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_work_time/data/datasources/remote/api_client.dart';
import 'package:flutter_work_time/domain/entities/trend_report.dart';

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

Map<String, dynamic> _bucket(String key, String start, String end) => {
      'key': key,
      'start': start,
      'end': end,
      'workedMs': 0,
      'targetMs': 0,
      'overtimeMs': 0,
      'cumulativeOvertimeMs': 0,
      'hasData': false,
    };

/// Trend (#531): `start`/`end` sind UTC-Mitternacht des Kalendertags. Über
/// `.toLocal()` gelesen, wäre es westlich von UTC (Los Angeles) der Vortag:
/// Montag → Sonntag, Monatserster → Vormonat. Die Assertions gelten in jeder
/// Zone; CI fährt die Datei zusätzlich unter LA und Auckland.
void main() {
  registerTimezoneCanary();

  Future<TrendReport> read(List<Map<String, dynamic>> buckets,
      {DateTime? date}) async {
    final http_ = _FixedHttpClient({'granularity': 'week', 'buckets': buckets});
    final api = ApiClient(FakeSignedInAuth(), http_);
    return api.getTrendReport(
        date ?? DateTime(2026, 11, 12), TrendGranularity.week);
  }

  test('Wochengrenzen bleiben Montag und Sonntag (beide Schreibweisen)',
      () async {
    final r = await read([
      _bucket(
          '2026-W46', '2026-11-09T00:00:00+00:00', '2026-11-15T00:00:00+00:00'),
      _bucket('2026-W47', '2026-11-16T00:00:00Z', '2026-11-22T00:00:00Z'),
    ]);
    expect(r.buckets[0].start, DateTime(2026, 11, 9));
    expect(r.buckets[0].start.weekday, DateTime.monday);
    expect(r.buckets[0].end, DateTime(2026, 11, 15));
    expect(r.buckets[0].end.weekday, DateTime.sunday);
    expect(r.buckets[1].start, DateTime(2026, 11, 16));
  });

  test('Monatserster und Jahreswechsel bleiben im richtigen Monat', () async {
    final r = await read([
      _bucket(
          '2026-01', '2026-01-01T00:00:00+00:00', '2026-01-31T00:00:00+00:00'),
      _bucket(
          '2026-W01', '2025-12-29T00:00:00+00:00', '2026-01-04T00:00:00+00:00'),
    ]);
    expect(r.buckets[0].start, DateTime(2026, 1, 1));
    expect(r.buckets[0].end, DateTime(2026, 1, 31));
    expect(r.buckets[1].start, DateTime(2025, 12, 29));
    expect(r.buckets[1].end, DateTime(2026, 1, 4));
  });

  test('Bezugstag im Pfad sind die lokalen Kalenderfelder', () async {
    final http_ = _FixedHttpClient({'granularity': 'week', 'buckets': []});
    final api = ApiClient(FakeSignedInAuth(), http_);
    // Lokale Mitternacht wie aus todayProvider; in UTC wäre es in Auckland
    // der Vortag.
    await api.getTrendReport(DateTime(2026, 1, 1), TrendGranularity.week);
    expect(http_.lastUri!.path, endsWith('/reports/trend/2026/1/1'));
  });
}
