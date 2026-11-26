import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/utils/home_office_stats.dart';

import '../../support/api_backed_work_repository.dart';
import '../../support/timezone_guard.dart';

/// Gemeinsame Home-Office-Testfälle (#537): dieselbe Datei prüft das Backend
/// (`AnalyticsParityTests.cs`, `HomeOfficeParityTests`). Die erwarteten Werte
/// stammen aus dem Backend (`testdata/home-office-parity/README.md`); hier wird
/// nichts angepasst. Der Test rechnet wie heute der Home-Office-Jahresexport
/// (`reports_page.dart`, `_exportHomeOfficeYearPdf`): 12 Monatsabfragen über
/// die echte Lesegrenze, Jahr = `calculateHomeOfficeStats` über alle, Monat =
/// `calculateHomeOfficeStats` je Monat. Damit ist belegt, dass der Umzug ins
/// Backend keine Zahl ändert.
///
/// Zonen-Regressionstest (`*_tz_test.dart`, #418): Die Zählung hängt von
/// keiner Zone ab; der Kalendertag kommt aus der `id`.
void main() {
  registerTimezoneCanary();

  final file = File('../testdata/home-office-parity/cases.json');
  final cases = ((jsonDecode(file.readAsStringSync())
          as Map<String, dynamic>)['cases'] as List<dynamic>)
      .cast<Map<String, dynamic>>();

  test('lädt die gemeinsamen Fälle', () {
    expect(cases.length, greaterThanOrEqualTo(5));
    final names = cases.map((c) => c['name'] as String).toList();
    expect(names.toSet().length, names.length);
  });

  for (final c in cases) {
    final name = c['name'] as String;
    final year = c['year'] as int;
    final expected = c['expected'] as Map<String, dynamic>;
    final raw = (c['entries'] as List<dynamic>).cast<Map<String, dynamic>>();

    test(name, () async {
      final work = ApiBackedWork();
      for (var i = 0; i < raw.length; i++) {
        // Eigener Schlüssel je Eintrag: mehrere Einträge am selben Tag bleiben.
        work.backend.entries['${raw[i]['id']}#$i'] = raw[i];
      }
      final perMonth = <List<WorkEntryEntity>>[
        for (var m = 1; m <= 12; m++)
          await work.repository.getWorkEntriesForMonth(year, m),
      ];
      final total = calculateHomeOfficeStats([for (final e in perMonth) ...e]);

      expect(
        {
          'year': year,
          'homeOfficeDays': total.homeOfficeDays,
          'officeDays': total.officeDays,
          'totalDays': total.totalDays,
          'homeOfficeRatio': total.ratio,
          'months': [for (var m = 1; m <= 12; m++) _month(m, perMonth[m - 1])],
          'homeOfficeDates': [for (final d in total.homeOfficeDates) _key(d)],
        },
        {
          ...expected,
          'homeOfficeRatio': (expected['homeOfficeRatio'] as num?)?.toDouble(),
          'months': [
            for (final m in (expected['months'] as List<dynamic>)
                .cast<Map<String, dynamic>>())
              {
                ...m,
                'homeOfficeRatio': (m['homeOfficeRatio'] as num?)?.toDouble(),
              },
          ],
        },
      );
    });
  }
}

Map<String, Object?> _month(int month, List<WorkEntryEntity> entries) {
  final s = calculateHomeOfficeStats(entries);
  return {
    'month': month,
    'homeOfficeDays': s.homeOfficeDays,
    'officeDays': s.officeDays,
    'totalDays': s.totalDays,
    'homeOfficeRatio': s.ratio,
  };
}

String _key(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
