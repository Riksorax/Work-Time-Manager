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

  /// Ruft ab, ob die AGB akzeptiert wurden.
  bool hasAcceptedTermsOfService();

  /// Speichert, dass die AGB akzeptiert wurden.
  Future<void> setAcceptedTermsOfService(bool accepted);

  /// Ruft ab, ob die Datenschutzerklärung akzeptiert wurde.
  bool hasAcceptedPrivacyPolicy();

  /// Speichert, dass die Datenschutzerklärung akzeptiert wurde.
  Future<void> setAcceptedPrivacyPolicy(bool accepted);

  /// Ruft ab, ob Benachrichtigungen aktiviert sind.
  bool getNotificationsEnabled();

  /// Speichert, ob Benachrichtigungen aktiviert sind.
  Future<void> setNotificationsEnabled(bool enabled);

  /// Ruft die Zeit für tägliche Erinnerungen ab (Format: "HH:mm").
  String getNotificationTime();

  /// Speichert die Zeit für tägliche Erinnerungen (Format: "HH:mm").
  Future<void> setNotificationTime(String time);

  /// Ruft die Tage für Benachrichtigungen ab (1 = Monday, 7 = Sunday).
  List<int> getNotificationDays();

  /// Speichert die Tage für Benachrichtigungen.
  Future<void> setNotificationDays(List<int> days);

  /// Ruft ab, ob Arbeitsbeginn-Benachrichtigungen aktiviert sind.
  bool getNotifyWorkStart();

  /// Speichert, ob Arbeitsbeginn-Benachrichtigungen aktiviert sind.
  Future<void> setNotifyWorkStart(bool enabled);

  /// Ruft ab, ob Arbeitsende-Benachrichtigungen aktiviert sind.
  bool getNotifyWorkEnd();

  /// Speichert, ob Arbeitsende-Benachrichtigungen aktiviert sind.
  Future<void> setNotifyWorkEnd(bool enabled);

  /// Ruft ab, ob Pausen-Benachrichtigungen aktiviert sind.
  bool getNotifyBreaks();

  /// Speichert, ob Pausen-Benachrichtigungen aktiviert sind.
  Future<void> setNotifyBreaks(bool enabled);
}
