import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart' as core_providers;
import '../../core/services/notification_service.dart';
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

  @override
  bool hasAcceptedTermsOfService() => false;

  @override
  Future<void> setAcceptedTermsOfService(bool accepted) async {}

  @override
  bool hasAcceptedPrivacyPolicy() => false;

  @override
  Future<void> setAcceptedPrivacyPolicy(bool accepted) async {}

  @override
  bool getNotificationsEnabled() => false;

  @override
  Future<void> setNotificationsEnabled(bool enabled) async {}

  @override
  String getNotificationTime() => '18:00';

  @override
  Future<void> setNotificationTime(String time) async {}

  @override
  List<int> getNotificationDays() => [1, 2, 3, 4, 5];

  @override
  Future<void> setNotificationDays(List<int> days) async {}

  @override
  bool getNotifyWorkStart() => true;

  @override
  Future<void> setNotifyWorkStart(bool enabled) async {}

  @override
  bool getNotifyWorkEnd() => true;

  @override
  Future<void> setNotifyWorkEnd(bool enabled) async {}

  @override
  bool getNotifyBreaks() => true;

  @override
  Future<void> setNotifyBreaks(bool enabled) async {}
}

class SettingsViewModel extends StateNotifier<AsyncValue<SettingsState>> {
  final GetOvertime _getOvertime;
  final SetOvertime _setOvertime;
  final SettingsRepository _settingsRepository;
  final NotificationService _notificationService;

  SettingsViewModel(
    this._getOvertime,
    this._setOvertime,
    this._settingsRepository,
    this._notificationService,
  ) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final overtimeBalance = _getOvertime.call();
      final weeklyTargetHours = _settingsRepository.getTargetWeeklyHours();
      final workdaysPerWeek = _settingsRepository.getWorkdaysPerWeek();
      final notificationsEnabled = _settingsRepository.getNotificationsEnabled();
      final notificationTime = _settingsRepository.getNotificationTime();
      final notificationDays = _settingsRepository.getNotificationDays();
      final notifyWorkStart = _settingsRepository.getNotifyWorkStart();
      final notifyWorkEnd = _settingsRepository.getNotifyWorkEnd();
      final notifyBreaks = _settingsRepository.getNotifyBreaks();

      final settings = SettingsEntity(
        weeklyTargetHours: weeklyTargetHours,
        workdaysPerWeek: workdaysPerWeek,
        notificationsEnabled: notificationsEnabled,
        notificationTime: notificationTime,
        notificationDays: notificationDays,
        notifyWorkStart: notifyWorkStart,
        notifyWorkEnd: notifyWorkEnd,
        notifyBreaks: notifyBreaks,
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

  Future<void> updateNotificationsEnabled(bool enabled) async {
    await _settingsRepository.setNotificationsEnabled(enabled);
    final newSettings = state.value!.settings.copyWith(notificationsEnabled: enabled);
    state = state.whenData((value) => value.copyWith(settings: newSettings));
    await _rescheduleNotifications();
  }

  Future<void> updateNotificationTime(String time) async {
    await _settingsRepository.setNotificationTime(time);
    final newSettings = state.value!.settings.copyWith(notificationTime: time);
    state = state.whenData((value) => value.copyWith(settings: newSettings));
    await _rescheduleNotifications();
  }

  Future<void> updateNotificationDays(List<int> days) async {
    await _settingsRepository.setNotificationDays(days);
    final newSettings = state.value!.settings.copyWith(notificationDays: days);
    state = state.whenData((value) => value.copyWith(settings: newSettings));
    await _rescheduleNotifications();
  }

  Future<void> updateNotifyWorkStart(bool enabled) async {
    await _settingsRepository.setNotifyWorkStart(enabled);
    final newSettings = state.value!.settings.copyWith(notifyWorkStart: enabled);
    state = state.whenData((value) => value.copyWith(settings: newSettings));
    await _rescheduleNotifications();
  }

  Future<void> updateNotifyWorkEnd(bool enabled) async {
    await _settingsRepository.setNotifyWorkEnd(enabled);
    final newSettings = state.value!.settings.copyWith(notifyWorkEnd: enabled);
    state = state.whenData((value) => value.copyWith(settings: newSettings));
    await _rescheduleNotifications();
  }

  Future<void> updateNotifyBreaks(bool enabled) async {
    await _settingsRepository.setNotifyBreaks(enabled);
    final newSettings = state.value!.settings.copyWith(notifyBreaks: enabled);
    state = state.whenData((value) => value.copyWith(settings: newSettings));
    await _rescheduleNotifications();
  }

  // --- Notification Rescheduling Logic ---
  Future<void> _rescheduleNotifications() async {
    final notificationsEnabled = _settingsRepository.getNotificationsEnabled();
    if (notificationsEnabled) {
      final notificationTime = _settingsRepository.getNotificationTime();
      final notificationDays = _settingsRepository.getNotificationDays();
      final notifyWorkStart = _settingsRepository.getNotifyWorkStart();
      final notifyWorkEnd = _settingsRepository.getNotifyWorkEnd();
      final notifyBreaks = _settingsRepository.getNotifyBreaks();

      await _notificationService.scheduleDailyReminder(
        time: notificationTime,
        days: notificationDays,
        checkWorkStart: notifyWorkStart,
        checkWorkEnd: notifyWorkEnd,
        checkBreaks: notifyBreaks,
      );
    } else {
      // Wenn Benachrichtigungen deaktiviert sind, alle Benachrichtigungen abbrechen
      await _notificationService.cancelAllNotifications();
    }
  }
}

final settingsViewModelProvider =
    StateNotifierProvider<SettingsViewModel, AsyncValue<SettingsState>>((ref) {
  return SettingsViewModel(
    ref.watch(getOvertimeProvider),
    ref.watch(setOvertimeProvider),
    ref.watch(core_providers.settingsRepositoryProvider),
    ref.watch(core_providers.notificationServiceProvider),
  );
});
