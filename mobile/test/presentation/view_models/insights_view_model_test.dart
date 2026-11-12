import 'package:logger/logger.dart';
import '../../support/reported_logs.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_work_time/core/providers/clock_provider.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/providers/today_provider.dart';
import 'package:flutter_work_time/domain/repositories/settings_repository.dart';
import 'package:flutter_work_time/domain/repositories/work_repository.dart';
import 'package:flutter_work_time/presentation/view_models/insights_view_model.dart';

import '../../support/fake_clock.dart';
import 'insights_view_model_test.mocks.dart';

@GenerateMocks([WorkRepository, SettingsRepository])
void main() {
  // todayProvider (#379) registriert einen WidgetsBindingObserver.
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  late MockWorkRepository work;
  late MockSettingsRepository settings;

  setUp(() {
    work = MockWorkRepository();
    settings = MockSettingsRepository();
    when(settings.getWorkdays()).thenReturn([1, 2, 3, 4, 5]);
    when(settings.getTargetWeeklyHours()).thenReturn(40.0);
    when(work.getWorkEntriesForMonth(any, any)).thenAnswer((_) async => []);
  });

  ProviderContainer make(FakeClock clock) => ProviderContainer(overrides: [
        workRepositoryProvider.overrideWithValue(work),
        settingsRepositoryProvider.overrideWithValue(settings),
        clockProvider.overrideWithValue(clock.call),
      ]);

  test('Monatsfenster ab Uhr 2026-11-01: 11, 10, 9', () {
    fakeAsync((async) {
      final c = make(FakeClock(DateTime(2026, 11, 1, 8))..bind(async));
      c.read(insightsViewModelProvider.notifier).loadInsights();
      async.flushMicrotasks();
      verify(work.getWorkEntriesForMonth(2026, 11)).called(1);
      verify(work.getWorkEntriesForMonth(2026, 10)).called(1);
      verify(work.getWorkEntriesForMonth(2026, 9)).called(1);
      verifyNoMoreInteractions(work);
      expect(c.read(insightsViewModelProvider).isLoading, false);
      c.dispose();
    });
  });

  test('Monatsfenster ueber den Jahreswechsel (Uhr 2027-01-01): 1, 12, 11', () {
    fakeAsync((async) {
      final c = make(FakeClock(DateTime(2027, 1, 1, 8))..bind(async));
      c.read(insightsViewModelProvider.notifier).loadInsights();
      async.flushMicrotasks();
      verify(work.getWorkEntriesForMonth(2027, 1)).called(1);
      verify(work.getWorkEntriesForMonth(2026, 12)).called(1);
      verify(work.getWorkEntriesForMonth(2026, 11)).called(1);
      verifyNoMoreInteractions(work);
      c.dispose();
    });
  });

  test('kein Repository-Zugriff beim Lesen und kein Auto-Reload (Schutz)', () {
    fakeAsync((async) {
      final clock = FakeClock(DateTime(2026, 10, 31, 23, 59, 30))..bind(async);
      final c = make(clock);
      c.read(insightsViewModelProvider);
      async.elapse(const Duration(seconds: 30));
      async.flushMicrotasks();
      expect(c.read(todayProvider), DateTime(2026, 11, 1));
      verifyNever(work.getWorkEntriesForMonth(any, any));
      c.dispose();
      expect(async.pendingTimers, isEmpty);
    });
  });

  group('Logging beim Fehler (#506) - Insights', () {
    final events = <LogEvent>[];
    captureLogs(events);

    for (final entry in transientNetworkErrors.entries) {
      test('${entry.key} wird nicht an Crashlytics gemeldet', () async {
        when(work.getWorkEntriesForMonth(any, any))
            .thenAnswer((_) async => throw entry.value);
        final c = make(FakeClock(DateTime(2026, 11, 1, 8)));
        addTearDown(c.dispose);
        await c.read(insightsViewModelProvider.notifier).loadInsights();
        expect(reported(events, 'InsightsViewModel'), isEmpty);
      });
    }

    test('anderer Fehler wird weiter auf Level error geloggt', () async {
      when(work.getWorkEntriesForMonth(any, any))
          .thenAnswer((_) async => throw StateError('kaputt'));
      final c = make(FakeClock(DateTime(2026, 11, 1, 8)));
      addTearDown(c.dispose);
      await c.read(insightsViewModelProvider.notifier).loadInsights();
      expect(reported(events, 'InsightsViewModel').map((e) => e.level),
          [Level.error]);
    });
  });
}
