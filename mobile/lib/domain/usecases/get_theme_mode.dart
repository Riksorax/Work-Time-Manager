import 'package:flutter/material.dart' show ThemeMode;

import '../repositories/settings_repository.dart';

/// Ein "Use Case", der die Geschäftslogik zum Abrufen des
/// aktuell gespeicherten Theme-Modus kapselt.
///
/// Wird vom ThemeViewModel verwendet, um den initialen Zustand zu laden.
class GetThemeMode {
  // Der Use Case hängt nur von der abstrakten Repository-Schnittstelle ab.
  final SettingsRepository _repository;

  /// Die Abhängigkeit wird über den Konstruktor injiziert.
  GetThemeMode(this._repository);

  /// Führt den Use Case aus.
  ///
  /// Diese Methode ist synchron, da das Lesen aus den bereits geladenen
  /// SharedPreferences eine synchrone Operation ist.
  ThemeMode call() {
    return _repository.getThemeMode();
  }
}