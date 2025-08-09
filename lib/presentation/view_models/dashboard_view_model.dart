import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/providers.dart';
import '../../domain/entities/break_entity.dart';
import '../../domain/entities/work_entry_entity.dart';
import '../../domain/repositories/work_repository.dart';
import '../../domain/usecases/overtime_usecases.dart';
import '../../domain/usecases/start_or_stop_timer.dart';
import '../state/dashboard_state.dart';

// The provider for the ViewModel.
final dashboardViewModelProvider =
    StateNotifierProvider<DashboardViewModel, DashboardState>((ref) {
  final workRepository = ref.watch(workRepositoryProvider);
  final startOrStopTimerUseCase = ref.watch(startOrStopTimerUseCaseProvider);
  final getOvertimeUseCase = ref.watch(getOvertimeUseCaseProvider);
  final updateOvertimeUseCase = ref.watch(updateOvertimeUseCaseProvider);
  return DashboardViewModel(
    workRepository,
    startOrStopTimerUseCase,
    getOvertimeUseCase,
    updateOvertimeUseCase,
  )..init();
});

class DashboardViewModel extends StateNotifier<DashboardState> {
  final WorkRepository _workRepository;
  final StartOrStopTimer _startOrStopTimer;
  final GetOvertime _getOvertime;
  final UpdateOvertime _updateOvertime;
  Timer? _timer;
  final Uuid _uuid = const Uuid();
  String? _entryId;

  DashboardViewModel(
    this._workRepository,
    this._startOrStopTimer,
    this._getOvertime,
    this._updateOvertime,
  ) : super(DashboardState.initial());

  /// Initializes the ViewModel by loading data.
  Future<void> init() async {
    // Load today's work entry.
    try {
      final todayEntry = await _workRepository.getWorkEntry(DateTime.now());
      _entryId = todayEntry.id;
      final newState = DashboardState.fromWorkEntry(todayEntry);
      // CORRECTED: Removed await as _getOvertime is synchronous.
      final currentOvertime = _getOvertime();
      state = newState.copyWith(
        overtimeBalance: currentOvertime,
        actualWorkDuration: todayEntry.workEnd != null ? todayEntry.effectiveWorkDuration : null,
      );
      _manageUiTimer();
    } catch (e) {
      debugPrint("No work entry for today found: $e");
      // Even if no entry is found, load the overtime balance
      // CORRECTED: Removed await as _getOvertime is synchronous.
      final currentOvertime = _getOvertime();
      state = state.copyWith(overtimeBalance: currentOvertime);
    }
  }

  /// Adjusts the overtime balance by the given amount.
  Future<void> adjustOvertime(Duration amount) async {
    final newBalance = await _updateOvertime(amount: amount);
    state = state.copyWith(overtimeBalance: newBalance);
  }

  Future<void> startOrStopTimer() async {
    final entryToUpdate = state.workEntry.copyWith(
      id: _entryId ?? _uuid.v4(),
      date: state.workEntry.workStart ?? DateTime.now(),
    );

    try {
      final updatedEntry = await _startOrStopTimer(entryToUpdate);

      // When the timer is stopped
      if (updatedEntry.workEnd != null) {
        final actualWorkDuration = updatedEntry.effectiveWorkDuration;
        const dailyGoal = Duration(hours: 8);
        final overtimeDifference = actualWorkDuration - dailyGoal;

        final newOvertimeBalance = await _updateOvertime(amount: overtimeDifference);
        
        state = state.copyWith(
          workEntry: updatedEntry,
          elapsedTime: actualWorkDuration,
          overtimeBalance: newOvertimeBalance,
          actualWorkDuration: actualWorkDuration,
        );
      } else {
        // When the timer is started
        final newState = DashboardState.fromWorkEntry(updatedEntry);
        state = newState.copyWith(
          overtimeBalance: state.overtimeBalance,
          actualWorkDuration: null,
        );
      }
      _entryId = updatedEntry.id;
      _manageUiTimer();
    } catch (e) {
      debugPrint("Error starting or stopping timer: $e");
    }
  }

  void startOrStopBreak() {
    final now = DateTime.now();
    final runningBreak = state.workEntry.breaks.where((b) => b.end == null).firstOrNull;

    WorkEntryEntity updatedEntry;
    if (runningBreak != null) {
      final updatedBreaks = state.workEntry.breaks
          .map((b) => b.id == runningBreak.id ? b.copyWith(end: now) : b)
          .toList();
      updatedEntry = state.workEntry.copyWith(breaks: updatedBreaks);
    } else {
      final newBreak = BreakEntity(
        id: _uuid.v4(),
        name: 'Pause #${state.workEntry.breaks.length + 1}',
        start: now,
      );
      updatedEntry = state.workEntry.copyWith(breaks: [...state.workEntry.breaks, newBreak]);
    }
    state = state.copyWith(workEntry: updatedEntry);
    _saveWorkEntry();
  }

  void updateBreak({
    required String breakId,
    String? newName,
    DateTime? newStart,
    DateTime? newEnd,
  }) {
    final updatedBreaks = state.workEntry.breaks.map((b) {
      if (b.id == breakId) {
        return b.copyWith(
          name: newName ?? b.name,
          start: newStart ?? b.start,
          end: newEnd,
        );
      }
      return b;
    }).toList();
    state = state.copyWith(workEntry: state.workEntry.copyWith(breaks: updatedBreaks));
    _saveWorkEntry();
  }

  void deleteBreak(String breakId) {
    final updatedBreaks =
        state.workEntry.breaks.where((b) => b.id != breakId).toList();
    state = state.copyWith(workEntry: state.workEntry.copyWith(breaks: updatedBreaks));
    _saveWorkEntry();
  }

  void setManualStartTime(TimeOfDay time) {
    final now = DateTime.now();
    final manualStartTime =
        DateTime(now.year, now.month, now.day, time.hour, time.minute);
    state = state.copyWith(workEntry: state.workEntry.copyWith(workStart: manualStartTime));
    _saveWorkEntry();
  }

  void setManualEndTime(TimeOfDay time) {
    final now = state.workEntry.workEnd ?? DateTime.now();
    final manualEndTime =
        DateTime(now.year, now.month, now.day, time.hour, time.minute);
    state = state.copyWith(workEntry: state.workEntry.copyWith(workEnd: manualEndTime));
    _saveWorkEntry();
  }

  void _updateElapsedTime() {
    if (state.workEntry.workStart != null && state.workEntry.workEnd == null) {
      final elapsed = DateTime.now().difference(state.workEntry.workStart!);
      // CORRECTED: Used the correct property 'totalBreakTime' from the WorkEntryEntity.
      final totalElapsed = elapsed - state.workEntry.totalBreakTime;
      state = state.copyWith(elapsedTime: totalElapsed);
    }
  }

  void _manageUiTimer() {
    _timer?.cancel();
    if (state.workEntry.workStart != null && state.workEntry.workEnd == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _updateElapsedTime();
      });
    }
  }

  Future<void> _saveWorkEntry() async {
    final workEntry = state.workEntry;
    if (workEntry.workStart == null) return;

    final entryId = _entryId ?? _uuid.v4();
    _entryId = entryId;

    final entry = workEntry.copyWith(id: entryId);
    try {
      await _workRepository.saveWorkEntry(entry);
    } catch (e) {
      debugPrint("Error saving work entry: $e");
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
