import 'package:equatable/equatable.dart';

import '../../domain/entities/settings_entity.dart';

class SettingsState extends Equatable {
  final SettingsEntity settings;
  final Duration overtimeBalance;
  final bool isLoading;

  const SettingsState({
    required this.settings,
    required this.overtimeBalance,
    this.isLoading = false,
  });

  factory SettingsState.initial() {
    return SettingsState(
      settings: const SettingsEntity(),
      overtimeBalance: Duration.zero,
      isLoading: true,
    );
  }

  SettingsState copyWith({
    SettingsEntity? settings,
    Duration? overtimeBalance,
    bool? isLoading,
  }) {
    return SettingsState(
      settings: settings ?? this.settings,
      overtimeBalance: overtimeBalance ?? this.overtimeBalance,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [settings, overtimeBalance, isLoading];
}
