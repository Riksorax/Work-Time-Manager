import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/providers.dart';
import '../../domain/entities/break_entity.dart';
import '../../domain/entities/work_entry_entity.dart';
import '../../domain/repositories/work_repository.dart';
import '../state/dashboard_state.dart';
import '../../data/repositories/work_repository_impl.dart';

// Provider that exposes the current authentication state stream.
final authStateProvider = StreamProvider((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return authRepository.authStateChanges;
});

// Provider to asynchronously provide the WorkRepository.
// It depends on the user's authentication state.
final workRepositoryProvider = FutureProvider<WorkRepository>((ref) async {
  // Wait for the auth state to be available and be a non-null user
  final user = await ref.watch(authStateProvider.future);

  if (user == null) {
    // If the user is not logged in, we throw an exception.
    // The UI should handle this state and not try to show the dashboard.
    throw Exception('User is not logged in');
  }

  // We get the Firestore data source and return the implementation of the WorkRepository.
  final firestoreDataSource = ref.watch(firestoreDataSourceProvider);
  return WorkRepositoryImpl(dataSource: firestoreDataSource, userId: user.id);
});

// The provider for the ViewModel.
// It now handles the asynchronous loading of its WorkRepository dependency.
final dashboardViewModelProvider =
    StateNotifierProvider.autoDispose<DashboardViewModel, DashboardState>((ref) {
  // Watch the asynchronous workRepositoryProvider.
  final workRepositoryAsync = ref.watch(workRepositoryProvider);

  // We can only create the ViewModel when the repository is successfully loaded.
  // The UI should show a loading or error state based on the `workRepositoryProvider`.
  final workRepository = workRepositoryAsync.asData?.value;

  // If the repository is not loaded yet, we return an initial (empty) ViewModel.
  // The UI should prevent any actions until the repository is ready.
  if (workRepository == null) {
    // This is a temporary state until the FutureProvider resolves.
    // The ViewModel requires a non-null repository.
    // A better approach is for the UI to handle the loading state of workRepositoryProvider.
    // For now, we create a dummy repository that will be replaced.
    return DashboardViewModel(const DummyWorkRepository());
  }

  // Once the repository is available, we create the real ViewModel and initialize it.
  return DashboardViewModel(workRepository)..init();
});


class DashboardViewModel extends StateNotifier<DashboardState> {
  final WorkRepository _workRepository;
  Timer? _timer;
  final Uuid _uuid = const Uuid();
  String? _entryId;

  DashboardViewModel(this._workRepository) : super(DashboardState.initial());

  /// Initializes the ViewModel by loading the work entry for the current day.
  Future<void> init() async {
    // Prevent initialization with the dummy repository
    if (_workRepository is DummyWorkRepository) return;

    try {
      final todayEntry = await _workRepository.getWorkEntry(DateTime.now());
      _entryId = todayEntry.id; // Store the ID for future updates
      state = DashboardState.fromWorkEntry(todayEntry);
      // If the timer was running when the app was closed, we restart the timer.
      if (state.isTimerRunning) {
        _startTimer(resume: true);
      }
    } catch (e) {
      // If no entry is found for today, getWorkEntry will throw an error.
      // We can ignore it and just start with a fresh state.
      debugPrint("No work entry for today found: $e");
    }
  }

  void startOrStopTimer() {
    if (state.isTimerRunning) {
      _stopTimer();
    } else {
      _startTimer();
    }
  }

