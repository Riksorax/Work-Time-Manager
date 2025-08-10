import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/break_entity.dart';
import '../../domain/entities/work_entry_entity.dart';
import '../../domain/usecases/get_today_work_entry.dart';
import '../../domain/usecases/save_work_entry.dart';
import '../../domain/usecases/toggle_break.dart';
import '../../domain/usecases/overtime_usecases.dart';
import '../state/dashboard_state.dart';

// Annahme: Die Provider sind in den Use-Case-Dateien definiert.
// Wenn nicht, muss dies an anderer Stelle im Code existieren.
final getTodayWorkEntryProvider = Provider<GetTodayWorkEntry>((ref) => throw UnimplementedError());
final saveWorkEntryProvider = Provider<SaveWorkEntry>((ref) => throw UnimplementedError());
final toggleBreakProvider = Provider<ToggleBreak>((ref) => throw UnimplementedError());
final getOvertimeProvider = Provider<GetOvertime>((ref) => throw UnimplementedError());
final updateOvertimeProvider = Provider<UpdateOvertime>((ref) => throw UnimplementedError());


class DashboardViewModel extends StateNotifier<DashboardState> {
  final GetTodayWorkEntry _getTodayWorkEntry;
  final SaveWorkEntry _saveWorkEntry;
  final ToggleBreak _toggleBreak;
  final GetOvertime _getOvertime;
  final UpdateOvertime _updateOvertime;

  Timer? _timer;

  DashboardViewModel(
    this._getTodayWorkEntry,
    this._saveWorkEntry,
    this._toggleBreak,
    this._getOvertime,
    this._updateOvertime,
  ) : super(DashboardState.initial()) {
    _init();
  }

  Future<void> _init() async {
    final workEntry = await _getTodayWorkEntry.call();
    final overtimeBalance = _getOvertime.call();
    state = state.copyWith(
      workEntry: workEntry,
      isLoading: false,
      overtimeBalance: overtimeBalance,
    );
    _recalculateStateAndSave(workEntry, save: false);
    _startTimerIfNeeded();
  }

  void _startTimerIfNeeded() {
    _timer?.cancel();
    if (state.workEntry.workStart != null && state.workEntry.workEnd == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        state = state.copyWith(elapsedTime: _calculateElapsedTime());
      });
    }
  }

  Duration _calculateElapsedTime() {
    if (state.workEntry.workStart == null) return Duration.zero;
    final now = DateTime.now();
    final breakDuration = _calculateTotalBreakDuration(now);
    return now.difference(state.workEntry.workStart!) - breakDuration;
  }

  Duration _calculateTotalBreakDuration(DateTime now) {
    return state.workEntry.breaks.fold(Duration.zero, (prev, b) {
      if (b.start.isAfter(now)) return prev;
      final end = b.end ?? now;
      return prev + end.difference(b.start);
    });
  }

  Future<void> startOrStopTimer() async {
    final now = DateTime.now();
    WorkEntryEntity updatedEntry;

    if (state.workEntry.workStart == null) {
      // START
      updatedEntry = state.workEntry.copyWith(workStart: now);
    } else {
      // STOP
      _timer?.cancel();
      updatedEntry = state.workEntry.copyWith(workEnd: now);
      // Hinweis: Die Überstundenlogik, die im alten Kommentar erwähnt wurde, fehlt noch.
      // Dies wäre der richtige Ort, um sie zu berechnen und zu aktualisieren, wenn die tägliche Arbeitszeit verfügbar wäre.
    }
    
    // Berechnet die Dauern neu, aktualisiert den Status und speichert
    await _recalculateStateAndSave(updatedEntry);
  }
  
  Future<void> _recalculateStateAndSave(WorkEntryEntity updatedEntry, {bool save = true}) async {
    Duration? newActualWorkDuration;
    if (updatedEntry.workStart != null && updatedEntry.workEnd != null) {
      final breakDuration = updatedEntry.breaks.fold<Duration>(
        Duration.zero,
        (previousValue, element) => previousValue + (element.end?.difference(element.start) ?? Duration.zero),
      );
      newActualWorkDuration = updatedEntry.workEnd!.difference(updatedEntry.workStart!) - breakDuration;
    }

    state = state.copyWith(
      workEntry: updatedEntry,
      actualWorkDuration: newActualWorkDuration,
    );

    if (save) {
      await _saveWorkEntry.call(updatedEntry);
    }
    _startTimerIfNeeded();
  }

  Future<void> setManualStartTime(TimeOfDay time) async {
    final oldDate = state.workEntry.workStart ?? DateTime.now();
    final newStart = DateTime(oldDate.year, oldDate.month, oldDate.day, time.hour, time.minute);
    final updatedEntry = state.workEntry.copyWith(workStart: newStart);
    await _recalculateStateAndSave(updatedEntry);
  }

  Future<void> setManualEndTime(TimeOfDay time) async {
    final oldDate = state.workEntry.workEnd ?? state.workEntry.workStart ?? DateTime.now();
    final newEnd = DateTime(oldDate.year, oldDate.month, oldDate.day, time.hour, time.minute);
    final updatedEntry = state.workEntry.copyWith(workEnd: newEnd);
    await _recalculateStateAndSave(updatedEntry);
  }

  Future<void> startOrStopBreak() async {
    final updatedEntry = await _toggleBreak.call(state.workEntry);
    await _recalculateStateAndSave(updatedEntry);
  }

  Future<void> deleteBreak(String breakId) async {
    final updatedBreaks = state.workEntry.breaks.where((b) => b.id != breakId).toList();
    final updatedEntry = state.workEntry.copyWith(breaks: updatedBreaks);
    await _recalculateStateAndSave(updatedEntry);
  }

  Future<void> updateBreak(BreakEntity breakEntity) async {
    final updatedBreaks = state.workEntry.breaks.map((b) {
      return b.id == breakEntity.id ? breakEntity : b;
    }).toList();
    final updatedEntry = state.workEntry.copyWith(breaks: updatedBreaks);
    await _recalculateStateAndSave(updatedEntry);
  }

  Future<void> addAdjustment(Duration adjustment) async {
    final newOvertime = await _updateOvertime.call(amount: adjustment);
    state = state.copyWith(overtimeBalance: newOvertime);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final dashboardViewModelProvider = StateNotifierProvider<DashboardViewModel, DashboardState>((ref) {
  return DashboardViewModel(
    ref.watch(getTodayWorkEntryProvider),
    ref.watch(saveWorkEntryProvider),
    ref.watch(toggleBreakProvider),
    ref.watch(getOvertimeProvider),
    ref.watch(updateOvertimeProvider),
  );
});
