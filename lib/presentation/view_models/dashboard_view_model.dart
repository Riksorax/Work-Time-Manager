import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';

import '../../core/providers/providers.dart';
import '../../data/datasources/remote/firestore_datasource.dart';
import '../../data/repositories/overtime_repository_impl.dart';
import '../../data/repositories/local_overtime_repository_impl.dart';
import '../../data/repositories/hybrid_overtime_repository_impl.dart';
import '../../data/repositories/work_repository_impl.dart';
import '../../data/repositories/local_work_repository_impl.dart';
import '../../data/repositories/hybrid_work_repository_impl.dart';
import '../../domain/entities/break_entity.dart';
import '../../domain/entities/work_entry_entity.dart';
import '../../domain/repositories/overtime_repository.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/repositories/work_repository.dart';
import '../../domain/services/break_calculator_service.dart';
import '../../domain/usecases/get_today_work_entry.dart';
import '../../domain/usecases/save_work_entry.dart';
import '../../domain/usecases/toggle_break.dart';
import '../../domain/usecases/overtime_usecases.dart';
import '../state/dashboard_state.dart';
import 'auth_view_model.dart' show authStateProvider;

// Service Providers
final firebaseAuthProvider =
    Provider<firebase.FirebaseAuth>((ref) => firebase.FirebaseAuth.instance);
final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
final googleSignInProvider =
    Provider<GoogleSignIn>((ref) => GoogleSignIn.instance);

// Datasource Provider
final firestoreDataSourceProvider = Provider<FirestoreDataSource>((ref) {
  return FirestoreDataSourceImpl(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
    ref.watch(googleSignInProvider),
  );
});

// Repository Provider mit automatischem Fallback (Firebase ↔ Local)
final workRepositoryProvider = Provider<WorkRepository>((ref) {
  // Beobachte den Auth-Status für automatisches Umschalten
  final authState = ref.watch(authStateProvider);
  final userId = authState.asData?.value?.id;
  final prefs = ref.watch(sharedPreferencesProvider);

  print('[workRepositoryProvider] Auth State geändert - userId: $userId');

  // Erstelle Local Repository (funktioniert immer)
  final localRepository = LocalWorkRepositoryImpl(prefs);

  // Erstelle Firebase Repository (nur wenn eingeloggt)
  final firebaseRepository = userId != null
      ? WorkRepositoryImpl(
          dataSource: ref.watch(firestoreDataSourceProvider),
          userId: userId,
        )
      : localRepository; // Fallback zu Local

  // Gib Hybrid Repository zurück
  return HybridWorkRepositoryImpl(
    firebaseRepository: firebaseRepository,
    localRepository: localRepository,
    userId: userId,
  );
});

