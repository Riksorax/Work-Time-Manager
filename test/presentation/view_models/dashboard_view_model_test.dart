import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/repositories/overtime_repository.dart';
import 'package:flutter_work_time/domain/repositories/settings_repository.dart';
import 'package:flutter_work_time/domain/usecases/get_today_work_entry.dart';
import 'package:flutter_work_time/domain/usecases/get_today_work_entry.dart';
import 'package:flutter_work_time/domain/usecases/overtime_usecases.dart';
import 'package:flutter_work_time/domain/usecases/save_work_entry.dart';
import 'package:flutter_work_time/presentation/view_models/dashboard_view_model.dart';

import 'dashboard_view_model_test.mocks.dart';

@GenerateMocks([
  GetTodayWorkEntry,
  GetOvertime,
  SettingsRepository,
  SaveWorkEntry,
  OvertimeRepository,
])
void main() {
  late MockGetTodayWorkEntry mockGetTodayWorkEntry;
  late MockGetOvertime mockGetOvertime;
  late MockSettingsRepository mockSettingsRepository;
  late MockSaveWorkEntry mockSaveWorkEntry;
  late MockOvertimeRepository mockOvertimeRepository;
  late ProviderContainer container;

  setUp(() {
    mockGetTodayWorkEntry = MockGetTodayWorkEntry();
    mockGetOvertime = MockGetOvertime();
    mockSettingsRepository = MockSettingsRepository();
    mockSaveWorkEntry = MockSaveWorkEntry();
    mockOvertimeRepository = MockOvertimeRepository();

    container = ProviderContainer(
      overrides: [
        getTodayWorkEntryUseCaseProvider.overrideWithValue(mockGetTodayWorkEntry),
        getOvertimeUseCaseProvider.overrideWithValue(mockGetOvertime),
        settingsRepositoryProvider.overrideWithValue(mockSettingsRepository),
        saveWorkEntryUseCaseProvider.overrideWithValue(mockSaveWorkEntry),
        overtimeRepositoryProvider.overrideWithValue(mockOvertimeRepository),
      ],
    );

    // Default Stubs
    when(mockSettingsRepository.getWorkdaysPerWeek()).thenReturn(5);
    when(mockSettingsRepository.getTargetWeeklyHours()).thenReturn(40.0);
    when(mockOvertimeRepository.getOvertime()).thenReturn(Duration.zero);
    when(mockOvertimeRepository.getLastUpdateDate()).thenReturn(null);
    when(mockGetOvertime()).thenReturn(Duration.zero);
  });

  tearDown(() {
    container.dispose();
  });

  group('DashboardViewModel', () {
    test('expectedEndTime should be calculated correctly (8h work + 30m break)', () async {
      // Arrange
      // Start time: 8:00 AM today
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day, 8, 0);
      
      final entry = WorkEntryEntity(
        id: '1',
        date: now,
        workStart: todayStart,
        workEnd: null, // Running
      );

      when(mockGetTodayWorkEntry()).thenAnswer((_) async => entry);

      // Act
      final viewModel = container.read(dashboardViewModelProvider.notifier);
      // Wait for init
      await Future.delayed(Duration.zero);
      
      // Wait for 1 tick of timer? Recalculation happens in _init too.
      // _startTimerIfNeeded -> _recalculateOvertime
      
      final state = container.read(dashboardViewModelProvider);

      // Assert
      // Target = 8h.
      // 8:00 + 8h = 16:00.
      // Gross duration 8h >= 6h -> +30m break.
      // Expected End = 16:30.
      
      expect(state.expectedEndTime, isNotNull);
      
      final expected = DateTime(now.year, now.month, now.day, 16, 30);
      // Allow slight difference if DateTime.now affects things? 
      // The calculation relies on 'start' and 'target', and 'currentBreaks'.
      // If 'currentBreaks' is 0 (no breaks in entry), result should be stable.
      
      expect(state.expectedEndTime!.hour, expected.hour);
      expect(state.expectedEndTime!.minute, expected.minute);
    });

    test('expectedEndTime should account for long day (9h work + 45m break)', () async {
      // Arrange
      // Set target hours to 9.5h per day?
      // Or just check if logic handles it.
      // Let's change target weekly hours to 47.5 (9.5 * 5)
      when(mockSettingsRepository.getTargetWeeklyHours()).thenReturn(47.5);

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day, 8, 0);
      
      final entry = WorkEntryEntity(
        id: '1',
        date: now,
        workStart: todayStart,
        workEnd: null,
      );

      when(mockGetTodayWorkEntry()).thenAnswer((_) async => entry);

      final viewModel = container.read(dashboardViewModelProvider.notifier);
      await Future.delayed(Duration.zero);
      
      final state = container.read(dashboardViewModelProvider);

      // Target = 9.5h.
      // 8:00 + 9.5h = 17:30.
      // Gross 9.5h > 9h -> +45m break.
      // Expected End = 17:30 + 45m = 18:15.
      
      expect(state.expectedEndTime!.hour, 18);
      expect(state.expectedEndTime!.minute, 15);
    });
  });
}
