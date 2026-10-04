import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_work_time/core/providers/clock_provider.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/providers/today_provider.dart';
import 'package:flutter_work_time/data/datasources/remote/api_client.dart';
import 'package:flutter_work_time/domain/repositories/settings_repository.dart';
import 'package:flutter_work_time/domain/repositories/work_repository.dart';
import 'package:flutter_work_time/presentation/view_models/yearly_report_view_model.dart';

import '../../support/fake_clock.dart';
import 'yearly_report_view_model_test.mocks.dart';

/// Liefert im Test ein festes aktives Arbeitszeit-Profil, ohne den echten
/// Aufbau über `authStateProvider`/`sharedPreferencesProvider` nachzustellen.
class _FixedActiveWorkProfileIdNotifier extends ActiveWorkProfileIdNotifier {
  _FixedActiveWorkProfileIdNotifier(this._value);
  final String? _value;
  @override
  String? build() => _value;
}

@GenerateMocks([WorkRepository, SettingsRepository, ApiClient])
void main() {
  // todayProvider (#379) registriert einen WidgetsBindingObserver.
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  late MockWorkRepository mockWorkRepository;
  late MockSettingsRepository mockSettingsRepository;
  late MockApiClient mockApiClient;
  late ProviderContainer container;

  void buildContainer(String? activeProfileId) {
    container = ProviderContainer(
      overrides: [
        workRepositoryProvider.overrideWithValue(mockWorkRepository),
        settingsRepositoryProvider.overrideWithValue(mockSettingsRepository),
        apiClientProvider.overrideWithValue(mockApiClient),
        activeWorkProfileIdProvider.overrideWith(
            () => _FixedActiveWorkProfileIdNotifier(activeProfileId)),
      ],
    );
  }

  setUp(() {
    mockWorkRepository = MockWorkRepository();
    mockSettingsRepository = MockSettingsRepository();
    mockApiClient = MockApiClient();

    when(mockSettingsRepository.getWorkdays()).thenReturn([1, 2, 3, 4, 5]);
    when(mockSettingsRepository.getTargetWeeklyHours()).thenReturn(40.0);
    when(mockWorkRepository.getWorkEntriesForMonth(any, any))
        .thenAnswer((_) async => []);
  });

  tearDown(() {
    container.dispose();
  });

  group(
      'YearlyReportViewModel — Monatsüberstunden geben das aktive Profil weiter (siehe #291)',
      () {
    test('Standard-Profil: getMonthlyReport wird ohne profileId angefragt',
        () async {
      buildContainer(null);
      when(mockApiClient.getMonthlyReport(any, any, profileId: null))
          .thenAnswer((_) async => {'monthlyOvertimeMs': 0});

      await container
          .read(yearlyReportViewModelProvider.notifier)
          .loadYear(2026);
      // _refineOvertimeFromApi läuft unawaited im Hintergrund weiter.
      await Future.delayed(Duration.zero);

      verify(mockApiClient.getMonthlyReport(2026, 1, profileId: null))
          .called(1);
      verify(mockApiClient.getMonthlyReport(2026, 12, profileId: null))
          .called(1);
    });

    test(
        'zusätzliches Profil: getMonthlyReport wird mit dessen profileId angefragt',
        () async {
      buildContainer('p1');
      when(mockApiClient.getMonthlyReport(any, any, profileId: 'p1'))
          .thenAnswer((_) async => {'monthlyOvertimeMs': 0});

      await container
          .read(yearlyReportViewModelProvider.notifier)
          .loadYear(2026);
      await Future.delayed(Duration.zero);

      verify(mockApiClient.getMonthlyReport(2026, 1, profileId: 'p1'))
          .called(1);
      verify(mockApiClient.getMonthlyReport(2026, 12, profileId: 'p1'))
          .called(1);
      verifyNever(mockApiClient.getMonthlyReport(any, any, profileId: null));
    });

    test('übernimmt die verfeinerten Überstunden aus der API-Antwort',
        () async {
      buildContainer('p1');
      when(mockApiClient.getMonthlyReport(any, any, profileId: 'p1'))
          .thenAnswer((_) async => {'monthlyOvertimeMs': 0});
      when(mockApiClient.getMonthlyReport(2026, 3, profileId: 'p1'))
          .thenAnswer((_) async => {'monthlyOvertimeMs': 120000});

      await container
          .read(yearlyReportViewModelProvider.notifier)
          .loadYear(2026);
      await Future.delayed(Duration.zero);

      final state = container.read(yearlyReportViewModelProvider);
      expect(state.months[2].overtime, const Duration(minutes: 2));
    });
  });

  group('Startjahr aus todayProvider (#387)', () {
    ProviderContainer makeContainer(FakeClock clock) => ProviderContainer(
          overrides: [
            workRepositoryProvider.overrideWithValue(mockWorkRepository),
            settingsRepositoryProvider
                .overrideWithValue(mockSettingsRepository),
            apiClientProvider.overrideWithValue(mockApiClient),
            clockProvider.overrideWithValue(clock.call),
          ],
        );

    test('Startjahr kommt aus der Uhr (2026-12-31 -> 2026, 2027-01-01 -> 2027)',
        () {
      fakeAsync((async) {
        final c1 = makeContainer(FakeClock(DateTime(2026, 12, 31, 12)));
        expect(c1.read(yearlyReportViewModelProvider).year, 2026);
        c1.dispose();
        final c2 = makeContainer(FakeClock(DateTime(2027, 1, 1, 12)));
        expect(c2.read(yearlyReportViewModelProvider).year, 2027);
        c2.dispose();
        expect(async.pendingTimers, isEmpty);
      });
    });

    test('gewaehltes Jahr bleibt nach Jahreswechsel, kein Auto-Reload', () {
      fakeAsync((async) {
        when(mockApiClient.getMonthlyReport(any, any,
                profileId: anyNamed('profileId')))
            .thenAnswer((_) async => {'monthlyOvertimeMs': 0});
        final clock = FakeClock(DateTime(2026, 12, 31, 23, 59, 30))
          ..bind(async);
        container = makeContainer(clock);
        final vm = container.read(yearlyReportViewModelProvider.notifier);
        vm.loadYear(2025);
        async.flushMicrotasks();
        clearInteractions(mockWorkRepository);

        async.elapse(const Duration(seconds: 30));
        async.flushMicrotasks();
        expect(container.read(todayProvider), DateTime(2027, 1, 1));
        expect(container.read(yearlyReportViewModelProvider).year, 2025);
        verifyNever(mockWorkRepository.getWorkEntriesForMonth(any, any));
      });
    });
  });
}
