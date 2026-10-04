import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/clock_provider.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/providers/today_provider.dart';
import 'package:flutter_work_time/domain/entities/break_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/presentation/state/dashboard_state.dart';
import 'package:flutter_work_time/presentation/view_models/dashboard_view_model.dart';

import 'fake_clock.dart';
import 'fake_repositories.dart';

// Feste Bezugsdaten (Wochentage sind zonenunabhaengig):
// Fr 2026-10-02, Sa 2026-10-03, So 2026-10-04, Mo 2026-10-05.
// Soll: Mo-Fr, 40 h/Woche = 8 h, am Wochenende 0.
const eightHours = Duration(hours: 8);

class Harness {
  Harness(this.async, DateTime start) {
    clock = FakeClock(start)..bind(async);
    container = ProviderContainer(overrides: [
      workRepositoryProvider.overrideWithValue(work),
      overtimeRepositoryProvider.overrideWithValue(overtime),
      settingsRepositoryProvider.overrideWithValue(settings),
      clockProvider.overrideWithValue(clock.call),
    ]);
  }

  final FakeAsync async;
  late final FakeClock clock;
  late final ProviderContainer container;
  final work = FakeWorkRepository();
  final overtime = FakeOvertimeRepository();
  final settings = FakeSettingsRepository();

  DashboardViewModel get vm =>
      container.read(dashboardViewModelProvider.notifier);
  DashboardState get state => container.read(dashboardViewModelProvider);

  /// Seed: legt einen Eintrag im Fake-Repo ab.
  WorkEntryEntity seed(WorkEntryEntity e) {
    work.store[dayKey(e.date)] = e;
    return e;
  }

  /// Startet das ViewModel und wartet auf den initialen Ladevorgang.
  void boot() {
    container.listen(dashboardViewModelProvider, (_, __) {});
    container.read(todayProvider);
    vm;
    async.flushMicrotasks();
  }

  /// Fuehrt eine async Aktion aus und flusht die Microtasks.
  void act(Future<void> Function() action) {
    unawaited(action());
    async.flushMicrotasks();
  }

  void tick([Duration d = const Duration(seconds: 1)]) {
    async.elapse(d);
    async.flushMicrotasks();
  }

  bool _disposed = false;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    container.dispose();
  }
}

WorkEntryEntity entryOf(
  DateTime day, {
  DateTime? start,
  DateTime? end,
  List<BreakEntity> breaks = const [],
}) =>
    WorkEntryEntity(
      id: dayKey(day),
      date: DateTime(day.year, day.month, day.day),
      workStart: start,
      workEnd: end,
      breaks: breaks,
    );

/// Fuehrt [body] in `fakeAsync` aus; danach darf kein Timer mehr laufen.
void scenario(
  String name,
  DateTime start,
  void Function(Harness h) body, {
  void Function(Harness h)? setUp,
}) {
  test(name, () {
    fakeAsync((async) {
      TestWidgetsFlutterBinding.ensureInitialized();
      final h = Harness(async, start);
      setUp?.call(h);
      body(h);
      h.dispose();
      expect(async.periodicTimerCount, 0, reason: 'Timer-Leak');
      expect(async.nonPeriodicTimerCount, 0, reason: 'Timer-Leak');
    });
  });
}
