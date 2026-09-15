import 'package:equatable/equatable.dart';

import 'bundesland.dart';

/// Represents the user's settings for the application.
class SettingsEntity extends Equatable {
  /// The target number of work hours per week.
  final double weeklyTargetHours;

  /// Die konkreten Wochentage, an denen gearbeitet wird (ISO-Wochentage,
  /// 1 = Montag ... 7 = Sonntag). Ersetzt die reine Anzahl, damit z.B.
  /// Di-Sa korrekt als Arbeitstage erkannt werden (siehe #217).
  final List<int> workdays;

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

  /// Whether to warn when the overtime balance exceeds
  /// [overtimeThresholdHours]. Siehe #219.
  final bool warnOnOvertimeThreshold;

  /// Threshold in hours for the overtime warning.
  final double overtimeThresholdHours;

  /// Whether to warn when the overtime balance falls below
  /// -[undertimeThresholdHours]. Siehe #219.
  final bool warnOnUndertimeThreshold;

  /// Threshold in hours for the undertime (minus hours) warning.
  final double undertimeThresholdHours;

  /// Whether times are displayed in 24-hour format (true) or 12-hour
  /// format with AM/PM (false). Siehe #218.
  final bool use24HourFormat;

  const SettingsEntity({
    this.weeklyTargetHours = 40.0,
    this.workdays = const [1, 2, 3, 4, 5], // Monday to Friday
    this.notificationsEnabled = false,
    this.notificationTime = '18:00',
    this.notificationDays = const [1, 2, 3, 4, 5], // Monday to Friday
    this.notifyWorkStart = true,
    this.notifyWorkEnd = true,
    this.notifyBreaks = true,
    this.bundesland,
    this.warnOnOvertimeThreshold = false,
    this.overtimeThresholdHours = 10.0,
    this.warnOnUndertimeThreshold = false,
    this.undertimeThresholdHours = 10.0,
    this.use24HourFormat = true,
  });

  /// Creates a copy of this [SettingsEntity] but with the given fields
  /// replaced with the new values.
  SettingsEntity copyWith({
    double? weeklyTargetHours,
    List<int>? workdays,
    bool? notificationsEnabled,
    String? notificationTime,
    List<int>? notificationDays,
    bool? notifyWorkStart,
    bool? notifyWorkEnd,
    bool? notifyBreaks,
    bool? warnOnOvertimeThreshold,
    double? overtimeThresholdHours,
    bool? warnOnUndertimeThreshold,
    double? undertimeThresholdHours,
    bool? use24HourFormat,
  }) {
    return SettingsEntity(
      weeklyTargetHours: weeklyTargetHours ?? this.weeklyTargetHours,
      workdays: workdays ?? this.workdays,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      notificationTime: notificationTime ?? this.notificationTime,
      notificationDays: notificationDays ?? this.notificationDays,
      notifyWorkStart: notifyWorkStart ?? this.notifyWorkStart,
      notifyWorkEnd: notifyWorkEnd ?? this.notifyWorkEnd,
      notifyBreaks: notifyBreaks ?? this.notifyBreaks,
      bundesland: bundesland,
      warnOnOvertimeThreshold: warnOnOvertimeThreshold ?? this.warnOnOvertimeThreshold,
      overtimeThresholdHours: overtimeThresholdHours ?? this.overtimeThresholdHours,
      warnOnUndertimeThreshold: warnOnUndertimeThreshold ?? this.warnOnUndertimeThreshold,
      undertimeThresholdHours: undertimeThresholdHours ?? this.undertimeThresholdHours,
      use24HourFormat: use24HourFormat ?? this.use24HourFormat,
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
      workdays: workdays,
      notificationsEnabled: notificationsEnabled,
      notificationTime: notificationTime,
      notificationDays: notificationDays,
      notifyWorkStart: notifyWorkStart,
      notifyWorkEnd: notifyWorkEnd,
      notifyBreaks: notifyBreaks,
      bundesland: bundesland,
      warnOnOvertimeThreshold: warnOnOvertimeThreshold,
      overtimeThresholdHours: overtimeThresholdHours,
      warnOnUndertimeThreshold: warnOnUndertimeThreshold,
      undertimeThresholdHours: undertimeThresholdHours,
      use24HourFormat: use24HourFormat,
    );
  }

  @override
  List<Object?> get props => [
        weeklyTargetHours,
        workdays,
        notificationsEnabled,
        notificationTime,
        notificationDays,
        notifyWorkStart,
        notifyWorkEnd,
        notifyBreaks,
        bundesland,
        warnOnOvertimeThreshold,
        overtimeThresholdHours,
        warnOnUndertimeThreshold,
        undertimeThresholdHours,
        use24HourFormat,
      ];
}
