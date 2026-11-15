import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:flutter_work_time/data/datasources/remote/api_client.dart';
import 'package:flutter_work_time/domain/entities/yearly_leave_report.dart';

import '../../../support/fake_signed_in_auth.dart';
import '../../../support/timezone_guard.dart';

class _FixedHttpClient extends Fake implements http.Client {
  _FixedHttpClient(this.body);
  final Object body;

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async =>
      http.Response(jsonEncode(body), 200);
}

/// Urlaubs-/Krankheitszeiträume (#284) sind Kalendertage `yyyy-MM-dd`. Über
/// eine Zeitzone gelesen (`DateTime.parse(...).toLocal()` einer UTC-
/// Mitternacht), wäre es westlich von UTC (Los Angeles) der Vortag:
/// Montag → Sonntag, Monatserster → Vormonat, Neujahr → Silvester. Die
/// Assertions gelten in jeder Zone; CI fährt die Datei zusätzlich unter LA
/// und Auckland.
void main() {
  registerTimezoneCanary();

  setUpAll(() async {
    await initializeDateFormatting('de', null);
  });

  Future<YearlyLeaveReport> read(List<Map<String, dynamic>> periods) {
    final api = ApiClient(
        FakeSignedInAuth(),
        _FixedHttpClient({
          'year': 2026,
          'vacationPeriods': periods,
          'sickPeriods': periods,
        }));
    return api.getYearlyLeaveReport(2026);
  }

  test('Zeiträume bleiben auf ihrem Kalendertag (lokale Mitternacht)',
      () async {
    final r = await read([
      {'start': '2026-01-01', 'end': '2026-01-01', 'days': 1},
      {'start': '2026-03-02', 'end': '2026-03-06', 'days': 5},
      {'start': '2026-03-29', 'end': '2026-03-30', 'days': 2},
      {'start': '2026-10-25', 'end': '2026-10-26', 'days': 2},
      {'start': '2026-12-28', 'end': '2026-12-31', 'days': 4},
    ]);
    for (final list in [r.vacationPeriods, r.sickPeriods]) {
      expect(list.map((p) => (p.start, p.end)), [
        (DateTime(2026, 1, 1), DateTime(2026, 1, 1)),
        (DateTime(2026, 3, 2), DateTime(2026, 3, 6)),
        // Sommerzeit-Wechsel in Europa (29.03./25.10.).
        (DateTime(2026, 3, 29), DateTime(2026, 3, 30)),
        (DateTime(2026, 10, 25), DateTime(2026, 10, 26)),
        (DateTime(2026, 12, 28), DateTime(2026, 12, 31)),
      ]);
      for (final p in list) {
        expect(p.start.hour, 0);
        expect(p.start.isUtc, isFalse);
      }
      expect(list[1].start.weekday, DateTime.monday);
      expect(list[1].end.weekday, DateTime.friday);
      expect(list.first.start.year, 2026);
    }
  });

  test('Formatiert als dd.MM. ohne Tagesverschiebung', () async {
    final r = await read([
      {'start': '2026-08-01', 'end': '2026-08-03', 'days': 3},
    ]);
    final fmt = DateFormat('dd.MM.', 'de');
    expect(fmt.format(r.vacationPeriods.single.start), '01.08.');
    expect(fmt.format(r.vacationPeriods.single.end), '03.08.');
  });
}
