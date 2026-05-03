import 'package:equatable/equatable.dart';

import '../../domain/entities/settings_entity.dart';

class SettingsState extends Equatable {
  final SettingsEntity settings;
  final Duration overtimeBalance;
  final DateTime? lastOvertimeUpdate; // Datum der letzten manuellen Änderung
  final bool isLoading;

  const SettingsState({
    required this.settings,
    required this.overtimeBalance,
    this.lastOvertimeUpdate,
    this.isLoading = false,
  });

  factory SettingsState.initial() {
    return SettingsState(
      settings: const SettingsEntity(),
      overtimeBalance: Duration.zero,
      lastOvertimeUpdate: null,
      isLoading: true,
    );
  }

  SettingsState copyWith({
    SettingsEntity? settings,
    Duration? overtimeBalance,
    DateTime? lastOvertimeUpdate,
    bool? isLoading,
  }) {
    return SettingsState(
      settings: settings ?? this.settings,
      overtimeBalance: overtimeBalance ?? this.overtimeBalance,
      lastOvertimeUpdate: lastOvertimeUpdate ?? this.lastOvertimeUpdate,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [settings, overtimeBalance, lastOvertimeUpdate, isLoading];
}
