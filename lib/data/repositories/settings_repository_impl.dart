import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_work_time/core/utils/logger.dart';

import '../../domain/entities/work_entry_entity.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/remote/firestore_datasource.dart';
import '../models/work_entry_model.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  // Theme ist global (nicht userId-spezifisch)
  static const String _themeModeKey = 'theme_mode';
  // Rechtliche Zustimmungen sind global (nicht userId-spezifisch)
  static const String _acceptedTermsOfServiceKey = 'accepted_terms_of_service';
  static const String _acceptedPrivacyPolicyKey = 'accepted_privacy_policy';
  // Benachrichtigungen sind global (nicht userId-spezifisch)
  static const String _notificationsEnabledKey = 'notifications_enabled';
  static const String _notificationTimeKey = 'notification_time';
  static const String _notificationDaysKey = 'notification_days';
  static const String _notifyWorkStartKey = 'notify_work_start';
  static const String _notifyWorkEndKey = 'notify_work_end';
  static const String _notifyBreaksKey = 'notify_breaks';

  final SharedPreferences _prefs;
  final FirestoreDataSource _firestoreDataSource;
  final String _userId;

  SettingsRepositoryImpl(this._prefs, this._firestoreDataSource, this._userId);

  // Generiere userId-spezifische Keys für Einstellungen
  String get _targetHoursKey => 'target_weekly_hours_$_userId';
  String get _workdaysPerWeekKey => 'workdays_per_week_$_userId';

  @override
  ThemeMode getThemeMode() {
    final themeModeString = _prefs.getString(_themeModeKey);
    if (themeModeString == 'dark') {
      return ThemeMode.dark;
    } else if (themeModeString == 'light') {
      return ThemeMode.light;
    } else {
      return ThemeMode.system;
    }
  }

  @override
  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString(_themeModeKey, mode.name);
  }

  @override
  double getTargetWeeklyHours() {
    final value = _prefs.getDouble(_targetHoursKey);
    logger.i('[SettingsRepository] getTargetWeeklyHours for user $_userId: $value');
    return value ?? 40.0;
  }

  @override
  Future<void> setTargetWeeklyHours(double hours) async {
    logger.i('[SettingsRepository] setTargetWeeklyHours for user $_userId: $hours');
    await _prefs.setDouble(_targetHoursKey, hours);
  }

  @override
  int getWorkdaysPerWeek() {
    final value = _prefs.getInt(_workdaysPerWeekKey);
    logger.i('[SettingsRepository] getWorkdaysPerWeek for user $_userId: $value');
    return value ?? 5;
  }

  @override
  Future<void> setWorkdaysPerWeek(int days) async {
    logger.i('[SettingsRepository] setWorkdaysPerWeek for user $_userId: $days');
    await _prefs.setInt(_workdaysPerWeekKey, days);
  }

  @override
  Future<List<WorkEntryEntity>> getAllOldWorkEntries() async {
    return await _firestoreDataSource.getAllOldWorkEntries(_userId);
  }

  @override
  Future<void> saveMigratedWorkEntries(Map<String, List<WorkEntryEntity>> monthlyEntries) async {
    for (final entry in monthlyEntries.entries) {
      for (final workEntry in entry.value) {
        await _firestoreDataSource.saveWorkEntry(_userId, WorkEntryModel.fromEntity(workEntry));
      }
    }
  }

  @override
  Future<void> deleteAllOldWorkEntries(List<String> entryIds) async {
    await _firestoreDataSource.deleteAllOldWorkEntries(_userId, entryIds);
  }

  @override
  bool hasAcceptedTermsOfService() {
    return _prefs.getBool(_acceptedTermsOfServiceKey) ?? false;
  }

  @override
  Future<void> setAcceptedTermsOfService(bool accepted) async {
    await _prefs.setBool(_acceptedTermsOfServiceKey, accepted);
  }

  @override
  bool hasAcceptedPrivacyPolicy() {
    return _prefs.getBool(_acceptedPrivacyPolicyKey) ?? false;
  }

  @override
  Future<void> setAcceptedPrivacyPolicy(bool accepted) async {
    await _prefs.setBool(_acceptedPrivacyPolicyKey, accepted);
  }

  @override
  bool getNotificationsEnabled() {
    return _prefs.getBool(_notificationsEnabledKey) ?? false;
  }

  @override
  Future<void> setNotificationsEnabled(bool enabled) async {
    await _prefs.setBool(_notificationsEnabledKey, enabled);
  }

  @override
  String getNotificationTime() {
    return _prefs.getString(_notificationTimeKey) ?? '18:00';
  }

  @override
  Future<void> setNotificationTime(String time) async {
    await _prefs.setString(_notificationTimeKey, time);
  }

  @override
  List<int> getNotificationDays() {
    final daysString = _prefs.getString(_notificationDaysKey);
    if (daysString == null || daysString.isEmpty) {
      return [1, 2, 3, 4, 5]; // Default: Monday to Friday
    }
    return daysString.split(',').map((e) => int.parse(e)).toList();
  }

  @override
  Future<void> setNotificationDays(List<int> days) async {
    await _prefs.setString(_notificationDaysKey, days.join(','));
  }

  @override
  bool getNotifyWorkStart() {
    return _prefs.getBool(_notifyWorkStartKey) ?? true;
  }

  @override
  Future<void> setNotifyWorkStart(bool enabled) async {
    await _prefs.setBool(_notifyWorkStartKey, enabled);
  }

  @override
  bool getNotifyWorkEnd() {
    return _prefs.getBool(_notifyWorkEndKey) ?? true;
  }

  @override
  Future<void> setNotifyWorkEnd(bool enabled) async {
    await _prefs.setBool(_notifyWorkEndKey, enabled);
  }

  @override
  bool getNotifyBreaks() {
    return _prefs.getBool(_notifyBreaksKey) ?? true;
  }

  @override
  Future<void> setNotifyBreaks(bool enabled) async {
    await _prefs.setBool(_notifyBreaksKey, enabled);
  }
}
