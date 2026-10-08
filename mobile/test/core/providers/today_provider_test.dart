import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/clock_provider.dart';
import 'package:flutter_work_time/core/providers/today_provider.dart';

import '../../support/fake_clock.dart';

void main() {
  late TestWidgetsFlutterBinding binding;

  setUpAll(() {
    binding = TestWidgetsFlutterBinding.ensureInitialized();
  });

  /// Führt [body] in `fakeAsync` mit gekoppelter Uhr aus und prüft am Ende,
  /// dass nach `dispose` kein Timer übrig ist.
  void run(
    DateTime start,
    void Function(FakeAsync async, FakeClock clock, ProviderContainer c,
            List<DateTime> changes)
        body,
  ) {
    fakeAsync((async) {
      final clock = FakeClock(start)..bind(async);
      final container = ProviderContainer(
        overrides: [clockProvider.overrideWithValue(clock.call)],
      );
      final changes = <DateTime>[];
      container.listen(todayProvider, (_, next) => changes.add(next));
      body(async, clock, container, changes);
      container.dispose();
      expect(async.nonPeriodicTimerCount, 0);
    });
  }

  test('Initial = Tag der Uhr', () {
    run(DateTime(2026, 10, 3, 12), (async, clock, c, changes) {
      expect(c.read(todayProvider), DateTime(2026, 10, 3));
    });
  });

  test('wechselt nach Mitternacht auf den Folgetag', () {
    run(DateTime(2026, 10, 2, 23, 59, 30), (async, clock, c, changes) {
      expect(c.read(todayProvider), DateTime(2026, 10, 2));
      async.elapse(const Duration(seconds: 29));
      expect(c.read(todayProvider), DateTime(2026, 10, 2));
      async.elapse(const Duration(seconds: 2));
      expect(c.read(todayProvider), DateTime(2026, 10, 3));
      expect(changes, [DateTime(2026, 10, 3)]);
    });
  });

  test('23:59:59.999 wechselt (Mindest-Delay 1 s)', () {
    run(DateTime(2026, 10, 2, 23, 59, 59, 999), (async, clock, c, changes) {
      c.read(todayProvider);
      async.elapse(const Duration(seconds: 1));
      expect(c.read(todayProvider), DateTime(2026, 10, 3));
    });
  });

  test('Uhr exakt 00:00:00.000: kein Spin, genau ein Timer', () {
    run(DateTime(2026, 10, 3), (async, clock, c, changes) {
      expect(c.read(todayProvider), DateTime(2026, 10, 3));
      async.flushMicrotasks();
      expect(async.nonPeriodicTimerCount, 1);
      expect(changes, isEmpty);
    });
  });

  test('Mindest-Delay: Timer vor Mitternacht feuert nicht im Mikrosekundentakt',
      () {
    // Uhr steht kurz vor Mitternacht still (wie ein zu frueh gefeuerter Timer):
    // ohne Mindest-Delay wuerde der Timer im Mikrosekundentakt neu geplant.
    fakeAsync((async) {
      var reads = 0;
      final frozen = DateTime(2026, 10, 2, 23, 59, 59, 999, 500);
      final container = ProviderContainer(overrides: [
        clockProvider.overrideWithValue(() {
          reads++;
          return frozen;
        }),
      ]);
      container.read(todayProvider);
      final afterBuild = reads;
      async.elapse(const Duration(milliseconds: 500));
      expect(reads, afterBuild, reason: 'Timer darf vor 1 s nicht feuern');
      async.elapse(const Duration(milliseconds: 600));
      expect(reads, lessThanOrEqualTo(afterBuild + 2));
      expect(async.nonPeriodicTimerCount, 1);
      container.dispose();
      expect(async.nonPeriodicTimerCount, 0);
    });
  });

  test('Folgetag-Timer wird neu geplant (zweiter Wechsel)', () {
    final start = DateTime(2026, 10, 2, 23, 59, 30);
    run(start, (async, clock, c, changes) {
      c.read(todayProvider);
      async.elapse(DateTime(2026, 10, 3).difference(start));
      expect(c.read(todayProvider), DateTime(2026, 10, 3));
      expect(async.nonPeriodicTimerCount, 1);
      final delay2 = DateTime(2026, 10, 4).difference(DateTime(2026, 10, 3));
      async.elapse(delay2 - const Duration(milliseconds: 1));
      expect(c.read(todayProvider), DateTime(2026, 10, 3));
      async.elapse(const Duration(milliseconds: 1));
      expect(c.read(todayProvider), DateTime(2026, 10, 4));
      expect(changes, [DateTime(2026, 10, 3), DateTime(2026, 10, 4)]);
    });
  });

  test('Jahreswechsel und Schaltjahr', () {
    run(DateTime(2026, 12, 31, 23, 59, 30), (async, clock, c, changes) {
      c.read(todayProvider);
      async.elapse(const Duration(seconds: 31));
      expect(c.read(todayProvider), DateTime(2027, 1, 1));
    });
    final start = DateTime(2028, 2, 28, 23, 59, 30);
    run(start, (async, clock, c, changes) {
      c.read(todayProvider);
      async.elapse(DateTime(2028, 2, 29).difference(start));
      expect(c.read(todayProvider), DateTime(2028, 2, 29));
      async.elapse(DateTime(2028, 3, 1).difference(DateTime(2028, 2, 29)));
      expect(c.read(todayProvider), DateTime(2028, 3, 1));
    });
  });

  test('DST-Invarianten: Key = lokaler Folgetag, Delay = Mitternachtsdifferenz',
      () {
    // Berlin 2026-03-29 (23 h) und 2026-10-25 (25 h); LA und Auckland
    // zusaetzlich. In anderen Zonen sind es normale Tage (gleiche Invariante).
    final firstDays = [
      DateTime(2026, 3, 28),
      DateTime(2026, 10, 24),
      DateTime(2026, 3, 7),
      DateTime(2026, 10, 31),
      DateTime(2026, 4, 4),
      DateTime(2026, 9, 26),
    ];
    for (final d in firstDays) {
      final start = DateTime(d.year, d.month, d.day, 23, 59, 30);
      run(start, (async, clock, c, changes) {
        c.read(todayProvider);
        for (var i = 1; i <= 2; i++) {
          final from =
              i == 1 ? start : DateTime(d.year, d.month, d.day + i - 1);
          final next = DateTime(d.year, d.month, d.day + i);
          final delay = next.difference(from);
          async.elapse(delay - const Duration(milliseconds: 1));
          expect(
              c.read(todayProvider), DateTime(d.year, d.month, d.day + i - 1),
              reason: '$d vor Wechsel $i');
          async.elapse(const Duration(milliseconds: 1));
          expect(c.read(todayProvider), next, reason: '$d Wechsel $i');
        }
      });
    }
  });

  test('resumed nach Uhrsprung aktualisiert und plant genau einen Timer', () {
    run(DateTime(2026, 10, 2, 12), (async, clock, c, changes) {
      c.read(todayProvider);
      clock.jumpTo(DateTime(2026, 10, 3, 9));
      expect(c.read(todayProvider), DateTime(2026, 10, 2));
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(c.read(todayProvider), DateTime(2026, 10, 3));
      expect(async.nonPeriodicTimerCount, 1);
      final delay = DateTime(2026, 10, 4).difference(clock());
      async.elapse(delay);
      expect(c.read(todayProvider), DateTime(2026, 10, 4));
    });
  });

  test('paused/inactive aendern nichts', () {
    run(DateTime(2026, 10, 2, 12), (async, clock, c, changes) {
      c.read(todayProvider);
      clock.jumpTo(DateTime(2026, 10, 3, 9));
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(c.read(todayProvider), DateTime(2026, 10, 2));
      expect(changes, isEmpty);
    });
  });

  test('refresh() setzt den Tag, Listener feuert nur bei Tageswechsel', () {
    run(DateTime(2026, 10, 2, 12), (async, clock, c, changes) {
      final notifier = c.read(todayProvider.notifier);
      notifier.refresh();
      notifier.refresh();
      expect(changes, isEmpty);
      clock.jumpTo(DateTime(2026, 10, 3, 0, 0, 5));
      notifier.refresh();
      notifier.refresh();
      expect(c.read(todayProvider), DateTime(2026, 10, 3));
      expect(changes, [DateTime(2026, 10, 3)]);
      expect(async.nonPeriodicTimerCount, 1);
    });
  });

  test('dispose raeumt Timer und Observer auf', () {
    fakeAsync((async) {
      final clock = FakeClock(DateTime(2026, 10, 2, 12))..bind(async);
      var reads = 0;
      DateTime counting() {
        reads++;
        return clock();
      }

      final container = ProviderContainer(
        overrides: [clockProvider.overrideWithValue(counting)],
      );
      container.read(todayProvider);
      expect(async.nonPeriodicTimerCount, 1);
      container.dispose();
      expect(async.nonPeriodicTimerCount, 0);
      final before = reads;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      async.elapse(const Duration(days: 2));
      expect(reads, before);
    });
  });
}
