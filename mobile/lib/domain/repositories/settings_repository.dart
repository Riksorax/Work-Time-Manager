import 'package:flutter/material.dart' show ThemeMode;

import '../entities/bundesland.dart';

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

  /// Ruft die konkreten Arbeitstage ab (ISO-Wochentage, 1 = Montag,
  /// 7 = Sonntag). Siehe #217.
  List<int> getWorkdays();

  /// Speichert die konkreten Arbeitstage (ISO-Wochentage 1-7).
  Future<void> setWorkdays(List<int> days);

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

  /// Ruft das für die Feiertagsberechnung ausgewählte Bundesland ab
  /// (`null` = keine Auswahl getroffen, siehe #222).
  Bundesland? getBundesland();

  /// Speichert das ausgewählte Bundesland (`null` löscht die Auswahl).
  Future<void> setBundesland(Bundesland? bundesland);

  /// Ruft ab, ob bei Überschreiten des Überstunden-Schwellwerts gewarnt
  /// werden soll. Siehe #219.
  bool getWarnOnOvertimeThreshold();

  /// Speichert, ob bei Überschreiten des Überstunden-Schwellwerts gewarnt
  /// werden soll.
  Future<void> setWarnOnOvertimeThreshold(bool enabled);

  /// Ruft den Schwellwert (in Stunden) für die Überstunden-Warnung ab.
  double getOvertimeThresholdHours();

  /// Speichert den Schwellwert (in Stunden) für die Überstunden-Warnung.
  Future<void> setOvertimeThresholdHours(double hours);

  /// Ruft ab, ob bei Unterschreiten des Minusstunden-Schwellwerts gewarnt
  /// werden soll. Siehe #219.
  bool getWarnOnUndertimeThreshold();

  /// Speichert, ob bei Unterschreiten des Minusstunden-Schwellwerts gewarnt
  /// werden soll.
  Future<void> setWarnOnUndertimeThreshold(bool enabled);

  /// Ruft den Schwellwert (in Stunden) für die Minusstunden-Warnung ab.
  double getUndertimeThresholdHours();

  /// Speichert den Schwellwert (in Stunden) für die Minusstunden-Warnung.
  Future<void> setUndertimeThresholdHours(double hours);

  /// Ruft ab, ob Uhrzeiten im 24-Stunden-Format angezeigt werden
  /// (false = 12-Stunden-Format mit AM/PM). Siehe #218.
  bool getUse24HourFormat();

  /// Speichert, ob Uhrzeiten im 24-Stunden-Format angezeigt werden.
  Future<void> setUse24HourFormat(bool use24Hour);

  /// Ruft die manuell überschriebene Zeitzone ab (IANA-Kennung, z.B.
  /// `Europe/Berlin`). `null` = Systemzeitzone verwenden. Siehe #221.
  String? getTimezoneOverride();

  /// Speichert die manuell überschriebene Zeitzone (`null` setzt auf
  /// Systemzeitzone zurück).
  Future<void> setTimezoneOverride(String? timezone);
}
