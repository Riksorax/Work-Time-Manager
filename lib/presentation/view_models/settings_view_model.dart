import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart' as core_providers;
import '../../domain/entities/settings_entity.dart';
import '../../domain/entities/work_entry_entity.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/usecases/overtime_usecases.dart';
import '../state/settings_state.dart';
import 'dashboard_view_model.dart' show getOvertimeProvider, setOvertimeProvider, dashboardViewModelProvider;

// Temporary No-op repository - wird nur für Fallback-Fälle benötigt
class NoOpSettingsRepository implements SettingsRepository {
  @override
  ThemeMode getThemeMode() => ThemeMode.system;
  @override
  Future<void> setThemeMode(ThemeMode mode) async {}
  @override
  double getTargetWeeklyHours() => 40.0;
  @override
  Future<void> setTargetWeeklyHours(double hours) async {}
  @override
  int getWorkdaysPerWeek() => 5;
  @override
  Future<void> setWorkdaysPerWeek(int days) async {}

  @override
  Future<List<WorkEntryEntity>> getAllOldWorkEntries() async => [];

  @override
  Future<void> saveMigratedWorkEntries(Map<String, List<WorkEntryEntity>> monthlyEntries) async {}

  @override
  Future<void> deleteAllOldWorkEntries(List<String> entryIds) async {}
}

class SettingsViewModel extends StateNotifier<AsyncValue<SettingsState>> {
  final GetOvertime _getOvertime;
  final SetOvertime _setOvertime;
  final SettingsRepository _settingsRepository;

  SettingsViewModel(
    this._getOvertime,
    this._setOvertime,
    this._settingsRepository,
  ) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final overtimeBalance = _getOvertime.call();
      final weeklyTargetHours = _settingsRepository.getTargetWeeklyHours();
      final workdaysPerWeek = _settingsRepository.getWorkdaysPerWeek();
      final settings = SettingsEntity(
        weeklyTargetHours: weeklyTargetHours,
        workdaysPerWeek: workdaysPerWeek,
      );
      state = AsyncValue.data(SettingsState(
        settings: settings,
        overtimeBalance: overtimeBalance,
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setOvertimeBalance(WidgetRef ref, Duration overtime) async {
    await _setOvertime.call(overtime: overtime);
    state = state.whenData((value) => value.copyWith(overtimeBalance: overtime));
    ref.read(dashboardViewModelProvider.notifier).updateOvertimeFromSettings(overtime);
  }

  Future<void> updateWorkdaysPerWeek(WidgetRef ref, int days) async {
    await _settingsRepository.setWorkdaysPerWeek(days);
    final newSettings = state.value!.settings.copyWith(workdaysPerWeek: days);
    state = state.whenData((value) => value.copyWith(settings: newSettings));

    // Dashboard über die Änderung informieren
    ref.read(dashboardViewModelProvider.notifier).recalculateOvertimeFromSettings();
  }

  Future<void> updateWeeklyTargetHours(WidgetRef ref, double hours) async {
    await _settingsRepository.setTargetWeeklyHours(hours);
    final newSettings = state.value!.settings.copyWith(weeklyTargetHours: hours);
    state = state.whenData((value) => value.copyWith(settings: newSettings));

    // Dashboard über die Änderung informieren
    ref.read(dashboardViewModelProvider.notifier).recalculateOvertimeFromSettings();
  }

  Future<void> migrateWorkEntries() async {
    try {
      final oldEntries = await _settingsRepository.getAllOldWorkEntries();
      if (oldEntries.isEmpty) {
        return;
      }

      final monthlyEntries = <String, List<WorkEntryEntity>>{};
      for (final entry in oldEntries) {
        final monthId = '${entry.date.year}-${entry.date.month.toString().padLeft(2, '0')}';
        (monthlyEntries[monthId] ??= []).add(entry);
      }

      await _settingsRepository.saveMigratedWorkEntries(monthlyEntries);
      await _settingsRepository.deleteAllOldWorkEntries(oldEntries.map((e) => e.id).toList());
    } catch (e) {
      // Handle error
    }
  }
}

final settingsViewModelProvider =
    StateNotifierProvider<SettingsViewModel, AsyncValue<SettingsState>>((ref) {
  return SettingsViewModel(
    ref.watch(getOvertimeProvider),
    ref.watch(setOvertimeProvider),
    ref.watch(core_providers.settingsRepositoryProvider),
  );
});
