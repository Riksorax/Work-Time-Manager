import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/repositories/work_repository.dart';
import '../../domain/entities/work_entry_entity.dart';

// State for the settings page
@immutable
class SettingsState {
  final ThemeMode themeMode;
  final double weeklyTargetHours;

  const SettingsState({
    required this.themeMode,
    required this.weeklyTargetHours,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    double? weeklyTargetHours,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      weeklyTargetHours: weeklyTargetHours ?? this.weeklyTargetHours,
    );
  }
}

// ViewModel for the settings page
class SettingsViewModel extends StateNotifier<AsyncValue<SettingsState>> {
  final SettingsRepository _repository;
  final WorkRepository _workRepository;

  SettingsViewModel(this._repository, this._workRepository) : super(const AsyncValue.loading()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final themeMode = _repository.getThemeMode();
      final weeklyTargetHours = _repository.getTargetWeeklyHours();
      state = AsyncValue.data(
        SettingsState(
            themeMode: themeMode, weeklyTargetHours: weeklyTargetHours),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    try {
      await _repository.setThemeMode(mode);
      state.whenData((value) {
        state = AsyncValue.data(value.copyWith(themeMode: mode));
      });
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setTargetWeeklyHours(double hours) async {
    try {
      await _repository.setTargetWeeklyHours(hours);
      state.whenData((value) {
        state = AsyncValue.data(value.copyWith(weeklyTargetHours: hours));
      });
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Passt alle vorhandenen Arbeitszeiten basierend auf einem Anpassungsfaktor an
  Future<void> adjustAllWorkEntries(double adjustmentFactor) async {
    try {
      // Lade alle Einträge für die letzten 12 Monate
      final now = DateTime.now();
      final entries = <WorkEntryEntity>[];

      // Hole Einträge für die letzten 12 Monate
      for (int i = 0; i < 12; i++) {
        final date = DateTime(now.year, now.month - i);
        final monthEntries = await _workRepository.getWorkEntriesForMonth(
          date.year, date.month);
        entries.addAll(monthEntries);
      }

      // Passe alle Einträge an
      // Kurze Verzögerung zwischen den Einträgen, um UI-Updates zu ermöglichen
      for (final entry in entries) {
        if (entry.workStart != null && entry.workEnd != null) {
          // Neue Arbeitsdauer berechnen
          final oldDuration = entry.workEnd!.difference(entry.workStart!);
          final newDurationMinutes = (oldDuration.inMinutes * adjustmentFactor).round();

          // Neues Ende berechnen (Start bleibt gleich)
          final newWorkEnd = entry.workStart!.add(Duration(minutes: newDurationMinutes));

          // Angepassten Eintrag speichern
          final updatedEntry = entry.copyWith(workEnd: newWorkEnd);
          await _workRepository.saveWorkEntry(updatedEntry);

          // Kleine Verzögerung, um das UI nicht zu blockieren
          await Future.delayed(const Duration(milliseconds: 10));
        }
      }
    } catch (e) {
      // Fehler abfangen, aber weitermachen
      print('Fehler bei der Anpassung der Arbeitszeiten: $e');
    }
  }
}

// Provider for the SettingsViewModel
final settingsViewModelProvider =
StateNotifierProvider<SettingsViewModel, AsyncValue<SettingsState>>((ref) {
  final settingsRepository = ref.watch(settingsRepositoryProvider);
  final workRepository = ref.watch(workRepositoryProvider);
  return SettingsViewModel(settingsRepository, workRepository);
});

