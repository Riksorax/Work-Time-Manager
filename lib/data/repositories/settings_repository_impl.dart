import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/work_entry_entity.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/remote/firestore_datasource.dart';
import '../models/work_entry_model.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  // Theme ist global (nicht userId-spezifisch)
  static const String _themeModeKey = 'theme_mode';

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
    print('[SettingsRepository] getTargetWeeklyHours for user $_userId: $value');
    return value ?? 40.0;
  }

  @override
  Future<void> setTargetWeeklyHours(double hours) async {
    print('[SettingsRepository] setTargetWeeklyHours for user $_userId: $hours');
    await _prefs.setDouble(_targetHoursKey, hours);
  }

  @override
  int getWorkdaysPerWeek() {
    final value = _prefs.getInt(_workdaysPerWeekKey);
    print('[SettingsRepository] getWorkdaysPerWeek for user $_userId: $value');
    return value ?? 5;
  }

  @override
  Future<void> setWorkdaysPerWeek(int days) async {
    print('[SettingsRepository] setWorkdaysPerWeek for user $_userId: $days');
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
}
