import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/clock_provider.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/domain/utils/iso_week.dart';
import 'package:flutter_work_time/presentation/state/reports_state.dart';
import 'package:flutter_work_time/presentation/view_models/reports_view_model.dart';
import 'package:http/http.dart' as http;

import '../../support/api_backed_work_repository.dart';
import '../../support/fake_repositories.dart';
import '../../support/timezone_guard.dart';

/// Regression #418 fuer die Reports: Berichtstage des Backends (`_dayKey`) und
/// die Tages-/Wochen-/Monatsberechnung ueber die echte API-Kette (UTC-Mitternacht
/// -> `ApiClient`-Mapper -> `ReportsViewModel`).
///
/// Feste Daten (Uhr Mo 2026-10-05 12:00 lokal), keine Abhaengigkeit von der
/// Maschine. Lokal: `TZ=America/Los_Angeles flutter test <datei>`.
class _NoProfile extends ActiveWorkProfileIdNotifier {
  @override
  String? build() => null;
}

final _clockNow = DateTime(2026, 10, 5, 12);

String _utc(DateTime local) => local.toUtc().toIso8601String();

void _seedWorkDay(FakeBackendHttpClient b, int y, int m, int d) {
  final id =
      '$y-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
  b.seed(id,
      workStart: _utc(DateTime(y, m, d, 8)),
      workEnd: _utc(DateTime(y, m, d, 16)));
}

