import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers/providers.dart' as core_providers;
import '../../core/utils/timezone_utils.dart';
import '../../domain/entities/bundesland.dart';
import '../../domain/entities/settings_entity.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/utils/overtime_warning_utils.dart';
import '../state/settings_state.dart';
import 'dashboard_view_model.dart' show dashboardViewModelProvider;

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
  List<int> getWorkdays() => const [1, 2, 3, 4, 5];
  @override
  Future<void> setWorkdays(List<int> days) async {}

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

  @override
  Bundesland? getBundesland() => null;

  @override
  Future<void> setBundesland(Bundesland? bundesland) async {}

  @override
  bool getWarnOnOvertimeThreshold() => false;

  @override
  Future<void> setWarnOnOvertimeThreshold(bool enabled) async {}

  @override
  double getOvertimeThresholdHours() => 10.0;

  @override
  Future<void> setOvertimeThresholdHours(double hours) async {}

  @override
  bool getWarnOnUndertimeThreshold() => false;

  @override
  Future<void> setWarnOnUndertimeThreshold(bool enabled) async {}

  @override
  double getUndertimeThresholdHours() => 10.0;

  @override
  Future<void> setUndertimeThresholdHours(double hours) async {}

  @override
  bool getUse24HourFormat() => true;

  @override
  Future<void> setUse24HourFormat(bool use24Hour) async {}

  @override
  String? getTimezoneOverride() => null;

  @override
  Future<void> setTimezoneOverride(String? timezone) async {}

  @override
  String getLocale() => 'de';

  @override
  Future<void> setLocale(String locale) async {}
}

class SettingsViewModel extends Notifier<AsyncValue<SettingsState>> {
  @override
  AsyncValue<SettingsState> build() {
    // Watch dependencies to trigger rebuild on updates (e.g. Auth change).
    // In try/catch: falls SharedPreferences (z.B. in Tests ohne Provider-
    // Override) noch nicht verfügbar ist, würde dieser watch()-Aufruf sonst
    // synchron eine ProviderException werfen, die als ungefangene Exception
    // bei jedem Widget landet, das settingsViewModelProvider beobachtet -
    // _init() unten fängt denselben Fehler zwar auch ab, aber erst
    // asynchron, also zu spät für diesen synchronen build()-Aufruf.
    try {
      ref.watch(core_providers.getOvertimeUseCaseProvider);
      ref.watch(core_providers.settingsRepositoryProvider);
    } catch (_) {
      // Reactivity auf diese Provider geht in diesem Fall verloren - der
      // eigentliche Fehler wird unten in _init() erneut geworfen und dort
      // reguär in einen AsyncValue.error verwandelt.
    }

    Future.microtask(() => _init());
    return const AsyncValue.loading();
  }

