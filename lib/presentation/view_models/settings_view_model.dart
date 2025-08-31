import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../domain/repositories/settings_repository.dart';

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

  SettingsViewModel(this._repository) : super(const AsyncValue.loading()) {
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
}

// Provider for the SettingsViewModel
final settingsViewModelProvider =
StateNotifierProvider<SettingsViewModel, AsyncValue<SettingsState>>((ref) {
  final repository = ref.watch(settingsRepositoryProvider);
  return SettingsViewModel(repository);
});

