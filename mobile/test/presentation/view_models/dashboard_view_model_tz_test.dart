import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/clock_provider.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/providers/today_provider.dart';
import 'package:flutter_work_time/presentation/state/dashboard_state.dart';
import 'package:flutter_work_time/presentation/view_models/dashboard_view_model.dart';

import '../../support/api_backed_work_repository.dart';
import '../../support/fake_clock.dart';
import '../../support/fake_repositories.dart';
import '../../support/timezone_guard.dart';

/// Regression #418 fuers Dashboard: Der heutige laufende Eintrag kommt als
/// UTC-Mitternacht durch den echten `ApiClient`-Mapper. Westlich von UTC wurde
/// daraus der Vortag (kein "heute", Soll am Wochenende, Start/Stop blockiert).
///
/// Uhr: Mo 2026-10-05 12:00 lokal (fest, `FakeClock`/`fakeAsync`). Eigener
/// Container nach dem Muster von `Harness` (dort laesst sich der
/// `workRepositoryProvider` nicht ein zweites Mal ueberschreiben).
/// Lokal: `TZ=America/Los_Angeles flutter test <datei>`.
const _eightHours = Duration(hours: 8);

class _Run {
  _Run(this.async, this.world, DateTime start) {
    clock = FakeClock(start)..bind(async);
    container = ProviderContainer(overrides: [
      workRepositoryProvider.overrideWithValue(world.repository),
      overtimeRepositoryProvider.overrideWithValue(overtime),
      settingsRepositoryProvider.overrideWithValue(settings),
      clockProvider.overrideWithValue(clock.call),
    ]);
    container.listen(dashboardViewModelProvider, (_, __) {});
    container.read(todayProvider);
    container.read(dashboardViewModelProvider.notifier);
    async.flushMicrotasks();
  }

  final FakeAsync async;
  final ApiBackedWork world;
  late final FakeClock clock;
  late final ProviderContainer container;
  final overtime = FakeOvertimeRepository();
  final settings = FakeSettingsRepository();

  DashboardState get state => container.read(dashboardViewModelProvider);
  DashboardViewModel get vm =>
      container.read(dashboardViewModelProvider.notifier);

  void act(Future<void> Function() action) {
    unawaited(action());
    async.flushMicrotasks();
  }
}

void _scenarioApi(String name, void Function(_Run r) body) {
  test(name, () {
    fakeAsync((async) {
      TestWidgetsFlutterBinding.ensureInitialized();
      final world = ApiBackedWork();
      // Laufender Eintrag am Montag, so wie ihn das Backend liefert.
      world.backend.seed('2026-10-05',
          workStart: DateTime(2026, 10, 5, 9).toUtc().toIso8601String());
      final r = _Run(async, world, DateTime(2026, 10, 5, 12));
      body(r);
      r.container.dispose();
      expect(async.periodicTimerCount, 0, reason: 'Timer-Leak');
      expect(async.nonPeriodicTimerCount, 0, reason: 'Timer-Leak');
    });
  });
}

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);
  registerTimezoneCanary();

  final mo = DateTime(2026, 10, 5);

  _scenarioApi('heutiger laufender Eintrag zaehlt als heute, Soll Montag', (r) {
    expect(r.state.isLoading, isFalse);
    expect(r.state.workEntry.date, mo);
    expect(r.state.workEntry.id, '2026-10-05');
    expect(r.state.isExtraDay, isFalse);
    // 09:00 bis 12:00 gearbeitet, Soll Montag 8 h.
    expect(r.state.dailyOvertime, const Duration(hours: 3) - _eightHours);
  });

  _scenarioApi(
      'Stop schreibt in den Slot 05.10. und rechnet mit dem Montag-Soll', (r) {
    r.act(r.vm.startOrStopTimer);

    final body = r.world.backend.puts.single;
    expect(body['id'], '2026-10-05');
    expect(body['date'], '2026-10-05T00:00:00.000Z');
    expect(r.world.backend.entries.keys, ['2026-10-05']);
    expect(r.state.workEntry.date, mo);
    expect(r.state.isExtraDay, isFalse);
    expect(r.overtime.savedOvertimes.single,
        const Duration(hours: 3) - _eightHours);
  });
}
