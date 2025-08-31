import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

import '../../data/datasources/local/storage_datasource.dart';
import '../../data/datasources/remote/firestore_datasource.dart';
import '../../data/repositories/overtime_repository_impl.dart';
import '../../data/repositories/work_repository_impl.dart';
import '../../domain/entities/break_entity.dart';
import '../../domain/entities/work_entry_entity.dart';
import '../../domain/repositories/overtime_repository.dart';
import '../../domain/repositories/work_repository.dart';
import '../../domain/usecases/get_today_work_entry.dart';
import '../../domain/usecases/save_work_entry.dart';
import '../../domain/usecases/toggle_break.dart';
import '../../domain/usecases/overtime_usecases.dart';
import '../state/dashboard_state.dart';

// No-Op Repositories
class NoOpWorkRepository implements WorkRepository {
  @override
  Future<WorkEntryEntity> getWorkEntry(DateTime date) async => WorkEntryEntity(
        id: 'no-op',
        date: DateTime.now(),
      );

  @override
  Future<List<WorkEntryEntity>> getWorkEntriesForMonth(
          int year, int month) async =>
      [];

  @override
  Future<void> saveWorkEntry(WorkEntryEntity entry) async {}
}

class NoOpOvertimeRepository implements OvertimeRepository {
  @override
  Duration getOvertime() => Duration.zero;

  @override
  Future<void> saveOvertime(Duration overtime) async {}
}

class NoOpStorageDataSource implements StorageDataSource {
  @override
  ThemeMode getThemeMode() => ThemeMode.system;

  @override
  Future<void> setThemeMode(ThemeMode mode) async {}

  @override
  double getTargetWeeklyHours() => 40.0;

  @override
  Future<void> setTargetWeeklyHours(double hours) async {}

  @override
  Duration getOvertime() => Duration.zero;

  @override
  Future<void> saveOvertime(Duration overtime) async {}
}


// Service Providers
final firebaseAuthProvider =
    Provider<firebase.FirebaseAuth>((ref) => firebase.FirebaseAuth.instance);
final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
final googleSignInProvider =
    Provider<GoogleSignIn>((ref) => GoogleSignIn.instance);
final sharedPreferencesProvider =
    Provider<SharedPreferences>((ref) => throw UnimplementedError());

// Datasource Provider
final firestoreDataSourceProvider = Provider<FirestoreDataSource>((ref) {
  return FirestoreDataSourceImpl(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
    ref.watch(googleSignInProvider),
  );
});

final storageDataSourceProvider = Provider<StorageDataSource>((ref) {
  try {
    return StorageDataSourceImpl(ref.watch(sharedPreferencesProvider));
  } catch (e) {
    // Return a dummy implementation if SharedPreferences fails
    return NoOpStorageDataSource();
  }
});

// Repository Provider
final workRepositoryProvider = Provider<WorkRepository>((ref) {
  final userId = ref.watch(firebaseAuthProvider).currentUser?.uid;
  if (userId == null) {
    return NoOpWorkRepository();
  }
  return WorkRepositoryImpl(
    dataSource: ref.watch(firestoreDataSourceProvider),
    userId: userId,
  );
});

final overtimeRepositoryProvider = Provider<OvertimeRepository>((ref) {
  final userId = ref.watch(firebaseAuthProvider).currentUser?.uid;
  if (userId == null) {
    return NoOpOvertimeRepository();
  }
  return OvertimeRepositoryImpl(ref.watch(storageDataSourceProvider));
});


// Use Case Providers
final getTodayWorkEntryProvider = Provider<GetTodayWorkEntry>(
    (ref) => GetTodayWorkEntry(ref.watch(workRepositoryProvider)));
final saveWorkEntryProvider = Provider<SaveWorkEntry>(
    (ref) => SaveWorkEntry(ref.watch(workRepositoryProvider)));
final toggleBreakProvider =
    Provider<ToggleBreak>((ref) => ToggleBreak(ref.watch(workRepositoryProvider)));
final getOvertimeProvider = Provider<GetOvertime>(
    (ref) => GetOvertime(ref.watch(overtimeRepositoryProvider)));
final updateOvertimeProvider = Provider<UpdateOvertime>(
    (ref) => UpdateOvertime(ref.watch(overtimeRepositoryProvider)));

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
    }

    await _recalculateStateAndSave(updatedEntry);
  }

  Future<void> _recalculateStateAndSave(WorkEntryEntity updatedEntry,
      {bool save = true}) async {
    Duration? newActualWorkDuration;
    if (updatedEntry.workStart != null && updatedEntry.workEnd != null) {
      final breakDuration = updatedEntry.breaks.fold<Duration>(
        Duration.zero,
        (previousValue, element) =>
            previousValue +
            (element.end?.difference(element.start) ?? Duration.zero),
      );
      newActualWorkDuration =
          updatedEntry.workEnd!.difference(updatedEntry.workStart!) -
              breakDuration;
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
    final newStart =
        DateTime(oldDate.year, oldDate.month, oldDate.day, time.hour, time.minute);
    final updatedEntry = state.workEntry.copyWith(workStart: newStart);
    await _recalculateStateAndSave(updatedEntry);
  }

  Future<void> setManualEndTime(TimeOfDay time) async {
    final oldDate =
        state.workEntry.workEnd ?? state.workEntry.workStart ?? DateTime.now();
    final newEnd =
        DateTime(oldDate.year, oldDate.month, oldDate.day, time.hour, time.minute);
    final updatedEntry = state.workEntry.copyWith(workEnd: newEnd);
    await _recalculateStateAndSave(updatedEntry);
  }

  Future<void> startOrStopBreak() async {
    final updatedEntry = await _toggleBreak.call(state.workEntry);
    await _recalculateStateAndSave(updatedEntry);
  }

  Future<void> deleteBreak(String breakId) async {
    final updatedBreaks =
        state.workEntry.breaks.where((b) => b.id != breakId).toList();
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

final dashboardViewModelProvider =
    StateNotifierProvider<DashboardViewModel, DashboardState>((ref) {
  return DashboardViewModel(
    ref.watch(getTodayWorkEntryProvider),
    ref.watch(saveWorkEntryProvider),
    ref.watch(toggleBreakProvider),
    ref.watch(getOvertimeProvider),
    ref.watch(updateOvertimeProvider),
  );
});