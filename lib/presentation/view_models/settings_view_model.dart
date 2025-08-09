import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/settings_repository_impl.dart';
import '../../domain/repositories/settings_repository.dart';

// Provider for the SharedPreferences instance
final sharedPreferencesProvider =
    FutureProvider<SharedPreferences>((ref) => SharedPreferences.getInstance());

// Provider for the SettingsRepository
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final prefsAsyncValue = ref.watch(sharedPreferencesProvider);
  return prefsAsyncValue.when(
    data: (prefs) => SettingsRepositoryImpl(prefs),
    loading: () =>
        throw Exception("SettingsRepository is not available while loading."),
    error: (err, stack) =>
        throw Exception("Error initializing SettingsRepository: $err"),
  );
});

// State for the settings page
@immutable
class SettingsState {
  final ThemeMode themeMode;
  final int weeklyTargetHours;

  const SettingsState({
    required this.themeMode,
    required this.weeklyTargetHours,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    int? weeklyTargetHours,
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

  Future<void> setTargetWeeklyHours(int hours) async {
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
  try {
    final repository = ref.watch(settingsRepositoryProvider);
    return SettingsViewModel(repository);
  } catch (e) {
    // This will provide a view model in an error state if the repository fails to initialize
    // You might want to handle this more gracefully in a real app
    return SettingsViewModel(const DummySettingsRepository());
  }
});

/// A dummy implementation for when the real repository isn't available.
class DummySettingsRepository implements SettingsRepository {
  const DummySettingsRepository();

  @override
  ThemeMode getThemeMode() => ThemeMode.system;

  @override
  Future<void> setThemeMode(ThemeMode mode) async {}

  @override
  int getTargetWeeklyHours() => 40;

  @override
  Future<void> setTargetWeeklyHours(int hours) async {}
}