final overtimeRepositoryProvider = Provider<OvertimeRepository>((ref) {
  // Beobachte den Auth-Status für automatisches Umschalten
  final authState = ref.watch(authStateProvider);
  final userId = authState.asData?.value?.id;
  final prefs = ref.watch(sharedPreferencesProvider);

  print('[overtimeRepositoryProvider] Auth State geändert - userId: $userId');

  // Erstelle Local Repository (funktioniert immer)
  final localRepository = LocalOvertimeRepositoryImpl(prefs);

  // Erstelle Firebase Repository (nur wenn eingeloggt)
  final firebaseRepository = userId != null
      ? OvertimeRepositoryImpl(prefs, userId)
      : localRepository; // Fallback zu Local

  // Gib Hybrid Repository zurück
  return HybridOvertimeRepositoryImpl(
    firebaseRepository: firebaseRepository,
    localRepository: localRepository,
    userId: userId,
  );
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
final setOvertimeProvider = Provider<SetOvertime>(
    (ref) => SetOvertime(ref.watch(overtimeRepositoryProvider)));

class DashboardViewModel extends StateNotifier<DashboardState> {
  final GetTodayWorkEntry _getTodayWorkEntry;
  final SaveWorkEntry _saveWorkEntry;
  final ToggleBreak _toggleBreak;
  final GetOvertime _getOvertime;
  final SetOvertime _setOvertime;
  final SettingsRepository _settingsRepository;

  Timer? _timer;
  Timer? _autoSaveTimer;
  int _tickCounter = 0;

  DashboardViewModel(
    this._getTodayWorkEntry,
    this._saveWorkEntry,
    this._toggleBreak,
    this._getOvertime,
    this._setOvertime,
    this._settingsRepository,
  ) : super(DashboardState.initial()) {
    _init();
  }

  Future<void> _init() async {
    print('[Dashboard] Initialisiere Dashboard...');
    final workEntry = await _getTodayWorkEntry.call();
    final overtime = await _getOvertime.call();
    print('[Dashboard] Geladener WorkEntry - Start: ${workEntry.workStart}, End: ${workEntry.workEnd}');
    state = state.copyWith(
      workEntry: workEntry,
      isLoading: false,
      overtime: overtime,
    );
    _recalculateStateAndSave(workEntry, save: false);
    _startTimerIfNeeded();
  }

  void updateOvertimeFromSettings(Duration newOvertime) {
    state = state.copyWith(overtime: newOvertime);
  }

  /// Berechnet die Überstunden neu, wenn sich die Einstellungen (Sollstunden/Arbeitstage) ändern
  void recalculateOvertimeFromSettings() {
    print('[Dashboard] Neuberechnung nach Einstellungsänderung');

    // Wenn kein abgeschlossener Eintrag vorhanden ist, nichts zu tun
    if (state.workEntry.workStart == null || state.workEntry.workEnd == null) {
      // Aber laufende Überstunden neu berechnen, falls Timer läuft
      if (state.workEntry.workStart != null) {
        _recalculateOvertime();
      }
      return;
    }

    // Berechne Überstunden mit neuen Einstellungen neu
    final breakDuration = state.workEntry.breaks.fold<Duration>(
      Duration.zero,
      (previousValue, element) => previousValue + (element.end?.difference(element.start) ?? Duration.zero),
    );
    final actualWorkDuration = state.workEntry.workEnd!.difference(state.workEntry.workStart!) - breakDuration;

    final workdaysPerWeek = _settingsRepository.getWorkdaysPerWeek();
    final targetDailyHours = Duration(microseconds: (_settingsRepository.getTargetWeeklyHours() / workdaysPerWeek * Duration.microsecondsPerHour).round());
    final newDailyOvertime = actualWorkDuration - targetDailyHours;

    print('[Dashboard] Neue tägliche Überstunden: ${newDailyOvertime.inMinutes} Min (war: ${state.dailyOvertime?.inMinutes ?? 0} Min)');

    // Aktualisiere den State mit den neuen Überstunden
    state = state.copyWith(
      actualWorkDuration: actualWorkDuration,
      dailyOvertime: newDailyOvertime,
    );
  }

  void _startTimerIfNeeded() {
    _timer?.cancel();
    _autoSaveTimer?.cancel();
    if (state.workEntry.workStart != null && state.workEntry.workEnd == null) {
      _tickCounter = 0;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        final elapsedTime = _calculateElapsedTime();
        state = state.copyWith(elapsedTime: elapsedTime);
        _recalculateOvertime();

        // Auto-Save alle 30 Sekunden
        _tickCounter++;
        if (_tickCounter >= 30) {
          _tickCounter = 0;
          _autoSave();
        }
      });
    }
  }

  Future<void> _autoSave() async {
    // Nur speichern, wenn tatsächlich eine Zeiterfassung läuft
    if (state.workEntry.workStart == null) {
      print('[Dashboard] Auto-Save übersprungen: Keine Zeiterfassung aktiv');
      return;
    }

    print('[Dashboard] Auto-Save: Speichere aktuellen Stand');
    try {
      await _saveWorkEntry.call(state.workEntry);
      print('[Dashboard] Auto-Save erfolgreich');
    } catch (e) {
      print('[Dashboard] Auto-Save Fehler: $e');
    }
  }

  void _updateElapsedTime() {
    if (state.workEntry.workStart == null) {
      state = state.copyWith(elapsedTime: Duration.zero);
      return;
    }

    final endTime = state.workEntry.workEnd ?? DateTime.now();
    final totalDuration = endTime.difference(state.workEntry.workStart!);

    // Pausen berücksichtigen
    Duration breakDuration = Duration.zero;
    for (final breakItem in state.workEntry.breaks) {
      final breakEnd = breakItem.end ?? DateTime.now();
      breakDuration += breakEnd.difference(breakItem.start);
    }

    final actualDuration = totalDuration - breakDuration;
    state = state.copyWith(elapsedTime: actualDuration);
  }

  Duration _calculateElapsedTime() {
    if (state.workEntry.workStart == null) return Duration.zero;
    final now = DateTime.now();
    final breakDuration = _calculateTotalBreakDuration(now);
    return now.difference(state.workEntry.workStart!) - breakDuration;
  }

  void _recalculateOvertime() {
    if (state.workEntry.workStart == null) return;

    final workdaysPerWeek = _settingsRepository.getWorkdaysPerWeek();
    final targetDailyHours = Duration(microseconds: (_settingsRepository.getTargetWeeklyHours() / workdaysPerWeek * Duration.microsecondsPerHour).round());
    final dailyOvertime = _calculateElapsedTime() - targetDailyHours;
    state = state.copyWith(dailyOvertime: dailyOvertime);
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
      print('[Dashboard] Timer gestartet um $now');
    } else {
      // STOP
      _timer?.cancel();
      updatedEntry = state.workEntry.copyWith(workEnd: now);
      print('[Dashboard] Timer gestoppt um $now');

      // Berechne automatische Pausen beim Beenden (nur wenn keine Pause läuft)
      final hasRunningBreak = updatedEntry.breaks.any((b) => b.end == null);
      if (!hasRunningBreak) {
        print('[Dashboard] Berechne automatische Pausen...');
        updatedEntry = BreakCalculatorService.calculateAndApplyBreaks(updatedEntry);
        print('[Dashboard] Automatische Pausen berechnet: ${updatedEntry.breaks.length} Pausen');
      } else {
        print('[Dashboard] Automatische Pausen übersprungen: Pause läuft noch');
      }
    }

    await _recalculateStateAndSave(updatedEntry);
  }

  Future<void> _recalculateStateAndSave(WorkEntryEntity updatedEntry, {bool save = true}) async {
    Duration? newActualWorkDuration;
    Duration? newOvertime = state.overtime;
    Duration? dailyOvertime;

    final wasFinished = state.workEntry.workEnd != null;
    final oldWorkDuration = state.actualWorkDuration ?? Duration.zero;

    if (updatedEntry.workStart != null && updatedEntry.workEnd != null) {
      final breakDuration = updatedEntry.breaks.fold<Duration>(
        Duration.zero,
        (previousValue, element) => previousValue + (element.end?.difference(element.start) ?? Duration.zero),
      );
      newActualWorkDuration = updatedEntry.workEnd!.difference(updatedEntry.workStart!) - breakDuration;

      final workdaysPerWeek = _settingsRepository.getWorkdaysPerWeek();
      final targetDailyHours = Duration(microseconds: (_settingsRepository.getTargetWeeklyHours() / workdaysPerWeek * Duration.microsecondsPerHour).round());
      dailyOvertime = newActualWorkDuration - targetDailyHours;

      if (save) {
        final oldDailyOvertime = wasFinished ? oldWorkDuration - targetDailyHours : Duration.zero;
        final newDailyOvertime = dailyOvertime;

        final currentTotalOvertime = state.overtime ?? await _getOvertime.call();
        newOvertime = currentTotalOvertime - oldDailyOvertime + newDailyOvertime;
        
        await _setOvertime.call(overtime: newOvertime);
      }
    } else {
      newActualWorkDuration = null;
      dailyOvertime = null;
    }

    state = state.copyWith(
      workEntry: updatedEntry,
      actualWorkDuration: newActualWorkDuration,
      overtime: newOvertime,
      dailyOvertime: dailyOvertime,
    );

    if (save) {
      print('[Dashboard] Speichere WorkEntry: ${updatedEntry.id}, Start: ${updatedEntry.workStart}, End: ${updatedEntry.workEnd}');
      await _saveWorkEntry.call(updatedEntry);
      print('[Dashboard] WorkEntry erfolgreich gespeichert');
    }
    _startTimerIfNeeded();
  }

  Future<void> setManualStartTime(TimeOfDay time) async {
    final oldDate = state.workEntry.workStart ?? DateTime.now();
    final newStart = DateTime(oldDate.year, oldDate.month, oldDate.day, time.hour, time.minute);
    var updatedEntry = state.workEntry.copyWith(workStart: newStart);

    print('[Dashboard] Setze manuelle Startzeit: $newStart');

    // Berechne automatische Pausen nur wenn:
    // 1. Start UND End vorhanden sind
    // 2. Keine laufende Pause existiert
    final hasRunningBreak = updatedEntry.breaks.any((b) => b.end == null);
    if (updatedEntry.workStart != null && updatedEntry.workEnd != null && !hasRunningBreak) {
      print('[Dashboard] Berechne automatische Pausen...');
      updatedEntry = BreakCalculatorService.calculateAndApplyBreaks(updatedEntry);
      print('[Dashboard] Automatische Pausen berechnet: ${updatedEntry.breaks.length} Pausen');
    }

    await _recalculateStateAndSave(updatedEntry);
    print('[Dashboard] Startzeit gespeichert');
  }

  Future<void> setManualEndTime(TimeOfDay time) async {
    final oldDate = state.workEntry.workEnd ?? state.workEntry.workStart ?? DateTime.now();
    final newEnd = DateTime(oldDate.year, oldDate.month, oldDate.day, time.hour, time.minute);
    var updatedEntry = state.workEntry.copyWith(workEnd: newEnd);

    print('[Dashboard] Setze manuelle Endzeit: $newEnd');

    // Berechne automatische Pausen nur wenn:
    // 1. Start UND End vorhanden sind
    // 2. Keine laufende Pause existiert
    final hasRunningBreak = updatedEntry.breaks.any((b) => b.end == null);
    if (updatedEntry.workStart != null && updatedEntry.workEnd != null && !hasRunningBreak) {
      print('[Dashboard] Berechne automatische Pausen...');
      updatedEntry = BreakCalculatorService.calculateAndApplyBreaks(updatedEntry);
      print('[Dashboard] Automatische Pausen berechnet: ${updatedEntry.breaks.length} Pausen');
    }

    await _recalculateStateAndSave(updatedEntry);
    print('[Dashboard] Endzeit gespeichert');
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

  @override
  void dispose() {
    _timer?.cancel();
    _autoSaveTimer?.cancel();
    super.dispose();
  }
}

final dashboardViewModelProvider = StateNotifierProvider<DashboardViewModel, DashboardState>((ref) {
  return DashboardViewModel(
    ref.watch(getTodayWorkEntryProvider),
    ref.watch(saveWorkEntryProvider),
    ref.watch(toggleBreakProvider),
    ref.watch(getOvertimeProvider),
    ref.watch(setOvertimeProvider),
    ref.watch(settingsRepositoryProvider),
  );
});