  Future<void> _init() async {
    try {
      final overtimeRepository = ref.read(core_providers.overtimeRepositoryProvider);
      final settingsRepository = ref.read(core_providers.settingsRepositoryProvider);

      // Beide Ladevorgänge parallel starten statt sequentiell zu awaiten - jeder
      // await war zuvor ein eigener Netzwerk-Roundtrip zu Firebase/Backend-API und
      // verzögerte das Anzeigen der Einstellungen unnötig.
      final overtimeBalanceFuture = overtimeRepository.ensureOvertimeLoaded();
      final lastOvertimeUpdateFuture = overtimeRepository.ensureLastUpdateLoaded();
      final overtimeBalance = await overtimeBalanceFuture;
      final lastOvertimeUpdate = await lastOvertimeUpdateFuture;
      final weeklyTargetHours = settingsRepository.getTargetWeeklyHours();
      final workdays = settingsRepository.getWorkdays();
      final notificationsEnabled = settingsRepository.getNotificationsEnabled();
      final notificationTime = settingsRepository.getNotificationTime();
      final notificationDays = settingsRepository.getNotificationDays();
      final notifyWorkStart = settingsRepository.getNotifyWorkStart();
      final notifyWorkEnd = settingsRepository.getNotifyWorkEnd();
      final notifyBreaks = settingsRepository.getNotifyBreaks();
      Bundesland? bundesland;
      try {
        bundesland = settingsRepository.getBundesland();
      } catch (_) {
        bundesland = null;
      }
      final warnOnOvertimeThreshold = settingsRepository.getWarnOnOvertimeThreshold();
      final overtimeThresholdHours = settingsRepository.getOvertimeThresholdHours();
      final warnOnUndertimeThreshold = settingsRepository.getWarnOnUndertimeThreshold();
      final undertimeThresholdHours = settingsRepository.getUndertimeThresholdHours();
      final use24HourFormat = settingsRepository.getUse24HourFormat();
      final timezoneOverride = settingsRepository.getTimezoneOverride();
      final locale = settingsRepository.getLocale();

      final settings = SettingsEntity(
        weeklyTargetHours: weeklyTargetHours,
        workdays: workdays,
        notificationsEnabled: notificationsEnabled,
        notificationTime: notificationTime,
        notificationDays: notificationDays,
        notifyWorkStart: notifyWorkStart,
        notifyWorkEnd: notifyWorkEnd,
        notifyBreaks: notifyBreaks,
        bundesland: bundesland,
        warnOnOvertimeThreshold: warnOnOvertimeThreshold,
        overtimeThresholdHours: overtimeThresholdHours,
        warnOnUndertimeThreshold: warnOnUndertimeThreshold,
        undertimeThresholdHours: undertimeThresholdHours,
        use24HourFormat: use24HourFormat,
        timezoneOverride: timezoneOverride,
        locale: locale,
      );
      state = AsyncValue.data(SettingsState(
        settings: settings,
        overtimeBalance: overtimeBalance,
        lastOvertimeUpdate: lastOvertimeUpdate,
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setOvertimeBalance(WidgetRef ref, Duration overtime) async {
    final setOvertime = ref.read(core_providers.setOvertimeUseCaseProvider);
    await setOvertime.call(overtime: overtime, isManual: true);
    final now = DateTime.now();
    state = state.whenData((value) => value.copyWith(
      overtimeBalance: overtime,
      lastOvertimeUpdate: now,
    ));
    ref.read(dashboardViewModelProvider.notifier).updateOvertimeFromSettings(overtime);
    await _checkOvertimeWarning(overtime);
  }

  /// Prüft nach jeder manuellen Anpassung des Gleitzeitsaldos, ob ein
  /// konfigurierter Über-/Minusstunden-Schwellwert erreicht ist (siehe #219).
  Future<void> _checkOvertimeWarning(Duration totalOvertime) async {
    // Eine fehlschlagende Warnprüfung darf niemals die eigentliche
    // Gleitzeit-Anpassung gefährden - daher komplett defensiv.
    try {
      final settingsRepository = ref.read(core_providers.settingsRepositoryProvider);
      final warningType = checkOvertimeWarning(
        totalOvertime: totalOvertime,
        warnOnOvertime: settingsRepository.getWarnOnOvertimeThreshold(),
        overtimeThresholdHours: settingsRepository.getOvertimeThresholdHours(),
        warnOnUndertime: settingsRepository.getWarnOnUndertimeThreshold(),
        undertimeThresholdHours: settingsRepository.getUndertimeThresholdHours(),
      );
      if (warningType == OvertimeWarningType.none) return;

      final notificationService = ref.read(core_providers.notificationServiceProvider);
      await notificationService.showOvertimeWarning(
        type: warningType,
        totalOvertime: totalOvertime,
      );
    } catch (_) {
      // Logging über logger würde hier selbst wieder Provider lesen können -
      // bewusst minimal gehalten, um keine neue Fehlerquelle zu öffnen.
    }
  }

  Future<void> updateWorkdays(WidgetRef ref, List<int> days) async {
    final settingsRepository = ref.read(core_providers.settingsRepositoryProvider);
    await settingsRepository.setWorkdays(days);
    final newSettings = state.value!.settings.copyWith(workdays: days);
    state = state.whenData((value) => value.copyWith(settings: newSettings));

    // Dashboard über die Änderung informieren
    ref.read(dashboardViewModelProvider.notifier).recalculateOvertimeFromSettings();
  }

  Future<void> updateWeeklyTargetHours(WidgetRef ref, double hours) async {
    final settingsRepository = ref.read(core_providers.settingsRepositoryProvider);
    await settingsRepository.setTargetWeeklyHours(hours);
    final newSettings = state.value!.settings.copyWith(weeklyTargetHours: hours);
    state = state.whenData((value) => value.copyWith(settings: newSettings));

    // Dashboard über die Änderung informieren
    ref.read(dashboardViewModelProvider.notifier).recalculateOvertimeFromSettings();
  }

  Future<void> updateNotificationsEnabled(bool enabled) async {
    final settingsRepository = ref.read(core_providers.settingsRepositoryProvider);
    await settingsRepository.setNotificationsEnabled(enabled);
    final newSettings = state.value!.settings.copyWith(notificationsEnabled: enabled);
    state = state.whenData((value) => value.copyWith(settings: newSettings));
    await _rescheduleNotifications();
  }

  Future<void> updateNotificationTime(String time) async {
    final settingsRepository = ref.read(core_providers.settingsRepositoryProvider);
    await settingsRepository.setNotificationTime(time);
    final newSettings = state.value!.settings.copyWith(notificationTime: time);
    state = state.whenData((value) => value.copyWith(settings: newSettings));
    await _rescheduleNotifications();
  }

  Future<void> updateNotificationDays(List<int> days) async {
    final settingsRepository = ref.read(core_providers.settingsRepositoryProvider);
    await settingsRepository.setNotificationDays(days);
    final newSettings = state.value!.settings.copyWith(notificationDays: days);
    state = state.whenData((value) => value.copyWith(settings: newSettings));
    await _rescheduleNotifications();
  }

  Future<void> updateNotifyWorkStart(bool enabled) async {
    final settingsRepository = ref.read(core_providers.settingsRepositoryProvider);
    await settingsRepository.setNotifyWorkStart(enabled);
    final newSettings = state.value!.settings.copyWith(notifyWorkStart: enabled);
    state = state.whenData((value) => value.copyWith(settings: newSettings));
    await _rescheduleNotifications();
  }

  Future<void> updateNotifyWorkEnd(bool enabled) async {
    final settingsRepository = ref.read(core_providers.settingsRepositoryProvider);
    await settingsRepository.setNotifyWorkEnd(enabled);
    final newSettings = state.value!.settings.copyWith(notifyWorkEnd: enabled);
    state = state.whenData((value) => value.copyWith(settings: newSettings));
    await _rescheduleNotifications();
  }

  Future<void> updateNotifyBreaks(bool enabled) async {
    final settingsRepository = ref.read(core_providers.settingsRepositoryProvider);
    await settingsRepository.setNotifyBreaks(enabled);
    final newSettings = state.value!.settings.copyWith(notifyBreaks: enabled);
    state = state.whenData((value) => value.copyWith(settings: newSettings));
    await _rescheduleNotifications();
  }

  Future<void> updateBundesland(Bundesland? bundesland) async {
    final settingsRepository = ref.read(core_providers.settingsRepositoryProvider);
    await settingsRepository.setBundesland(bundesland);
    final newSettings = state.value!.settings.copyWithBundesland(bundesland);
    state = state.whenData((value) => value.copyWith(settings: newSettings));
  }

  Future<void> updateWarnOnOvertimeThreshold(bool enabled) async {
    final settingsRepository = ref.read(core_providers.settingsRepositoryProvider);
    await settingsRepository.setWarnOnOvertimeThreshold(enabled);
    final newSettings = state.value!.settings.copyWith(warnOnOvertimeThreshold: enabled);
    state = state.whenData((value) => value.copyWith(settings: newSettings));
  }

  Future<void> updateOvertimeThresholdHours(double hours) async {
    final settingsRepository = ref.read(core_providers.settingsRepositoryProvider);
    await settingsRepository.setOvertimeThresholdHours(hours);
    final newSettings = state.value!.settings.copyWith(overtimeThresholdHours: hours);
    state = state.whenData((value) => value.copyWith(settings: newSettings));
  }

  Future<void> updateWarnOnUndertimeThreshold(bool enabled) async {
    final settingsRepository = ref.read(core_providers.settingsRepositoryProvider);
    await settingsRepository.setWarnOnUndertimeThreshold(enabled);
    final newSettings = state.value!.settings.copyWith(warnOnUndertimeThreshold: enabled);
    state = state.whenData((value) => value.copyWith(settings: newSettings));
  }

  Future<void> updateUndertimeThresholdHours(double hours) async {
    final settingsRepository = ref.read(core_providers.settingsRepositoryProvider);
    await settingsRepository.setUndertimeThresholdHours(hours);
    final newSettings = state.value!.settings.copyWith(undertimeThresholdHours: hours);
    state = state.whenData((value) => value.copyWith(settings: newSettings));
  }

  Future<void> updateUse24HourFormat(bool use24Hour) async {
    final settingsRepository = ref.read(core_providers.settingsRepositoryProvider);
    await settingsRepository.setUse24HourFormat(use24Hour);
    final newSettings = state.value!.settings.copyWith(use24HourFormat: use24Hour);
    state = state.whenData((value) => value.copyWith(settings: newSettings));
  }

  /// Speichert die manuelle Zeitzone-Überschreibung (`null` = Systemzeitzone)
  /// und wendet sie sofort auf [tz.local] an, damit z.B. Benachrichtigungs-
  /// Zeitpunkte ohne App-Neustart korrekt berechnet werden. Siehe #221.
  Future<void> updateTimezoneOverride(String? timezone) async {
    final settingsRepository = ref.read(core_providers.settingsRepositoryProvider);
    await settingsRepository.setTimezoneOverride(timezone);
    await applyTimezone(timezone);
    final newSettings = state.value!.settings.copyWithTimezoneOverride(timezone);
    state = state.whenData((value) => value.copyWith(settings: newSettings));
    await _rescheduleNotifications();
  }

  /// Speichert die Sprache der App-Oberfläche (`de`/`en`) und aktualisiert
  /// [Intl.defaultLocale] sofort, damit z.B. `formatTime` (siehe #218) ohne
  /// App-Neustart in der neuen Sprache formatiert. Siehe #221.
  Future<void> updateLocale(String locale) async {
    final settingsRepository = ref.read(core_providers.settingsRepositoryProvider);
    await settingsRepository.setLocale(locale);
    Intl.defaultLocale = locale == 'en' ? 'en_US' : 'de_DE';
    final newSettings = state.value!.settings.copyWith(locale: locale);
    state = state.whenData((value) => value.copyWith(settings: newSettings));
  }

  // --- Notification Rescheduling Logic ---
  Future<void> _rescheduleNotifications() async {
    final settingsRepository = ref.read(core_providers.settingsRepositoryProvider);
    final notificationService = ref.read(core_providers.notificationServiceProvider);
    
    final notificationsEnabled = settingsRepository.getNotificationsEnabled();
    if (notificationsEnabled) {
      final notificationTime = settingsRepository.getNotificationTime();
      final notificationDays = settingsRepository.getNotificationDays();
      final notifyWorkStart = settingsRepository.getNotifyWorkStart();
      final notifyWorkEnd = settingsRepository.getNotifyWorkEnd();
      final notifyBreaks = settingsRepository.getNotifyBreaks();

      await notificationService.scheduleDailyReminder(
        time: notificationTime,
        days: notificationDays,
        checkWorkStart: notifyWorkStart,
        checkWorkEnd: notifyWorkEnd,
        checkBreaks: notifyBreaks,
      );
    } else {
      // Wenn Benachrichtigungen deaktiviert sind, alle Benachrichtigungen abbrechen
      await notificationService.cancelAllNotifications();
    }
  }
}

final settingsViewModelProvider =
    NotifierProvider<SettingsViewModel, AsyncValue<SettingsState>>(SettingsViewModel.new);