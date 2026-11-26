import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import 'package:flutter_work_time/core/providers/clock_provider.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/utils/api_errors.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/repositories/settings_repository.dart';
import 'package:flutter_work_time/presentation/state/reports_state.dart';
import 'package:flutter_work_time/presentation/view_models/insights_view_model.dart';

import '../../support/analytics_fixture.dart';
import '../../support/fake_repositories.dart';
import '../../support/offline_fixture.dart' show hostLookupError;
import '../../support/reported_logs.dart';

/// Insights (#537): angemeldet vom Backend, als Gast lokal; Fehler-, Profil-
/// und Ladelauf-Verhalten des ViewModels. Uhr und Zone fest.
class _Settings extends Fake implements SettingsRepository {
  @override
  double getTargetWeeklyHours() => 40;

  @override
  List<int> getWorkdays() => const [1, 2, 3, 4, 5];
}

const _user = UserEntity(id: 'u1', email: 'a@b.c');

void main() {
  // todayProvider (#379) registriert einen WidgetsBindingObserver.
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  late FakeAnalyticsApi api;
  late FakeWorkRepository work;
  final events = <LogEvent>[];
  captureLogs(events);

  setUp(() {
    api = FakeAnalyticsApi();
    work = FakeWorkRepository();
  });

  ProviderContainer make({UserEntity? user = _user, String? profileId}) {
    final c = ProviderContainer(overrides: [
      clockProvider.overrideWithValue(() => DateTime(2026, 11, 15, 9)),
      authStateProvider.overrideWithValue(AsyncValue.data(user)),
      apiClientProvider.overrideWithValue(api),
      workRepositoryProvider.overrideWithValue(work),
      settingsRepositoryProvider.overrideWithValue(_Settings()),
      activeWorkProfileIdProvider.overrideWith(() => TestProfile(profileId)),
      deviceTimeZoneProvider
          .overrideWithValue(const FixedTimeZone('America/Los_Angeles')),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  group('angemeldet', () {
    test('lädt vom Backend: Bezugstag heute, Gerätezone, kein Monatslesen',
        () async {
      final c = make();
      await c.read(insightsViewModelProvider.notifier).loadInsights();

      expect(api.insightsCalls, [
        (
          date: DateTime(2026, 11, 15),
          timeZone: 'America/Los_Angeles',
          profileId: null
        ),
      ]);
      expect(work.monthReads, isEmpty);
      final s = c.read(insightsViewModelProvider);
      expect(s.isLoading, isFalse);
      expect(s.loadFailure, ReportsLoadFailure.none);
      expect(s.weekdayAverages.map((w) => w.weekday), [1, 2, 3, 4, 5]);
      expect(s.weekdayAverages[2].averageWorkDuration,
          const Duration(hours: 9, minutes: 5));
      expect(s.weekdayAverages[2].deviationFromOverallAverage,
          const Duration(minutes: 35));
      expect(s.weekdayAverages[0].sampleCount, 11);
      expect(s.heatmap.map((b) => b.startHour), [7, 8, 9]);
      expect(s.heatmap[2].averageOvertime, const Duration(minutes: -21));
      expect(s.burnoutStatus.isWarning, isFalse);
      expect(s.burnoutStatus.currentStreak, 2);
      expect(s.burnoutStatus.longestStreak, 4);
      expect(s.hasNoData, isFalse);
    });

    test('Warnung kommt aus der Antwort', () async {
      api.onInsights = (c) async => insightsJson(c.date, warning: true);
      final c = make();
      await c.read(insightsViewModelProvider.notifier).loadInsights();
      final s = c.read(insightsViewModelProvider).burnoutStatus;
      expect((s.isWarning, s.currentStreak, s.longestStreak), (true, 7, 9));
    });

    test('Zusatzprofil fragt mit profileId an', () async {
      final c = make(profileId: 'p1');
      await c.read(insightsViewModelProvider.notifier).loadInsights();
      expect(api.insightsCalls.single.profileId, 'p1');
    });

    test('leere Antwort: hasNoData', () async {
      api.onInsights = (c) async => insightsJson(c.date, empty: true);
      final c = make();
      await c.read(insightsViewModelProvider.notifier).loadInsights();
      expect(c.read(insightsViewModelProvider).hasNoData, isTrue);
    });

    test('offline: loadFailure offline, nur logger.i', () async {
      api.onInsights = (_) async => throw hostLookupError;
      final c = make();
      await c.read(insightsViewModelProvider.notifier).loadInsights();
      final s = c.read(insightsViewModelProvider);
      expect(s.loadFailure, ReportsLoadFailure.offline);
      expect(s.isLoading, isFalse);
      expect(s.hasNoData, isFalse);
      expect(reported(events, 'InsightsViewModel'), isEmpty);
    });

    test('anderer Fehler: loadFailure failed, logger.e ohne Ausnahmetext',
        () async {
      api.onInsights = (_) async => throw const ApiException('x', 500);
      final c = make();
      await c.read(insightsViewModelProvider.notifier).loadInsights();
      expect(c.read(insightsViewModelProvider).loadFailure,
          ReportsLoadFailure.failed);
      final r = reported(events, 'InsightsViewModel');
      expect(r.map((e) => e.level), [Level.error]);
      expect(r.single.message.toString(), contains('ApiException(500)'));
    });

    test('retry nach Fehler lädt erneut und zeigt Werte', () async {
      var fail = true;
      api.onInsights = (c) async {
        if (fail) throw hostLookupError;
        return insightsJson(c.date);
      };
      final c = make();
      final vm = c.read(insightsViewModelProvider.notifier);
      await vm.loadInsights();
      fail = false;
      await vm.retry();
      final s = c.read(insightsViewModelProvider);
      expect(s.loadFailure, ReportsLoadFailure.none);
      expect(s.weekdayAverages, hasLength(5));
      expect(api.insightsCalls, hasLength(2));
    });

    test('NotSignedInException: kein Fehlerzustand, nicht gemeldet', () async {
      api.onInsights = (_) async => throw const NotSignedInException('x');
      final c = make();
      await c.read(insightsViewModelProvider.notifier).loadInsights();
      expect(c.read(insightsViewModelProvider).loadFailure,
          ReportsLoadFailure.none);
      expect(reported(events, 'InsightsViewModel'), isEmpty);
    });

    test('ensureLoaded lädt nur einmal je Aufbau', () async {
      final c = make();
      final vm = c.read(insightsViewModelProvider.notifier);
      vm.ensureLoaded();
      vm.ensureLoaded();
      await pumpEventQueue();
      expect(api.insightsCalls, hasLength(1));
    });

    test(
        'Profilwechsel: neuer Aufbau, späte Antwort des alten Profils '
        'wird verworfen, die Ansicht fordert neu an', () async {
      final hold = Completer<Map<String, dynamic>>();
      api.onInsights = (call) => call.profileId == null
          ? hold.future
          : Future.value(insightsJson(call.date, warning: true));
      final c = make();
      c.listen(insightsViewModelProvider, (_, __) {});
      final first = c.read(insightsViewModelProvider.notifier).loadInsights();

      (c.read(activeWorkProfileIdProvider.notifier) as TestProfile)
          .select('p2');
      await pumpEventQueue();
      expect(c.read(insightsViewModelProvider).isLoading, isTrue);

      c.read(insightsViewModelProvider.notifier).ensureLoaded();
      await pumpEventQueue();
      expect(api.insightsCalls.map((x) => x.profileId), [null, 'p2']);
      expect(c.read(insightsViewModelProvider).burnoutStatus.isWarning, isTrue);

      hold.complete(insightsJson(DateTime(2026, 11, 15)));
      await first;
      // Die alte Antwort überschreibt den Stand von p2 nicht.
      expect(c.read(insightsViewModelProvider).burnoutStatus.isWarning, isTrue);
    });
  });

  group('Gast', () {
    WorkEntryEntity entry(int month, int day, int startHour) => WorkEntryEntity(
          id: '2026-${month.toString().padLeft(2, '0')}-'
              '${day.toString().padLeft(2, '0')}',
          date: DateTime(2026, month, day),
          workStart: DateTime(2026, month, day, startHour),
          workEnd: DateTime(2026, month, day, startHour + 9),
        );

    test('rechnet lokal über drei Monate, kein API-Aufruf', () async {
      work.store['2026-11-02'] = entry(11, 2, 8); // Montag
      work.store['2026-10-05'] = entry(10, 5, 8); // Montag
      final c = make(user: null);
      await c.read(insightsViewModelProvider.notifier).loadInsights();

      expect(api.insightsCalls, isEmpty);
      expect(work.monthReads.toSet(), {'2026-11', '2026-10', '2026-09'});
      final s = c.read(insightsViewModelProvider);
      expect(s.weekdayAverages.single.weekday, 1);
      expect(s.weekdayAverages.single.averageWorkDuration,
          const Duration(hours: 9));
      expect(s.heatmap.single.startHour, 8);
      expect(s.heatmap.single.averageOvertime, const Duration(hours: 1));
    });

    test('Lesefehler lokal: loadFailure failed', () async {
      work.failReads = true;
      final c = make(user: null);
      await c.read(insightsViewModelProvider.notifier).loadInsights();
      expect(c.read(insightsViewModelProvider).loadFailure,
          ReportsLoadFailure.failed);
    });
  });
}
