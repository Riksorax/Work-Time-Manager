import 'package:flutter/material.dart' show ThemeMode;

/// Die Schnittstelle (der Vertrag) für den Zugriff auf lokale App-Einstellungen.
///
/// Dieses Repository abstrahiert, wo und wie die Einstellungen gespeichert werden
/// (z.B. in SharedPreferences oder einer lokalen Datenbank).
abstract class SettingsRepository {
  /// Ruft den aktuell gespeicherten Theme-Modus ab.
  ThemeMode getThemeMode();

  /// Speichert den ausgewählten Theme-Modus.
  Future<void> setThemeMode(ThemeMode mode);

  /// Ruft die wöchentlichen Soll-Arbeitsstunden des Benutzers ab.
  double getTargetWeeklyHours();

  /// Speichert die wöchentlichen Soll-Arbeitsstunden des Benutzers.
  Future<void> setTargetWeeklyHours(double hours);
}