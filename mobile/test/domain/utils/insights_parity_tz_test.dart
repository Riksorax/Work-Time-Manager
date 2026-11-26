import 'dart:convert';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/clock_provider.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/domain/repositories/settings_repository.dart';
import 'package:flutter_work_time/presentation/view_models/insights_view_model.dart';

import '../../support/api_backed_work_repository.dart';
import '../../support/fake_clock.dart';
import '../../support/timezone_guard.dart';

/// Gemeinsame Insights-Testfälle (#537): dieselbe Datei prüft das Backend
/// (`AnalyticsParityTests.cs`, `InsightsParityTests`). Die erwarteten Werte
/// stammen aus dem Backend (`testdata/insights-parity/README.md`); hier wird
/// nichts angepasst. Der Test schickt die Fälle durch die **heutige**
/// Mobile-Rechnung: echtes `InsightsViewModel` (3-Monats-Fenster, Tagessoll
/// aus Wochenstunden/Arbeitstagen) über `insights_utils.dart`, Einträge über
/// die echte Lesegrenze (`ApiClient._entryFromJson`, Minuten abgeschnitten).
/// Damit ist belegt, dass der Umzug ins Backend keine Zahl ändert.
///
/// Wochentage und Serie hängen nicht von der Zone ab und werden immer
/// verglichen. Die Heatmap nutzt die lokale Startstunde und wird nur
/// verglichen, wenn `TZ` des Prozesses gleich `timeZone` des Falls ist (CI:
/// Berlin und Los Angeles). Lokal z. B.
/// `TZ=America/Los_Angeles flutter test test/domain/utils/insights_parity_tz_test.dart`
/// (ebenso `Europe/Berlin`, `UTC`, `Pacific/Auckland`).
void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);
  registerTimezoneCanary();

  final file = File('../testdata/insights-parity/cases.json');
  final cases = ((jsonDecode(file.readAsStringSync())
          as Map<String, dynamic>)['cases'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  final processZone = Platform.environment['TZ'];

  test('lädt die gemeinsamen Fälle', () {
    expect(cases.length, greaterThanOrEqualTo(12));
    final names = cases.map((c) => c['name'] as String).toList();
    expect(names.toSet().length, names.length);
  });

  for (final c in cases) {
    final name = c['name'] as String;
    final expected = c['expected'] as Map<String, dynamic>;
    final settingsJson = c['settings'] as Map<String, dynamic>;
    final refKey = c['referenceDate'] as String;
    final timeZone = c['timeZone'] as String;
    final raw = (c['entries'] as List<dynamic>).cast<Map<String, dynamic>>();

    test(name, () {
      fakeAsync((async) {
        final work = ApiBackedWork();
        for (var i = 0; i < raw.length; i++) {
          // Eigener Schlüssel je Eintrag, damit mehrere Einträge am selben Tag
          // (gleiche id) erhalten bleiben; die Monatsabfrage filtert per Präfix.
          work.backend.entries['${raw[i]['id']}#$i'] = raw[i];
        }
        final settings = _Settings(
          (settingsJson['weeklyTargetHours'] as num).toDouble(),
          (settingsJson['workdays'] as List<dynamic>).cast<int>(),
        );
        final clock = FakeClock(
          DateTime(
            int.parse(refKey.substring(0, 4)),
            int.parse(refKey.substring(5, 7)),
            int.parse(refKey.substring(8)),
            12,
          ),
        )..bind(async);
        final container = ProviderContainer(
          overrides: [
            workRepositoryProvider.overrideWithValue(work.repository),
            settingsRepositoryProvider.overrideWithValue(settings),
            clockProvider.overrideWithValue(clock.call),
          ],
        );

        container.read(insightsViewModelProvider.notifier).loadInsights();
        async.flushMicrotasks();
        final state = container.read(insightsViewModelProvider);
        expect(state.isLoading, isFalse);

        // Zeitfenster: genau die Monate von `from` bis `to` werden gelesen.
        final months = work.backend.requests
            .map((u) => u.pathSegments)
            .where((s) => s.length == 4 && s[1] == 'work-entries')
            .map((s) => '${s[2]}-${s[3].padLeft(2, '0')}')
            .toSet();
        expect(months, _monthsBetween(expected['from'], expected['to']));

        expect([
          for (final w in state.weekdayAverages)
            {
              'weekday': w.weekday,
              'averageWorkedMs': w.averageWorkDuration.inMilliseconds,
              'deviationMs': w.deviationFromOverallAverage.inMilliseconds,
              'sampleCount': w.sampleCount,
            },
        ], expected['weekdayAverages']);

        final streak = expected['overtimeStreak'] as Map<String, dynamic>;
        expect(streak['warningThresholdDays'], 5);
        expect({
          'currentStreak': state.burnoutStatus.currentStreak,
          'longestStreak': state.burnoutStatus.longestStreak,
          'isWarning': state.burnoutStatus.isWarning,
          'warningThresholdDays': 5,
        }, streak);

        if (processZone == timeZone) {
          expect([
            for (final b in state.heatmap)
              {
                'startHour': b.startHour,
                'averageOvertimeMs': b.averageOvertime.inMilliseconds,
                'sampleCount': b.sampleCount,
              },
          ], expected['startTimeHeatmap']);
        }

        container.dispose();
      });
    });
  }
}

/// `yyyy-MM` aller Monate von [from] bis [to] (`yyyy-MM-dd`).
Set<String> _monthsBetween(Object? from, Object? to) {
  final f = from as String;
  final t = to as String;
  var y = int.parse(f.substring(0, 4));
  var m = int.parse(f.substring(5, 7));
  final result = <String>{};
  while (true) {
    final key = '$y-${m.toString().padLeft(2, '0')}';
    result.add(key);
    if (key == t.substring(0, 7)) return result;
    if (++m > 12) {
      m = 1;
      y++;
    }
  }
}

/// Einstellungen des Falls; das `InsightsViewModel` liest nur diese beiden.
class _Settings extends Fake implements SettingsRepository {
  _Settings(this._hours, this._workdays);

  final double _hours;
  final List<int> _workdays;

  @override
  double getTargetWeeklyHours() => _hours;

  @override
  List<int> getWorkdays() => _workdays;
}