  void _startTimer({bool resume = false}) {
    // If we are not resuming, we set the start time.
    // If a manual start time is set, we use it. Otherwise, we use the current time.
    final startTime = resume ? state.startTime! : (state.manualStartTime ?? DateTime.now());

    state = state.copyWith(
      isTimerRunning: true,
      startTime: startTime,
      manualEndTime: () => null, // Reset end time on start
    );
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateElapsedTime();
    });
    // We save the current state to the repository.
    _saveWorkEntry();
  }

  void _stopTimer() {
    _timer?.cancel();
    state = state.copyWith(
        isTimerRunning: false, manualEndTime: () => DateTime.now());
    _saveWorkEntry();
  }

  void startOrStopBreak() {
    final now = DateTime.now();
    // We check if there is a break that has a start time but no end time.
    final runningBreak =
        state.breaks.where((b) => b.end == null).firstOrNull;

    if (runningBreak != null) {
      // If a break is running, we stop it by setting its end time.
      final updatedBreaks = state.breaks
          .map((b) => b.id == runningBreak.id ? b.copyWith(end: now) : b)
          .toList();
      state = state.copyWith(breaks: updatedBreaks);
    } else {
      // If no break is running, we start a new one.
      final newBreak = BreakEntity(
        id: _uuid.v4(),
        name: 'Pause #${state.breaks.length + 1}',
        start: now,
      );
      state = state.copyWith(breaks: [...state.breaks, newBreak]);
    }
    _saveWorkEntry();
  }

  void updateBreak({
    required String breakId,
    String? newName,
    DateTime? newStart,
    DateTime? newEnd,
  }) {
    final updatedBreaks = state.breaks.map((b) {
      if (b.id == breakId) {
        return b.copyWith(
          name: newName ?? b.name,
          start: newStart ?? b.start,
          end: newEnd, // Allow setting end to null
        );
      }
      return b;
    }).toList();
    state = state.copyWith(breaks: updatedBreaks);
    _saveWorkEntry();
  }

  void deleteBreak(String breakId) {
    final updatedBreaks =
        state.breaks.where((b) => b.id != breakId).toList();
    state = state.copyWith(breaks: updatedBreaks);
    _saveWorkEntry();
  }

  void setManualStartTime(TimeOfDay time) {
    final now = DateTime.now();
    final manualStartTime =
        DateTime(now.year, now.month, now.day, time.hour, time.minute);
    state = state.copyWith(manualStartTime: manualStartTime);
    // We don't save here, the user has to press start.
  }

  /// Adds a manual adjustment for overtime or undertime.
  void addAdjustment({required int hours, required int minutes}) {
    final totalMinutes = hours * 60 + (hours.isNegative ? -minutes : minutes);
    state = state.copyWith(manualAdjustmentMinutes: totalMinutes);
    _saveWorkEntry();
  }

  void _updateElapsedTime() {
    if (!state.isTimerRunning || state.startTime == null) return;

    final now = DateTime.now();
    final totalDuration = now.difference(state.startTime!);

    final breakDuration = state.breaks.fold<Duration>(
      Duration.zero,
      (previousValue, breakEntity) {
        // If the break has an end time, we calculate the duration.
        if (breakEntity.end != null) {
          return previousValue +
              breakEntity.end!.difference(breakEntity.start);
        } else {
          // If the break is still running, we calculate the duration until now.
          return previousValue + now.difference(breakEntity.start);
        }
      },
    );

    final netDuration = totalDuration - breakDuration;
    state = state.copyWith(elapsedTime: netDuration);
  }

  /// Saves the current state as a WorkEntryEntity to the repository.
  Future<void> _saveWorkEntry() async {
    // We need a start time to save an entry.
    // If the timer is not running and there is no manual start time, we can't save.
    final startTime = state.startTime ?? state.manualStartTime;
    if (startTime == null) return;

    final entryId = _entryId ?? _uuid.v4();
    _entryId = entryId;

    final entry = WorkEntryEntity(
      id: entryId,
      date: startTime,
      workStart: startTime,
      // If the timer is not running, we use the manual end time.
      workEnd: state.isTimerRunning ? null : state.manualEndTime,
      breaks: state.breaks,
      manualOvertime: state.manualAdjustmentMinutes != null
          ? Duration(minutes: state.manualAdjustmentMinutes!)
          : null,
    );
    try {
      await _workRepository.saveWorkEntry(entry);
    } catch (e) {
      debugPrint("Error saving work entry: $e");
      // Here you could show a snackbar or some other error indication to the user
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// A dummy implementation of WorkRepository to satisfy the ViewModel's constructor
/// while the real repository is loading.
class DummyWorkRepository implements WorkRepository {
  const DummyWorkRepository();

  @override
  Future<WorkEntryEntity> getWorkEntry(DateTime date) async {
    throw UnimplementedError();
  }

  @override
  Future<List<WorkEntryEntity>> getWorkEntriesForMonth(int year, int month) async {
    throw UnimplementedError();
  }

  @override
  Future<void> saveWorkEntry(WorkEntryEntity entry) async {
    throw UnimplementedError();
  }
}
