import 'package:flutter/material.dart' show ThemeMode;

import '../entities/work_entry_entity.dart';

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

  /// Ruft die Anzahl der Arbeitstage pro Woche ab.
  int getWorkdaysPerWeek();

  /// Speichert die Anzahl der Arbeitstage pro Woche.
  Future<void> setWorkdaysPerWeek(int days);

  /// Ruft alle alten Arbeitseinträge zur Migration ab.
  Future<List<WorkEntryEntity>> getAllOldWorkEntries();

  /// Speichert die migrierten Arbeitseinträge in der neuen Struktur.
  Future<void> saveMigratedWorkEntries(Map<String, List<WorkEntryEntity>> monthlyEntries);

  /// Löscht die alten, tagesbasierten Arbeitseinträge.
  Future<void> deleteAllOldWorkEntries(List<String> entryIds);
}
