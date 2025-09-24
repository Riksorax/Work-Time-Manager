import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  static const String _themeModeKey = 'theme_mode';
  static const String _targetHoursKey = 'target_weekly_hours';

  final SharedPreferences _prefs;

  SettingsRepositoryImpl(this._prefs);

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
    return _prefs.getDouble(_targetHoursKey) ?? 40.0; // Default to 40 hours
  }

  @override
  Future<void> setTargetWeeklyHours(double hours) async {
    await _prefs.setDouble(_targetHoursKey, hours);
  }
}
