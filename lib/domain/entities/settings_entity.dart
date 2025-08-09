import 'package:equatable/equatable.dart';

/// Represents the user's settings for the application.
class SettingsEntity extends Equatable {
  /// The target number of work hours per week.
  final double weeklyTargetHours;

  /// The number of workdays in a week.
  final int workdaysPerWeek;

  const SettingsEntity({
    this.weeklyTargetHours = 40.0,
    this.workdaysPerWeek = 5,
  });

  /// Creates a copy of this [SettingsEntity] but with the given fields
  /// replaced with the new values.
  SettingsEntity copyWith({
    double? weeklyTargetHours,
    int? workdaysPerWeek,
  }) {
    return SettingsEntity(
      weeklyTargetHours: weeklyTargetHours ?? this.weeklyTargetHours,
      workdaysPerWeek: workdaysPerWeek ?? this.workdaysPerWeek,
    );
  }

  @override
  List<Object?> get props => [weeklyTargetHours, workdaysPerWeek];
}
