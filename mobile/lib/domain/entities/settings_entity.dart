import 'package:equatable/equatable.dart';

import 'bundesland.dart';

/// Represents the user's settings for the application.
class SettingsEntity extends Equatable {
  /// The target number of work hours per week.
  final double weeklyTargetHours;

  /// The number of workdays in a week.
  final int workdaysPerWeek;

  /// Whether notifications are enabled globally.
  final bool notificationsEnabled;

  /// The time for daily reminders (format: "HH:mm").
  final String notificationTime;

  /// Days of the week for notifications (1 = Monday, 7 = Sunday).
  final List<int> notificationDays;

  /// Whether to notify about missing work start entries.
  final bool notifyWorkStart;

  /// Whether to notify about missing work end entries.
  final bool notifyWorkEnd;

  /// Whether to notify about missing break entries.
  final bool notifyBreaks;

  /// Das ausgewählte Bundesland für die Feiertagsberechnung im Kalender
  /// (siehe #222). `null` = keine Auswahl getroffen, keine automatischen
  /// Feiertagsmarkierungen.
  final Bundesland? bundesland;

  const SettingsEntity({
    this.weeklyTargetHours = 40.0,
    this.workdaysPerWeek = 5,
    this.notificationsEnabled = false,
    this.notificationTime = '18:00',
    this.notificationDays = const [1, 2, 3, 4, 5], // Monday to Friday
    this.notifyWorkStart = true,
    this.notifyWorkEnd = true,
    this.notifyBreaks = true,
    this.bundesland,
  });

  /// Creates a copy of this [SettingsEntity] but with the given fields
  /// replaced with the new values.
  SettingsEntity copyWith({
    double? weeklyTargetHours,
    int? workdaysPerWeek,
    bool? notificationsEnabled,
    String? notificationTime,
    List<int>? notificationDays,
    bool? notifyWorkStart,
    bool? notifyWorkEnd,
    bool? notifyBreaks,
  }) {
    return SettingsEntity(
      weeklyTargetHours: weeklyTargetHours ?? this.weeklyTargetHours,
      workdaysPerWeek: workdaysPerWeek ?? this.workdaysPerWeek,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      notificationTime: notificationTime ?? this.notificationTime,
      notificationDays: notificationDays ?? this.notificationDays,
      notifyWorkStart: notifyWorkStart ?? this.notifyWorkStart,
      notifyWorkEnd: notifyWorkEnd ?? this.notifyWorkEnd,
      notifyBreaks: notifyBreaks ?? this.notifyBreaks,
      bundesland: bundesland ?? this.bundesland,
    );
  }

  /// Eigene Methode statt über [copyWith], da `bundesland` explizit auf
  /// `null` zurückgesetzt werden können muss (Nutzer wählt "Keine
  /// Auswahl") - das normale `?? this.bundesland`-Muster in [copyWith]
  /// kann "nicht angegeben" nicht von "bewusst auf null gesetzt"
  /// unterscheiden.
  SettingsEntity copyWithBundesland(Bundesland? bundesland) {
    return SettingsEntity(
      weeklyTargetHours: weeklyTargetHours,
      workdaysPerWeek: workdaysPerWeek,
      notificationsEnabled: notificationsEnabled,
      notificationTime: notificationTime,
      notificationDays: notificationDays,
      notifyWorkStart: notifyWorkStart,
      notifyWorkEnd: notifyWorkEnd,
      notifyBreaks: notifyBreaks,
      bundesland: bundesland,
    );
  }

  @override
  List<Object?> get props => [
        weeklyTargetHours,
        workdaysPerWeek,
        notificationsEnabled,
        notificationTime,
        notificationDays,
        notifyWorkStart,
        notifyWorkEnd,
        notifyBreaks,
        bundesland,
      ];
}
