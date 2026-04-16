import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

/// Die Schnittstelle (der "Vertrag") für unsere lokale Speicher-Datenquelle.
/// Sie definiert, welche Operationen für App-Einstellungen möglich sein müssen.
abstract class StorageDataSource {
  /// Ruft den gespeicherten Theme-Modus ab.
  ThemeMode getThemeMode();

  /// Speichert den ausgewählten Theme-Modus.
  Future<void> setThemeMode(ThemeMode mode);

  /// Ruft die wöchentlichen Soll-Arbeitsstunden des Benutzers ab.
  double getTargetWeeklyHours();

  /// Speichert die wöchentlichen Soll-Arbeitsstunden des Benutzers.
  Future<void> setTargetWeeklyHours(double hours);

  /// Ruft den aktuellen Überstundensaldo ab.
  Duration getOvertime();

  /// Speichert den Überstundensaldo.
  Future<void> saveOvertime(Duration overtime);
}

/// Die konkrete Implementierung der lokalen Datenquelle,
/// die das `shared_preferences`-Paket verwendet.
class StorageDataSourceImpl implements StorageDataSource {
  final SharedPreferences _prefs;

  // Die Abhängigkeit (SharedPreferences) wird von außen über den Konstruktor
  // injiziert (Dependency Injection). Das ist entscheidend für die Testbarkeit.
  StorageDataSourceImpl(this._prefs);

  // Private Konstanten für die Schlüssel, um Tippfehler zu vermeiden.
  static const String _themeKey = 'theme_mode';
  static const String _targetHoursKey = 'target_weekly_hours';
  static const String _overtimeKey = 'overtime_balance';

  @override
  ThemeMode getThemeMode() {
    final themeString = _prefs.getString(_themeKey);
    // Suche in den ThemeMode-Werten nach dem gespeicherten String.
    // Wenn nichts gefunden wird, gib den System-Standard zurück.
    return ThemeMode.values.firstWhere(
      (e) => e.name == themeString,
      orElse: () => ThemeMode.system, // Standardwert
    );
  }

  @override
  Future<void> setThemeMode(ThemeMode mode) async {
    // Speichere den Namen des Enum-Wertes als String.
    await _prefs.setString(_themeKey, mode.name);
  }

  @override
  double getTargetWeeklyHours() {
    // Rufe den Double-Wert ab. Wenn der Schlüssel nicht existiert (also null ist),
    // gib den Standardwert 40.0 zurück.
    return _prefs.getDouble(_targetHoursKey) ?? 40.0; // Standardwert
  }

  @override
  Future<void> setTargetWeeklyHours(double hours) async {
    await _prefs.setDouble(_targetHoursKey, hours);
  }

  @override
  Duration getOvertime() {
    final minutes = _prefs.getInt(_overtimeKey) ?? 0;
    return Duration(minutes: minutes);
  }

  @override
  Future<void> saveOvertime(Duration overtime) async {
    await _prefs.setInt(_overtimeKey, overtime.inMinutes);
  }
}