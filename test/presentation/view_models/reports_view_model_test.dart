import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/repositories/settings_repository.dart';
import 'package:flutter_work_time/domain/repositories/work_repository.dart';
import 'package:flutter_work_time/presentation/view_models/reports_view_model.dart';

import 'reports_view_model_test.mocks.dart';

@GenerateMocks([WorkRepository, SettingsRepository])
void main() {
  late MockWorkRepository mockWorkRepository;
  late MockSettingsRepository mockSettingsRepository;
  late ProviderContainer container;

  setUp(() {
    mockWorkRepository = MockWorkRepository();
    mockSettingsRepository = MockSettingsRepository();
    container = ProviderContainer(
      overrides: [
        workRepositoryProvider.overrideWithValue(mockWorkRepository),
        settingsRepositoryProvider.overrideWithValue(mockSettingsRepository),
      ],
    );

    // Default Stubs
    when(mockSettingsRepository.getWorkdaysPerWeek()).thenReturn(5);
    when(mockSettingsRepository.getTargetWeeklyHours()).thenReturn(40.0);
    
    // Stub for initial load (current date)
    final now = DateTime.now();
    when(mockWorkRepository.getWorkEntriesForMonth(now.year, now.month))
        .thenAnswer((_) async => []);
  });

  tearDown(() {
    container.dispose();
  });

  group('ReportsViewModel', () {
    test('initial state should be loading and then populated', () async {
      // Arrange
      final now = DateTime.now();
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
      verify(mockWorkRepository.getWorkEntriesForMonth(now.year, now.month)).called(1);
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
      
      when(mockSettingsRepository.getWorkdaysPerWeek()).thenReturn(5);
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

      expect(state.weeklyReportState.totalNetWorkDuration, const Duration(hours: 12));
      expect(state.weeklyReportState.workDays, 2);
      expect(state.weeklyReportState.overtime, const Duration(hours: -4));
    });

    test('weekly report should cap target at weekly hours when extra days worked', () async {
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

      when(mockSettingsRepository.getWorkdaysPerWeek()).thenReturn(5);
      when(mockSettingsRepository.getTargetWeeklyHours()).thenReturn(40.0);
      // Ohne Fix: Soll = 8h * 6 Tage = 48h, Ist = 46h, Overtime = -2h (FALSCH)
      // Mit Fix:  Soll = 8h * 5 Tage = 40h (gedeckelt), Ist = 46h, Overtime = +6h (RICHTIG)

      final viewModel = container.read(reportsViewModelProvider.notifier);

      await Future.delayed(Duration.zero);

      viewModel.selectDate(date);

      await Future.delayed(Duration.zero);

      final state = container.read(reportsViewModelProvider);

      expect(state.weeklyReportState.totalNetWorkDuration, const Duration(hours: 46));
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
      final mondayTarget = viewModel.getEffectiveDailyTargetForDate(DateTime(2023, 10, 23));
      expect(mondayTarget, const Duration(hours: 8));
    });

    group('Multi-Select Mode', () {
      test('toggleMultiSelectMode should toggle the mode and clear selection', () async {
        final now = DateTime.now();
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
        final now = DateTime.now();
        when(mockWorkRepository.getWorkEntriesForMonth(now.year, now.month))
            .thenAnswer((_) async => []);

        final viewModel = container.read(reportsViewModelProvider.notifier);
        await Future.delayed(Duration.zero);

        final pastDate = DateTime.now().subtract(const Duration(days: 5));
        final futureDate = DateTime.now().add(const Duration(days: 5));

        viewModel.addDateToSelection(pastDate);
        expect(viewModel.state.selectedDates.length, 1);

        viewModel.addDateToSelection(futureDate);
        expect(viewModel.state.selectedDates.length, 2); // Future dates are now allowed
      });

      test('toggleDateSelection should add/remove dates', () async {
        final now = DateTime.now();
        when(mockWorkRepository.getWorkEntriesForMonth(now.year, now.month))
            .thenAnswer((_) async => []);

        final viewModel = container.read(reportsViewModelProvider.notifier);
        await Future.delayed(Duration.zero);

        final testDate = DateTime.now().subtract(const Duration(days: 3));

        viewModel.toggleDateSelection(testDate);
        expect(viewModel.state.selectedDates, contains(DateTime(testDate.year, testDate.month, testDate.day)));

        viewModel.toggleDateSelection(testDate);
        expect(viewModel.state.selectedDates, isEmpty);
      });

      test('clearDateSelection should empty selected dates', () async {
        final now = DateTime.now();
        when(mockWorkRepository.getWorkEntriesForMonth(now.year, now.month))
            .thenAnswer((_) async => []);

        final viewModel = container.read(reportsViewModelProvider.notifier);
        await Future.delayed(Duration.zero);

        final date1 = DateTime.now().subtract(const Duration(days: 1));
        final date2 = DateTime.now().subtract(const Duration(days: 2));

        viewModel.addDateToSelection(date1);
        viewModel.addDateToSelection(date2);
        expect(viewModel.state.selectedDates.length, 2);

        viewModel.clearDateSelection();
        expect(viewModel.state.selectedDates, isEmpty);
      });

      test('saveBatchWorkEntries should create entries for all selected dates', () async {
        final now = DateTime.now();
        when(mockWorkRepository.getWorkEntriesForMonth(now.year, now.month))
            .thenAnswer((_) async => []);

        when(mockWorkRepository.saveWorkEntry(any))
            .thenAnswer((_) async => {});

        final viewModel = container.read(reportsViewModelProvider.notifier);
        await Future.delayed(Duration.zero);

        final dates = [
          DateTime.now().subtract(const Duration(days: 3)),
          DateTime.now().subtract(const Duration(days: 2)),
          DateTime.now().subtract(const Duration(days: 1)),
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
  });
}
