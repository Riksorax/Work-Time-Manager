import 'package:equatable/equatable.dart';

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

  const SettingsEntity({
    this.weeklyTargetHours = 40.0,
    this.workdaysPerWeek = 5,
    this.notificationsEnabled = false,
    this.notificationTime = '18:00',
    this.notificationDays = const [1, 2, 3, 4, 5], // Monday to Friday
    this.notifyWorkStart = true,
    this.notifyWorkEnd = true,
    this.notifyBreaks = true,
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
      ];
}
