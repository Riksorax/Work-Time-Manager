import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_work_time/core/providers/clock_provider.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/providers/today_provider.dart';
import 'package:flutter_work_time/data/datasources/remote/api_client.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/repositories/settings_repository.dart';
import 'package:flutter_work_time/domain/repositories/work_repository.dart';
import 'package:flutter_work_time/domain/utils/date_utils.dart';
import 'package:flutter_work_time/domain/utils/iso_week.dart';
import 'package:flutter_work_time/presentation/state/leave_balance_state.dart';
import 'package:flutter_work_time/presentation/state/reports_state.dart';
import 'package:flutter_work_time/presentation/view_models/leave_balance_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/reports_view_model.dart';

import '../../support/fake_clock.dart';
import 'reports_view_model_test.mocks.dart';

/// Liefert im Test ein festes aktives Arbeitszeit-Profil, ohne den echten
/// Aufbau über `authStateProvider`/`sharedPreferencesProvider` nachzustellen.
class _FixedActiveWorkProfileIdNotifier extends ActiveWorkProfileIdNotifier {
  _FixedActiveWorkProfileIdNotifier(this._value);
  final String? _value;
  @override
  String? build() => _value;
}

/// Feste Uhr für alle Tests (Fr 2026-10-02, kein DateTime.now(), #387).
final _fixedNow = DateTime(2026, 10, 2, 12);

/// Zählt `build()`-Läufe, um einen Neuaufbau durch `todayProvider` zu erkennen.
class _CountingReportsViewModel extends ReportsViewModel {
  static int builds = 0;
  @override
  ReportsState build() {
    builds++;
    return super.build();
  }
}

class _CountingLeaveViewModel extends LeaveBalanceViewModel {
  static int builds = 0;
  @override
  LeaveBalanceState build() {
    builds++;
    return const LeaveBalanceState();
  }
}

