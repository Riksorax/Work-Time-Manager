import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/utils/report_calculator.dart';

import '../../support/api_backed_work_repository.dart';
import '../../support/timezone_guard.dart';

/// Gemeinsame Report-Testfälle (#535): dieselbe Datei prüfen das Backend
/// (`ReportParityTests.cs`) und das Web (`report-calculator.parity.tz.spec.ts`).
/// Die erwarteten Werte stammen aus dem Backend, siehe
/// `testdata/report-parity/README.md`; hier wird nichts angepasst.
///
/// Zonen-Regressionstest (`*_tz_test.dart`, #418): Die Einträge kommen als
/// API-JSON (`date` = UTC-Mitternacht) und laufen durch die echte Lesegrenze
/// (`WorkRepositoryImpl` → `ApiDataSource` → `ApiClient._entryFromJson`).
/// Berichtstage werden als Kalendertag (`yyyy-MM-dd`) verglichen: Mobile
/// liefert lokale Mitternacht, das Backend UTC-Mitternacht desselben Tages.
///
/// Eingaben wie die Endpunkte: Tag und Monat bekommen die Einträge des Monats
/// des Bezugstags, die Woche alle Einträge des Falls.
///
/// Die Durchschnitte (`avgPerDayMs`, `avgPerWeekMs`) werden **exakt**
/// verglichen: Beide Seiten teilen dieselbe Ganzzahl (ms) als IEEE-Double durch
/// dieselbe Ganzzahl, und das Backend schreibt Doubles verlustfrei
/// (kürzeste Round-Trip-Darstellung) in die Datei.
///
/// Lokal: `TZ=America/Los_Angeles flutter test <datei>` (ebenso
/// `Pacific/Auckland`, `Europe/Berlin`, `UTC`).
void main() {
  registerTimezoneCanary();

  // `flutter test` läuft im Paketordner `mobile/`; die Datei liegt in der
  // Repo-Wurzel und wird nicht kopiert.
  final file = File('../testdata/report-parity/cases.json');
  final cases = ((jsonDecode(file.readAsStringSync())
          as Map<String, dynamic>)['cases'] as List<dynamic>)
      .cast<Map<String, dynamic>>();

  test('lädt die gemeinsamen Fälle', () {
    expect(cases.length, greaterThanOrEqualTo(15));
    final names = cases.map((c) => c['name'] as String).toList();
    expect(names.toSet().length, names.length);
  });

  for (final c in cases) {
    final name = c['name'] as String;
    final expected = c['expected'] as Map<String, dynamic>;
    final settingsJson = c['settings'] as Map<String, dynamic>;
    final settings = ReportSettings(
      weeklyTargetHours: (settingsJson['weeklyTargetHours'] as num).toDouble(),
      workdays: (settingsJson['workdays'] as List<dynamic>).cast<int>(),
    );
    final refKey = c['referenceDate'] as String;
    final ref = _localDate(refKey);
    final monthPrefix = refKey.substring(0, 7);
    final stored =
        Duration(milliseconds: (c['storedOvertimeMs'] as num?)?.toInt() ?? 0);
    final rawEntries =
        (c['entries'] as List<dynamic>).cast<Map<String, dynamic>>();

    group(name, () {
      late List<WorkEntryEntity> allEntries;
      late List<WorkEntryEntity> monthEntries;

      setUp(() async {
        allEntries = await _readThroughApi(rawEntries);
        monthEntries =
            allEntries.where((e) => e.id.startsWith(monthPrefix)).toList();
      });

      test('Tagesbericht', () {
        final s = calculateDailyStat(monthEntries, ref, settings);
        expect({
          'targetMs': s.target.inMilliseconds,
          'workedMs': s.worked.inMilliseconds,
          'overtimeMs': s.overtime.inMilliseconds,
        }, expected['daily']);
      });

      test('Wochenbericht', () {
        final r = calculateWeeklyReport(allEntries, ref, settings);
        final e = expected['weekly'] as Map<String, dynamic>;
        expect({
          'weekNumber': r.weekNumber,
          'start': _key(r.start),
          'end': _key(r.end),
          'totalWorkedMs': r.totalWorked.inMilliseconds,
          'totalBreaksMs': r.totalBreaks.inMilliseconds,
          'workDays': r.workDays,
          'avgPerDayMs': r.avgPerDayMs,
          'overtimeMs': r.overtime.inMilliseconds,
          'days': _days(r.days),
        }, {
          ...e,
          'start': _dayOf(e['start']),
          'end': _dayOf(e['end']),
          'avgPerDayMs': (e['avgPerDayMs'] as num).toDouble(),
          'days': _expectedDays(e['days']),
        });
      });

      test('Monatsbericht', () {
        final r = calculateMonthlyReport(monthEntries, ref, settings, stored);
        final e = expected['monthly'] as Map<String, dynamic>;
        expect({
          'month': _key(r.month),
          'totalWorkedMs': r.totalWorked.inMilliseconds,
          'totalBreaksMs': r.totalBreaks.inMilliseconds,
          'workDays': r.workDays,
          'avgPerDayMs': r.avgPerDayMs,
          'avgPerWeekMs': r.avgPerWeekMs,
          'monthlyOvertimeMs': r.monthlyOvertime.inMilliseconds,
          'totalOvertimeMs': r.totalOvertime.inMilliseconds,
          'weeks': [
            for (final w in r.weeks)
              {
                'weekNumber': w.weekNumber,
                'totalWorkedMs': w.totalWorked.inMilliseconds,
              },
          ],
          'days': _days(r.days),
        }, {
          ...e,
          'month': _dayOf(e['month']),
          'avgPerDayMs': (e['avgPerDayMs'] as num).toDouble(),
          'avgPerWeekMs': (e['avgPerWeekMs'] as num).toDouble(),
          // netWorkedMs (je Woche/Tag) wird mit #551 Web/Mobile aktiviert; bis dahin bewusst ignoriert.
          'weeks': [
            for (final w
                in (e['weeks'] as List<dynamic>).cast<Map<String, dynamic>>())
              {
                'weekNumber': w['weekNumber'],
                'totalWorkedMs': w['totalWorkedMs'],
              },
          ],
          'days': _expectedDays(e['days']),
        });
      });
    });
  }
}

