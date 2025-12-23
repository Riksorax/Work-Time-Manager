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
      final viewModel = container.read(reportsViewModelProvider.notifier);
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
  });
}
