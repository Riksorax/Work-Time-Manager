import 'package:flutter/foundation.dart';

@immutable
class SettingsState {
  final String? userName;
  final String? appVersion;
  final double? targetHours; // Hinzugefügt

  const SettingsState({
    this.userName,
    this.appVersion,
    this.targetHours, // Hinzugefügt
  });

  SettingsState copyWith({
    String? userName,
    String? appVersion,
    double? targetHours, // Hinzugefügt
  }) {
    return SettingsState(
      userName: userName ?? this.userName,
      appVersion: appVersion ?? this.appVersion,
      targetHours: targetHours ?? this.targetHours, // Hinzugefügt
    );
  }
}
