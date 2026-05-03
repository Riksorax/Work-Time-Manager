import 'package:flutter/material.dart' show ThemeMode;
import '../repositories/settings_repository.dart';

/// Use Case zum Setzen des Theme-Modus.
class SetThemeMode {
  final SettingsRepository _repository;

  SetThemeMode(this._repository);

  Future<void> call(ThemeMode mode) async {
    await _repository.setThemeMode(mode);
  }
}