@GenerateMocks([WorkRepository, SettingsRepository, ApiClient])
void main() {
  // todayProvider registriert einen WidgetsBindingObserver.
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  late MockWorkRepository mockWorkRepository;
  late MockSettingsRepository mockSettingsRepository;
  late MockApiClient mockApiClient;
  late ProviderContainer container;

  /// Baut den Container neu mit dem übergebenen aktiven Profil auf. Wird nur
  /// von den profileId-Tests genutzt; alle anderen Tests laufen unverändert
  /// mit dem Standard-Profil (kein aktives Profil, `null`) aus [setUp].
  void rebuildContainerWithActiveProfile(String? profileId) {
    container.dispose();
    container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(() => _fixedNow),
        workRepositoryProvider.overrideWithValue(mockWorkRepository),
        settingsRepositoryProvider.overrideWithValue(mockSettingsRepository),
        apiClientProvider.overrideWithValue(mockApiClient),
        activeWorkProfileIdProvider
            .overrideWith(() => _FixedActiveWorkProfileIdNotifier(profileId)),
      ],
    );
  }

  setUp(() {
    mockWorkRepository = MockWorkRepository();
    mockSettingsRepository = MockSettingsRepository();
    mockApiClient = MockApiClient();
    container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(() => _fixedNow),
        workRepositoryProvider.overrideWithValue(mockWorkRepository),
        settingsRepositoryProvider.overrideWithValue(mockSettingsRepository),
      ],
    );

    // Default Stubs
    when(mockSettingsRepository.getWorkdays()).thenReturn([1, 2, 3, 4, 5]);
    when(mockSettingsRepository.getTargetWeeklyHours()).thenReturn(40.0);

    // Stub for initial load (current date)
    final now = _fixedNow;
    when(mockWorkRepository.getWorkEntriesForMonth(now.year, now.month))
        .thenAnswer((_) async => []);
  });

  tearDown(() {
    container.dispose();
  });

  group('ReportsViewModel', () {
    test('initial state should be loading and then populated', () async {
      // Arrange
      final now = _fixedNow;
      when(mockWorkRepository.getWorkEntriesForMonth(now.year, now.month))
          .thenAnswer((_) async => []);

      // Act
      container.read(reportsViewModelProvider.notifier);
      // init is called in build via microtask, so we wait for pump
      await Future.delayed(Duration.zero);

      // Assert
      final state = container.read(reportsViewModelProvider);
      expect(state.isLoading, false);
      expect(state.selectedDay!.year, now.year);
      verify(mockWorkRepository.getWorkEntriesForMonth(now.year, now.month))
          .called(1);
    });

    group('selectDate normalisiert auf lokale Mitternacht (#362)', () {
      for (final date in [
        DateTime(2025, 10, 26, 23),
        DateTime(2025, 3, 23, 23),
      ]) {
        test('$date', () async {
          when(mockWorkRepository.getWorkEntriesForMonth(date.year, date.month))
              .thenAnswer((_) async => []);
          final viewModel = container.read(reportsViewModelProvider.notifier);
          await Future.delayed(Duration.zero);
          viewModel.selectDate(date);
          await Future.delayed(Duration.zero);
          expect(container.read(reportsViewModelProvider).selectedDay,
              DateTime(date.year, date.month, date.day));
        });
      }
    });

    group('ISO-Kalenderwoche in monthlyReportState.weeklyWork (#352)', () {
      WorkEntryEntity entryOn(int y, int m, int d) => WorkEntryEntity(
            id: '$y-$m-$d',
            date: DateTime(y, m, d),
            workStart: DateTime(y, m, d, 8),
            workEnd: DateTime(y, m, d, 16),
          );

      Future<Map<int, Duration>> weeklyWorkFor(
          int year, int month, List<WorkEntryEntity> entries) async {
        when(mockWorkRepository.getWorkEntriesForMonth(year, month))
            .thenAnswer((_) async => entries);
        final viewModel = container.read(reportsViewModelProvider.notifier);
        await Future.delayed(Duration.zero);
        viewModel.selectDate(DateTime(year, month, 15));
        await Future.delayed(Duration.zero);
        return container
            .read(reportsViewModelProvider)
            .monthlyReportState
            .weeklyWork;
      }

      test('Montag 31.08.2026 (Sommerzeit) liegt in KW 36', () async {
        final weekly = await weeklyWorkFor(2026, 8, [
          entryOn(2026, 8, 28),
          entryOn(2026, 8, 31),
        ]);
        expect(weekly.keys.toSet(), {35, 36});
      });

      test('Dezember 2025: 29.12. gehoert zu KW 1', () async {
        final weekly = await weeklyWorkFor(2025, 12, [
          entryOn(2025, 12, 22),
          entryOn(2025, 12, 29),
        ]);
        expect(weekly.keys.toSet(), {52, 1});
      });

      test('Januar 2027: 01.01. gehoert zu KW 53, keine Woche 0', () async {
        final weekly = await weeklyWorkFor(2027, 1, [
          entryOn(2027, 1, 1),
          entryOn(2027, 1, 4),
        ]);
        expect(weekly.keys.toSet(), {53, 1});
      });
    });

    test('should calculate daily report correctly', () async {
      final date = DateTime(2023, 10, 26);
      final entry = WorkEntryEntity(
        id: '1',
        date: date,
        workStart: DateTime(2023, 10, 26, 8, 0),
        workEnd: DateTime(2023, 10, 26, 17, 0),
        breaks: [],
      );

      when(mockWorkRepository.getWorkEntriesForMonth(2023, 10))
          .thenAnswer((_) async => [entry]);

      final viewModel = container.read(reportsViewModelProvider.notifier);

      // Wait for init() to complete
      await Future.delayed(Duration.zero);

      viewModel.selectDate(date); // This triggers load and calculation

      // Wait for selectDate's async part to complete
      await Future.delayed(Duration.zero);

      final state = container.read(reportsViewModelProvider);

      expect(state.dailyReportState.totalTime, const Duration(hours: 9));
      expect(state.dailyReportState.entries.length, 1);
      expect(state.dailyReportState.entries.first, entry);
    });

    test('should calculate weekly report correctly', () async {
      // 26.10.2023 is a Thursday. Week is Mon 23 - Sun 29.
      final date = DateTime(2023, 10, 26);

      final entry1 = WorkEntryEntity(
        id: '1',
        date: DateTime(2023, 10, 23), // Monday
        workStart: DateTime(2023, 10, 23, 8, 0),
        workEnd: DateTime(2023, 10, 23, 16, 0), // 8h
      );

      final entry2 = WorkEntryEntity(
        id: '2',
        date: DateTime(2023, 10, 26), // Thursday
        workStart: DateTime(2023, 10, 26, 8, 0),
        workEnd: DateTime(2023, 10, 26, 12, 0), // 4h
      );

      when(mockWorkRepository.getWorkEntriesForMonth(2023, 10))
          .thenAnswer((_) async => [entry1, entry2]);

      when(mockSettingsRepository.getWorkdays()).thenReturn([1, 2, 3, 4, 5]);
      when(mockSettingsRepository.getTargetWeeklyHours()).thenReturn(40.0);
      // Target per day = 8h.
      // Work days in this week = 2.
      // Target for week (based on actual days) = 16h.
      // Actual = 8 + 4 = 12h.
      // Overtime = 12 - 16 = -4h.

      final viewModel = container.read(reportsViewModelProvider.notifier);

      // Wait for init()
      await Future.delayed(Duration.zero);

      viewModel.selectDate(date);

      // Wait for selectDate()
      await Future.delayed(Duration.zero);

      final state = container.read(reportsViewModelProvider);

      expect(state.weeklyReportState.totalNetWorkDuration,
          const Duration(hours: 12));
      expect(state.weeklyReportState.workDays, 2);
      expect(state.weeklyReportState.overtime, const Duration(hours: -4));
    });

    test(
        'weekly report should cap target at weekly hours when extra days worked',
        () async {
      // 5-Tage-Woche, aber 6 Tage gearbeitet
      // Woche: Mo 23.10 - So 29.10.2023
      final date = DateTime(2023, 10, 28); // Samstag

      final entries = [
        WorkEntryEntity(
          id: '1',
          date: DateTime(2023, 10, 23), // Mo
          workStart: DateTime(2023, 10, 23, 8, 0),
          workEnd: DateTime(2023, 10, 23, 16, 0), // 8h
        ),
        WorkEntryEntity(
          id: '2',
          date: DateTime(2023, 10, 24), // Di
          workStart: DateTime(2023, 10, 24, 8, 0),
          workEnd: DateTime(2023, 10, 24, 16, 0), // 8h
        ),
        WorkEntryEntity(
          id: '3',
          date: DateTime(2023, 10, 25), // Mi
          workStart: DateTime(2023, 10, 25, 8, 0),
          workEnd: DateTime(2023, 10, 25, 16, 0), // 8h
        ),
        WorkEntryEntity(
          id: '4',
          date: DateTime(2023, 10, 26), // Do
          workStart: DateTime(2023, 10, 26, 8, 0),
          workEnd: DateTime(2023, 10, 26, 16, 0), // 8h
        ),
        WorkEntryEntity(
          id: '5',
          date: DateTime(2023, 10, 27), // Fr
          workStart: DateTime(2023, 10, 27, 8, 0),
          workEnd: DateTime(2023, 10, 27, 16, 0), // 8h
        ),
        WorkEntryEntity(
          id: '6',
          date: DateTime(2023, 10, 28), // Sa (Zusatztag)
          workStart: DateTime(2023, 10, 28, 8, 0),
          workEnd: DateTime(2023, 10, 28, 14, 0), // 6h
        ),
      ];

      when(mockWorkRepository.getWorkEntriesForMonth(2023, 10))
          .thenAnswer((_) async => entries);

      when(mockSettingsRepository.getWorkdays()).thenReturn([1, 2, 3, 4, 5]);
      when(mockSettingsRepository.getTargetWeeklyHours()).thenReturn(40.0);
      // Ohne Fix: Soll = 8h * 6 Tage = 48h, Ist = 46h, Overtime = -2h (FALSCH)
      // Mit Fix:  Soll = 8h * 5 Tage = 40h (gedeckelt), Ist = 46h, Overtime = +6h (RICHTIG)

      final viewModel = container.read(reportsViewModelProvider.notifier);

      await Future.delayed(Duration.zero);

      viewModel.selectDate(date);

      await Future.delayed(Duration.zero);

      final state = container.read(reportsViewModelProvider);

      expect(state.weeklyReportState.totalNetWorkDuration,
          const Duration(hours: 46));
      // Wochen-Soll sollte auf 40h gedeckelt sein (nicht 48h)
      expect(state.weeklyReportState.overtime, const Duration(hours: 6));
    });

    test('getEffectiveDailyTargetForDate returns zero for extra day', () async {
      final date = DateTime(2023, 10, 28); // Samstag

      final entries = [
        WorkEntryEntity(
          id: '1',
          date: DateTime(2023, 10, 23),
          workStart: DateTime(2023, 10, 23, 8, 0),
          workEnd: DateTime(2023, 10, 23, 16, 0),
        ),
        WorkEntryEntity(
          id: '2',
          date: DateTime(2023, 10, 24),
          workStart: DateTime(2023, 10, 24, 8, 0),
          workEnd: DateTime(2023, 10, 24, 16, 0),
        ),
        WorkEntryEntity(
          id: '3',
          date: DateTime(2023, 10, 25),
          workStart: DateTime(2023, 10, 25, 8, 0),
          workEnd: DateTime(2023, 10, 25, 16, 0),
        ),
        WorkEntryEntity(
          id: '4',
          date: DateTime(2023, 10, 26),
          workStart: DateTime(2023, 10, 26, 8, 0),
          workEnd: DateTime(2023, 10, 26, 16, 0),
        ),
        WorkEntryEntity(
          id: '5',
          date: DateTime(2023, 10, 27),
          workStart: DateTime(2023, 10, 27, 8, 0),
          workEnd: DateTime(2023, 10, 27, 16, 0),
        ),
        WorkEntryEntity(
          id: '6',
          date: DateTime(2023, 10, 28), // Zusatztag
          workStart: DateTime(2023, 10, 28, 8, 0),
          workEnd: DateTime(2023, 10, 28, 14, 0),
        ),
      ];

      when(mockWorkRepository.getWorkEntriesForMonth(2023, 10))
          .thenAnswer((_) async => entries);

      final viewModel = container.read(reportsViewModelProvider.notifier);

      await Future.delayed(Duration.zero);

      viewModel.selectDate(date);

      await Future.delayed(Duration.zero);

      // Samstag ist der 6. Arbeitstag in einer 5-Tage-Woche => Soll = 0
      final effectiveTarget = viewModel.getEffectiveDailyTargetForDate(date);
      expect(effectiveTarget, Duration.zero);

      // Mo-Fr sollten reguläres Soll haben
      final mondayTarget =
          viewModel.getEffectiveDailyTargetForDate(DateTime(2023, 10, 23));
      expect(mondayTarget, const Duration(hours: 8));
    });

    group('Multi-Select Mode', () {
      test('toggleMultiSelectMode should toggle the mode and clear selection',
          () async {
        final now = _fixedNow;
        when(mockWorkRepository.getWorkEntriesForMonth(now.year, now.month))
            .thenAnswer((_) async => []);

        final viewModel = container.read(reportsViewModelProvider.notifier);
        await Future.delayed(Duration.zero);

        expect(viewModel.state.multiSelectMode, false);
        expect(viewModel.state.selectedDates, isEmpty);

        viewModel.toggleMultiSelectMode();
        expect(viewModel.state.multiSelectMode, true);

        viewModel.toggleMultiSelectMode();
        expect(viewModel.state.multiSelectMode, false);
      });

      test('addDateToSelection should add past and future dates', () async {
        final now = _fixedNow;
        when(mockWorkRepository.getWorkEntriesForMonth(now.year, now.month))
            .thenAnswer((_) async => []);

        final viewModel = container.read(reportsViewModelProvider.notifier);
        await Future.delayed(Duration.zero);

        final pastDate = _fixedNow.subtract(const Duration(days: 5));
        final futureDate = _fixedNow.add(const Duration(days: 5));

        viewModel.addDateToSelection(pastDate);
        expect(viewModel.state.selectedDates.length, 1);

        viewModel.addDateToSelection(futureDate);
        expect(viewModel.state.selectedDates.length,
            2); // Future dates are now allowed
      });

      test('toggleDateSelection should add/remove dates', () async {
        final now = _fixedNow;
        when(mockWorkRepository.getWorkEntriesForMonth(now.year, now.month))
            .thenAnswer((_) async => []);

        final viewModel = container.read(reportsViewModelProvider.notifier);
        await Future.delayed(Duration.zero);

        final testDate = _fixedNow.subtract(const Duration(days: 3));

        viewModel.toggleDateSelection(testDate);
        expect(viewModel.state.selectedDates,
            contains(DateTime(testDate.year, testDate.month, testDate.day)));

        viewModel.toggleDateSelection(testDate);
        expect(viewModel.state.selectedDates, isEmpty);
      });

      test('clearDateSelection should empty selected dates', () async {
        final now = _fixedNow;
        when(mockWorkRepository.getWorkEntriesForMonth(now.year, now.month))
            .thenAnswer((_) async => []);

        final viewModel = container.read(reportsViewModelProvider.notifier);
        await Future.delayed(Duration.zero);

        final date1 = _fixedNow.subtract(const Duration(days: 1));
        final date2 = _fixedNow.subtract(const Duration(days: 2));

        viewModel.addDateToSelection(date1);
        viewModel.addDateToSelection(date2);
        expect(viewModel.state.selectedDates.length, 2);

        viewModel.clearDateSelection();
        expect(viewModel.state.selectedDates, isEmpty);
      });

      test('saveBatchWorkEntries should create entries for all selected dates',
          () async {
        final now = _fixedNow;
        when(mockWorkRepository.getWorkEntriesForMonth(now.year, now.month))
            .thenAnswer((_) async => []);

        when(mockWorkRepository.saveWorkEntry(any)).thenAnswer((_) async => {});

        final viewModel = container.read(reportsViewModelProvider.notifier);
        await Future.delayed(Duration.zero);

        final dates = [
          _fixedNow.subtract(const Duration(days: 3)),
          _fixedNow.subtract(const Duration(days: 2)),
          _fixedNow.subtract(const Duration(days: 1)),
        ];

        viewModel.toggleMultiSelectMode();
        for (final date in dates) {
          viewModel.addDateToSelection(date);
        }

        await viewModel.saveBatchWorkEntries(
          dates,
          WorkEntryType.vacation,
          TimeOfDay(hour: 8, minute: 0),
          TimeOfDay(hour: 16, minute: 0),
        );

        // Verify that saveWorkEntry was called for each date
        verify(mockWorkRepository.saveWorkEntry(any)).called(3);
        expect(viewModel.state.selectedDates, isEmpty);
        expect(viewModel.state.multiSelectMode, false);
      });
    });

    group(
        'Server-Reports geben das aktive Arbeitszeit-Profil weiter (siehe #291)',
        () {
      test('Standard-Profil: Server-Reports werden ohne profileId angefragt',
          () async {
        rebuildContainerWithActiveProfile(null);
        final now = _fixedNow;
        when(mockWorkRepository.getWorkEntriesForMonth(now.year, now.month))
            .thenAnswer((_) async => []);
        when(mockApiClient.getDailyReport(now.year, now.month, now.day,
                profileId: null))
            .thenAnswer((_) async => {'overtimeMs': 0});
        when(mockApiClient.getWeeklyReport(now.year, now.month, now.day,
                profileId: null))
            .thenAnswer((_) async => {
                  'totalWorkedMs': 0,
                  'totalBreaksMs': 0,
                  'avgPerDayMs': 0,
                  'overtimeMs': 0,
                  'workDays': 0
                });
        when(mockApiClient.getMonthlyReport(now.year, now.month,
                profileId: null))
            .thenAnswer((_) async => {
                  'totalWorkedMs': 0,
                  'totalBreaksMs': 0,
                  'avgPerDayMs': 0,
                  'monthlyOvertimeMs': 0,
                  'totalOvertimeMs': 0,
                  'workDays': 0,
                  'avgPerWeekMs': 0
                });

        container.read(reportsViewModelProvider.notifier);
        await Future.delayed(Duration.zero);

        verify(mockApiClient.getDailyReport(now.year, now.month, now.day,
                profileId: null))
            .called(1);
        verify(mockApiClient.getWeeklyReport(now.year, now.month, now.day,
                profileId: null))
            .called(1);
        verify(mockApiClient.getMonthlyReport(now.year, now.month,
                profileId: null))
            .called(1);
      });

      test(
          'zusätzliches Profil: Server-Reports werden mit dessen profileId angefragt',
          () async {
        rebuildContainerWithActiveProfile('p1');
        final now = _fixedNow;
        when(mockWorkRepository.getWorkEntriesForMonth(now.year, now.month))
            .thenAnswer((_) async => []);
        when(mockApiClient.getDailyReport(now.year, now.month, now.day,
                profileId: 'p1'))
            .thenAnswer((_) async => {'overtimeMs': 0});
        when(mockApiClient.getWeeklyReport(now.year, now.month, now.day,
                profileId: 'p1'))
            .thenAnswer((_) async => {
                  'totalWorkedMs': 0,
                  'totalBreaksMs': 0,
                  'avgPerDayMs': 0,
                  'overtimeMs': 0,
                  'workDays': 0
                });
        when(mockApiClient.getMonthlyReport(now.year, now.month,
                profileId: 'p1'))
            .thenAnswer((_) async => {
                  'totalWorkedMs': 0,
                  'totalBreaksMs': 0,
                  'avgPerDayMs': 0,
                  'monthlyOvertimeMs': 0,
                  'totalOvertimeMs': 0,
                  'workDays': 0,
                  'avgPerWeekMs': 0
                });

        container.read(reportsViewModelProvider.notifier);
        await Future.delayed(Duration.zero);

        verify(mockApiClient.getDailyReport(now.year, now.month, now.day,
                profileId: 'p1'))
            .called(1);
        verify(mockApiClient.getWeeklyReport(now.year, now.month, now.day,
                profileId: 'p1'))
            .called(1);
        verify(mockApiClient.getMonthlyReport(now.year, now.month,
                profileId: 'p1'))
            .called(1);
      });
    });
  });

  group('Tageswechsel (#387)', () {
    WorkEntryEntity entry(int y, int m, int d, {int hours = 8}) =>
        WorkEntryEntity(
          id: '$y-$m-$d',
          date: DateTime(y, m, d),
          workStart: DateTime(y, m, d, 8),
          workEnd: DateTime(y, m, d, 8 + hours),
        );

    /// Fake-Uhr ab [start], Container in `fakeAsync`, `init()` abgeschlossen.
    void scenario(
      String name,
      DateTime start,
      void Function(FakeAsync async, ProviderContainer c, FakeClock clock,
              ReportsViewModel vm, MockWorkRepository work)
          body, {
      List<WorkEntryEntity> entries = const [],
    }) {
      test(name, () {
        fakeAsync((async) {
          final clock = FakeClock(start)..bind(async);
          final work = MockWorkRepository();
          final settings = MockSettingsRepository();
          when(settings.getWorkdays()).thenReturn([1, 2, 3, 4, 5]);
          when(settings.getTargetWeeklyHours()).thenReturn(40.0);
          when(work.getWorkEntriesForMonth(any, any)).thenAnswer((inv) async {
            final y = inv.positionalArguments[0] as int;
            final m = inv.positionalArguments[1] as int;
            return entries
                .where((e) => e.date.year == y && e.date.month == m)
                .toList();
          });
          _CountingReportsViewModel.builds = 0;
          final c = ProviderContainer(overrides: [
            clockProvider.overrideWithValue(clock.call),
            workRepositoryProvider.overrideWithValue(work),
            settingsRepositoryProvider.overrideWithValue(settings),
            reportsViewModelProvider
                .overrideWith(_CountingReportsViewModel.new),
          ]);
          final vm = c.read(reportsViewModelProvider.notifier);
          async.flushMicrotasks();
          body(async, c, clock, vm, work);
          c.dispose();
          expect(async.pendingTimers, isEmpty);
        });
      });
    }

    ReportsState st(ProviderContainer c) => c.read(reportsViewModelProvider);

    test('ReportsState.initial normalisiert auf lokale Mitternacht', () {
      final s = ReportsState.initial(DateTime(2026, 10, 2, 23, 59, 30));
      expect(s.selectedDay, DateTime(2026, 10, 2));
      expect(s.focusedDay, DateTime(2026, 10, 2));
      expect(s.selectedMonth, DateTime(2026, 10));
      expect(s.isLoading, isTrue);
    });

    // A1
    scenario('init(): selectedDay/Monat/focusedDay normalisiert aus der Uhr',
        DateTime(2026, 10, 2, 23, 59, 30), (async, c, clock, vm, work) {
      final s = st(c);
      expect(s.selectedDay, DateTime(2026, 10, 2));
      expect(s.selectedDay!.hour, 0);
      expect(s.focusedDay, DateTime(2026, 10, 2));
      expect(s.selectedMonth, DateTime(2026, 10));
      expect(s.isLoading, isFalse);
    });

    // T1
    scenario('T1 Auswahl auf heute folgt dem Tageswechsel, kein Monats-Reload',
        DateTime(2026, 10, 2, 23, 59, 30), (async, c, clock, vm, work) {
      expect(st(c).selectedDay, DateTime(2026, 10, 2));
      async.elapse(const Duration(seconds: 30));
      async.flushMicrotasks();
      final s = st(c);
      expect(s.selectedDay, DateTime(2026, 10, 3));
      expect(s.focusedDay, DateTime(2026, 10, 3));
      expect(s.selectedMonth, DateTime(2026, 10));
      expect(s.isLoading, isFalse);
      verify(work.getWorkEntriesForMonth(2026, 10)).called(1);
    });

    scenario('T1b Tagesbericht rechnet auf den neuen Tag',
        DateTime(2026, 10, 2, 23, 59, 30), (async, c, clock, vm, work) {
      expect(st(c).dailyReportState.entries.single.date, DateTime(2026, 10, 2));
      async.elapse(const Duration(seconds: 30));
      async.flushMicrotasks();
      expect(st(c).dailyReportState.entries, isEmpty);
    }, entries: [entry(2026, 10, 2)]);

    // T2
    scenario(
        'T2 manuell gewaehlter Tag bleibt', DateTime(2026, 10, 2, 23, 59, 30),
        (async, c, clock, vm, work) {
      vm.selectDate(DateTime(2026, 10, 1));
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 30));
      async.flushMicrotasks();
      expect(st(c).selectedDay, DateTime(2026, 10, 1));
      expect(st(c).selectedMonth, DateTime(2026, 10));
    });

    // T3
    scenario('T3 Monatswechsel, Auswahl auf heute: Monat folgt und laedt neu',
        DateTime(2026, 10, 31, 23, 59, 30), (async, c, clock, vm, work) {
      verify(work.getWorkEntriesForMonth(2026, 10)).called(1);
      async.elapse(const Duration(seconds: 30));
      async.flushMicrotasks();
      final s = st(c);
      expect(s.selectedDay, DateTime(2026, 11, 1));
      expect(s.selectedMonth, DateTime(2026, 11));
      expect(s.isLoading, isFalse);
      verify(work.getWorkEntriesForMonth(2026, 11)).called(1);
      expect(s.monthlyReportState.workDays, 1);
    }, entries: [entry(2026, 11, 1, hours: 4)]);

    // T4
    scenario('T4 Monatswechsel, Auswahl manuell: nichts aendert sich',
        DateTime(2026, 10, 31, 23, 59, 30), (async, c, clock, vm, work) {
      vm.selectDate(DateTime(2026, 10, 15));
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 30));
      async.flushMicrotasks();
      expect(st(c).selectedDay, DateTime(2026, 10, 15));
      expect(st(c).selectedMonth, DateTime(2026, 10));
      verifyNever(work.getWorkEntriesForMonth(2026, 11));
    });

    // T5
    scenario(
        'T5 selectedMonth auf heutigem Monat, Auswahl manuell: Monatswechsel '
        'aendert nichts',
        DateTime(2026, 10, 31, 23, 59, 30), (async, c, clock, vm, work) {
      vm.selectDate(DateTime(2026, 10, 20));
      async.flushMicrotasks();
      expect(st(c).selectedMonth, DateTime(2026, 10));
      async.elapse(const Duration(seconds: 30));
      async.flushMicrotasks();
      expect(st(c).selectedMonth, DateTime(2026, 10));
      expect(st(c).selectedDay, DateTime(2026, 10, 20));
      verifyNever(work.getWorkEntriesForMonth(2026, 11));
    });

    // T6
    scenario('T6 Wochenwechsel So->Mo: Wochenbericht rechnet ab Mo 2026-10-05',
        DateTime(2026, 10, 4, 23, 59, 30), (async, c, clock, vm, work) {
      expect(st(c).selectedDay, DateTime(2026, 10, 4));
      // Woche Mo 09-28 .. So 10-04: Fr 10-02 (8 h) zaehlt mit.
      expect(st(c).weeklyReportState.totalNetWorkDuration,
          const Duration(hours: 8));
      async.elapse(const Duration(seconds: 30));
      async.flushMicrotasks();
      expect(st(c).selectedDay, DateTime(2026, 10, 5));
      // Woche Mo 10-05 .. So 10-11: nur Mo 10-05 (4 h).
      expect(st(c).weeklyReportState.totalNetWorkDuration,
          const Duration(hours: 4));
    }, entries: [entry(2026, 10, 2), entry(2026, 10, 5, hours: 4)]);

    // T7
    scenario(
        'T7 Jahreswechsel: Silvesterwoche bleibt 2026-W53, Mo 2027-01-04 ist '
        '2027-W01',
        DateTime(2026, 12, 31, 23, 59, 30), (async, c, clock, vm, work) {
      DateTime mondayOf(DateTime d) => addCalendarDays(d, -(d.weekday - 1));
      expect(st(c).selectedDay, DateTime(2026, 12, 31));
      async.elapse(const Duration(seconds: 30));
      async.flushMicrotasks();
      var s = st(c);
      expect(s.selectedDay, DateTime(2027, 1, 1));
      expect(s.selectedMonth, DateTime(2027, 1));
      verify(work.getWorkEntriesForMonth(2027, 1)).called(1);
      var monday = mondayOf(s.selectedDay!);
      expect(monday, DateTime(2026, 12, 28));
      expect((isoWeekYear(monday), isoWeekNumber(monday)), (2026, 53));
      // Wochenbericht: nur Fr 2027-01-01 (3 h), nicht Mo 2027-01-04.
      expect(
          s.weeklyReportState.totalNetWorkDuration, const Duration(hours: 3));

      // Montag 2027-01-04 (Resume-Pfad): Auswahl stand auf heute (Fr 01-01).
      clock.jumpTo(DateTime(2027, 1, 4, 0, 0, 5));
      c.read(todayProvider.notifier).refresh();
      async.flushMicrotasks();
      s = st(c);
      expect(s.selectedDay, DateTime(2027, 1, 4));
      monday = mondayOf(s.selectedDay!);
      expect(monday, DateTime(2027, 1, 4));
      expect((isoWeekYear(monday), isoWeekNumber(monday)), (2027, 1));
      expect(
          s.weeklyReportState.totalNetWorkDuration, const Duration(hours: 5));
    }, entries: [entry(2027, 1, 1, hours: 3), entry(2027, 1, 4, hours: 5)]);

    // T8
    scenario('T8 Resume-Pfad: Uhrsprung + refresh() zieht die Auswahl nach',
        DateTime(2026, 10, 2, 22), (async, c, clock, vm, work) {
      expect(st(c).selectedDay, DateTime(2026, 10, 2));
      clock.jumpTo(DateTime(2026, 10, 3, 0, 0, 5));
      c.read(todayProvider.notifier).refresh();
      async.flushMicrotasks();
      expect(st(c).selectedDay, DateTime(2026, 10, 3));
      expect(st(c).selectedMonth, DateTime(2026, 10));
      verify(work.getWorkEntriesForMonth(2026, 10)).called(1);
    });

    // T9
    scenario('T9 Multi-Select bleibt unangetastet (Auswahl != heute)',
        DateTime(2026, 10, 2, 23, 59, 30), (async, c, clock, vm, work) {
      vm.selectDate(DateTime(2026, 10, 1));
      async.flushMicrotasks();
      vm.toggleMultiSelectMode();
      vm.addDateToSelection(DateTime(2026, 10, 6));
      vm.addDateToSelection(DateTime(2026, 10, 7));
      async.elapse(const Duration(seconds: 30));
      async.flushMicrotasks();
      expect(st(c).multiSelectMode, isTrue);
      expect(
          st(c).selectedDates, {DateTime(2026, 10, 6), DateTime(2026, 10, 7)});
      expect(st(c).selectedDay, DateTime(2026, 10, 1));
    });

    scenario(
        'T9b Multi-Select, Auswahl == heute: selectedDay folgt, Dates bleiben',
        DateTime(2026, 10, 2, 23, 59, 30), (async, c, clock, vm, work) {
      vm.toggleMultiSelectMode();
      vm.addDateToSelection(DateTime(2026, 10, 6));
      async.elapse(const Duration(seconds: 30));
      async.flushMicrotasks();
      expect(st(c).selectedDay, DateTime(2026, 10, 3));
      expect(st(c).multiSelectMode, isTrue);
      expect(st(c).selectedDates, {DateTime(2026, 10, 6)});
    });

    // T10
    scenario('T10 kein Rebuild, geladene Monatsdaten bleiben erhalten',
        DateTime(2026, 10, 2, 23, 59, 30), (async, c, clock, vm, work) {
      expect(_CountingReportsViewModel.builds, 1);
      async.elapse(const Duration(seconds: 30));
      async.flushMicrotasks();
      expect(_CountingReportsViewModel.builds, 1);
      expect(identical(c.read(reportsViewModelProvider.notifier), vm), isTrue);
      expect(st(c).selectedDay, DateTime(2026, 10, 3));
      // Monatsbericht kennt weiterhin den Eintrag vom 2.10. ohne Reload.
      expect(st(c).monthlyReportState.workDays, 1);
      verify(work.getWorkEntriesForMonth(2026, 10)).called(1);
    }, entries: [entry(2026, 10, 2)]);

    // T11: Dispose in jedem Szenario (pendingTimers leer); hier zusaetzlich
    // Dispose waehrend eines offenen Reloads.
    scenario('T11 Dispose waehrend laufendem Reload schreibt keinen State',
        DateTime(2026, 10, 31, 23, 59, 30), (async, c, clock, vm, work) {
      final pending = Completer<List<WorkEntryEntity>>();
      when(work.getWorkEntriesForMonth(2026, 11))
          .thenAnswer((_) => pending.future);
      async.elapse(const Duration(seconds: 30)); // Reload 11/2026 offen
      verify(work.getWorkEntriesForMonth(2026, 11)).called(1);
      c.dispose();
      pending.complete([]);
      // wirft, falls nach Dispose State geschrieben wird
      async.flushMicrotasks();
    });

    // Charakterisierung Entscheidung 4
    scenario(
        'loadCurrentMonthData setzt nur selectedMonth (bekannte Inkonsistenz)',
        DateTime(2026, 11, 1, 10), (async, c, clock, vm, work) {
      vm.selectDate(DateTime(2026, 10, 15));
      async.flushMicrotasks();
      expect(st(c).selectedMonth, DateTime(2026, 10));
      vm.loadCurrentMonthData();
      async.flushMicrotasks();
      expect(st(c).selectedMonth, DateTime(2026, 11));
      expect(st(c).selectedDay, DateTime(2026, 10, 15));
    });
  });

  group('Resturlaub-Invalidierung (#278)', () {
    late ProviderContainer leaveContainer;
    late ReportsViewModel vm;

    setUp(() async {
      _CountingLeaveViewModel.builds = 0;
      when(mockWorkRepository.saveWorkEntry(any)).thenAnswer((_) async {});
      when(mockWorkRepository.deleteWorkEntry(any)).thenAnswer((_) async {});
      when(mockWorkRepository.getWorkEntriesForMonth(any, any))
          .thenAnswer((_) async => []);
      leaveContainer = ProviderContainer(overrides: [
        clockProvider.overrideWithValue(() => _fixedNow),
        workRepositoryProvider.overrideWithValue(mockWorkRepository),
        settingsRepositoryProvider.overrideWithValue(mockSettingsRepository),
        leaveBalanceViewModelProvider.overrideWith(_CountingLeaveViewModel.new),
      ]);
      leaveContainer.listen(leaveBalanceViewModelProvider, (_, __) {});
      vm = leaveContainer.read(reportsViewModelProvider.notifier);
      await Future.delayed(Duration.zero);
    });

    tearDown(() => leaveContainer.dispose());

    final entry = WorkEntryEntity(
        id: '2026-03-02',
        date: DateTime(2026, 3, 2),
        type: WorkEntryType.vacation);

    test('saveWorkEntry invalidiert', () async {
      final before = _CountingLeaveViewModel.builds;
      await vm.saveWorkEntry(entry);
      await Future.delayed(Duration.zero);
      expect(_CountingLeaveViewModel.builds, before + 1);
    });

    test('deleteWorkEntry invalidiert', () async {
      final before = _CountingLeaveViewModel.builds;
      await vm.deleteWorkEntry(entry.id);
      await Future.delayed(Duration.zero);
      expect(_CountingLeaveViewModel.builds, before + 1);
    });

    test('saveBatchWorkEntries invalidiert', () async {
      final before = _CountingLeaveViewModel.builds;
      await vm.saveBatchWorkEntries(
          [DateTime(2026, 3, 2), DateTime(2026, 3, 3)],
          WorkEntryType.vacation,
          null,
          null);
      await Future.delayed(Duration.zero);
      expect(_CountingLeaveViewModel.builds, before + 1);
    });
  });
}
