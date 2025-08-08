import 'package:flutter/material.dart' show ThemeMode;

import '../../domain/repositories/settings_repository.dart';
import '../datasources/local/storage_datasource.dart';

/// Die konkrete Implementierung des SettingsRepository-Vertrags.
class SettingsRepositoryImpl implements SettingsRepository {
  final StorageDataSource _dataSource;

  // Die Abhängigkeit zur lokalen Datenquelle wird injiziert.
  SettingsRepositoryImpl(this._dataSource);

  @override
  ThemeMode getThemeMode() {
    // Leitet den Aufruf einfach an die Datenquelle weiter.
    return _dataSource.getThemeMode();
  }

  @override
  Future<void> setThemeMode(ThemeMode mode) async {
    // Leitet den Aufruf einfach an die Datenquelle weiter.
    await _dataSource.setThemeMode(mode);
  }

  @override
  int getTargetWeeklyHours() {
    // Leitet den Aufruf einfach an die Datenquelle weiter.
    return _dataSource.getTargetWeeklyHours();
  }

  @override
  Future<void> setTargetWeeklyHours(int hours) async {
    // Leitet den Aufruf einfach an die Datenquelle weiter.
    await _dataSource.setTargetWeeklyHours(hours);
  }
}