http.Response _ok(Map<String, dynamic> json) => http.Response(
      jsonEncode(json),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);
  registerTimezoneCanary();

  late ApiBackedWork world;
  late FakeSettingsRepository settings;

  setUp(() {
    world = ApiBackedWork();
    settings = FakeSettingsRepository();
  });

  ProviderContainer newContainer() {
    final c = ProviderContainer(overrides: [
      clockProvider.overrideWithValue(() => _clockNow),
      workRepositoryProvider.overrideWithValue(world.repository),
      settingsRepositoryProvider.overrideWithValue(settings),
      apiClientProvider.overrideWithValue(world.api),
      activeWorkProfileIdProvider.overrideWith(_NoProfile.new),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  /// Startet das ViewModel (heute = Mo 05.10.) und waehlt [day].
  Future<ReportsState> loadAt(ProviderContainer c, DateTime day) async {
    c.listen(reportsViewModelProvider, (_, __) {});
    c.read(reportsViewModelProvider.notifier);
    await pumpEventQueue();
    c.read(reportsViewModelProvider.notifier).selectDate(day);
    await pumpEventQueue();
    return c.read(reportsViewModelProvider);
  }

  group('_dayKey: Berichtstage des Backends (UTC-Mitternacht)', () {
    test('Wochen- und Monatsbericht: Schluessel sind Kalendertage', () async {
      world.backend.reports.addAll({
        '/api/reports/daily/2026/10/5': _ok({'overtimeMs': 0}),
        '/api/reports/weekly/2026/10/5': _ok({
          'totalWorkedMs': 0,
          'days': [
            {'date': '2026-10-05T00:00:00Z', 'workedMs': 28800000},
            {'date': '2026-10-06T00:00:00+00:00', 'workedMs': 3600000},
          ],
        }),
        '/api/reports/monthly/2026/10': _ok({
          'days': [
            {'date': '2026-10-05T00:00:00.000Z', 'workedMs': 28800000},
            {'date': '2026-10-06T00:00:00.000+00:00', 'workedMs': 3600000},
          ],
          'weeks': [],
        }),
      });
      final c = newContainer();
      final state = await loadAt(c, DateTime(2026, 10, 5));

      final expected = {
        DateTime(2026, 10, 5): const Duration(hours: 8),
        DateTime(2026, 10, 6): const Duration(hours: 1),
      };
      expect(state.weeklyReportState.dailyWork, expected);
      expect(state.monthlyReportState.dailyWork, expected);
    });
  });

  group('Tages-/Wochen-/Monatsbericht ueber die API-Kette', () {
    test('Eintrag erscheint am 05.10. (nicht am 04.10.), Soll Montag, KW 41',
        () async {
      _seedWorkDay(world.backend, 2026, 10, 4); // Sonntag, KW 40
      _seedWorkDay(world.backend, 2026, 10, 5); // Montag, KW 41
      final c = newContainer();

      final monday = await loadAt(c, DateTime(2026, 10, 5));
      expect(monday.dailyReportState.entries.map((e) => e.id), ['2026-10-05']);
      expect(monday.dailyReportState.workTime, const Duration(hours: 8));
      expect(monday.weeklyReportState.dailyWork.keys, [DateTime(2026, 10, 5)]);
      expect(monday.weeklyReportState.workDays, 1);
      expect(monday.monthlyReportState.weeklyWork.keys.toSet(), {40, 41});

      final entry = monday.dailyReportState.entries.single;
      expect(entry.date, DateTime(2026, 10, 5));
      expect(isoWeekNumber(entry.date), 41);
      final vm = c.read(reportsViewModelProvider.notifier);
      expect(vm.getEffectiveDailyTargetForDate(entry.date),
          const Duration(hours: 8));

      vm.selectDate(DateTime(2026, 10, 4));
      await pumpEventQueue();
      final sunday = c.read(reportsViewModelProvider);
      expect(sunday.dailyReportState.entries.map((e) => e.id), ['2026-10-04']);
      expect(isoWeekNumber(sunday.dailyReportState.entries.single.date), 40);
    });
  });

  // E4: `dailyWork[entry.date]` (Wochenbericht) nutzt `date` als Map-Schluessel.
  // Nach dem Fix ist das die lokale Mitternacht (vorher in Europa 01:00/02:00).
  // Die Report-Endpunkte antworten 500, damit die lokale Berechnung stehen bleibt.
  group('E4 Wochenbericht: dailyWork-Schluessel sind Mitternacht', () {
    final cases = <String, ({DateTime select, List<DateTime> days})>{
      'Woche Mo 19. bis So 25.10.2026 (Ende der Sommerzeit)': (
        select: DateTime(2026, 10, 25),
        days: [
          DateTime(2026, 10, 19),
          DateTime(2026, 10, 23),
          DateTime(2026, 10, 25)
        ],
      ),
      'Woche Mo 23. bis So 29.03.2026 (Beginn der Sommerzeit)': (
        select: DateTime(2026, 3, 29),
        days: [
          DateTime(2026, 3, 23),
          DateTime(2026, 3, 27),
          DateTime(2026, 3, 29)
        ],
      ),
      'Sommerwoche ab Mo 13.07.2026': (
        select: DateTime(2026, 7, 13),
        days: [DateTime(2026, 7, 13)],
      ),
      'Winterwoche ab Mo 12.01.2026': (
        select: DateTime(2026, 1, 12),
        days: [DateTime(2026, 1, 12)],
      ),
    };
    for (final c in cases.entries) {
      test(c.key, () async {
        for (final d in c.value.days) {
          _seedWorkDay(world.backend, d.year, d.month, d.day);
        }
        final container = newContainer();
        final state = await loadAt(container, c.value.select);

        final weekly = state.weeklyReportState;
        expect(weekly.dailyWork.keys.toList(), c.value.days);
        expect(weekly.dailyWork.keys.every((k) => k.hour == 0 && k.minute == 0),
            isTrue);
        expect(weekly.workDays, c.value.days.length);
        expect(weekly.dailyWork.values.fold(Duration.zero, (a, b) => a + b),
            Duration(hours: 8 * c.value.days.length));

        // Regression (unveraendert gruen): der Monatsbericht normalisiert schon.
        expect(state.monthlyReportState.dailyWork.keys.toList(), c.value.days);
      });
    }
  });
}