/// Schickt die Einträge eines Falls durch die echte Lesegrenze der App: das
/// Fake-Backend liefert das JSON aus der Datei unverändert aus, der echte
/// `ApiClient` mappt es (Monat für Monat wie `getWorkEntriesForMonth`).
Future<List<WorkEntryEntity>> _readThroughApi(
    List<Map<String, dynamic>> raw) async {
  final work = ApiBackedWork();
  final months = <(int, int)>{};
  for (final e in raw) {
    final id = e['id'] as String;
    work.backend.entries[id] = e;
    months.add((int.parse(id.substring(0, 4)), int.parse(id.substring(5, 7))));
  }
  final result = <WorkEntryEntity>[];
  for (final (y, m) in months) {
    result.addAll(await work.repository.getWorkEntriesForMonth(y, m));
  }
  expect(result.length, raw.length, reason: 'alle Einträge gelesen');
  return result;
}

DateTime _localDate(String key) => DateTime(int.parse(key.substring(0, 4)),
    int.parse(key.substring(5, 7)), int.parse(key.substring(8, 10)));

String _key(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Kalendertag eines Backend-Zeitpunkts (UTC-Mitternacht) als `yyyy-MM-dd`.
String _dayOf(Object? iso) => (iso as String).substring(0, 10);

List<Map<String, Object>> _days(List<ReportDay> days) => [
      for (final d in days)
        {'date': _key(d.date), 'workedMs': d.worked.inMilliseconds},
    ];

List<Map<String, Object>> _expectedDays(Object? days) => [
      for (final d in (days as List<dynamic>).cast<Map<String, dynamic>>())
        {
          'date': _dayOf(d['date']),
          'workedMs': (d['workedMs'] as num).toInt(),
        },
    ];
