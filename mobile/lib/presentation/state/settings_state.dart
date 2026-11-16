import 'package:equatable/equatable.dart';

import '../../domain/entities/overtime_freshness.dart';
import '../../domain/entities/settings_entity.dart';

class SettingsState extends Equatable {
  final SettingsEntity settings;

  /// Gleitzeit-Saldo; `null` = unbekannt (angemeldet ohne Netz und ohne
  /// gemerkten Stand, #573). Nie als 0 anzeigen.
  final Duration? overtimeBalance;
  final DateTime? lastOvertimeUpdate; // Datum der letzten manuellen Änderung

  /// Herkunft des Saldos (#573): `cached` = zuletzt bekannter Stand ohne Netz.
  final OvertimeFreshness overtimeFreshness;
  final bool isLoading;

  const SettingsState({
    required this.settings,
    required this.overtimeBalance,
    this.lastOvertimeUpdate,
    this.overtimeFreshness = OvertimeFreshness.current,
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
    OvertimeFreshness? overtimeFreshness,
    bool? isLoading,
  }) {
    return SettingsState(
      settings: settings ?? this.settings,
      overtimeBalance: overtimeBalance ?? this.overtimeBalance,
      lastOvertimeUpdate: lastOvertimeUpdate ?? this.lastOvertimeUpdate,
      overtimeFreshness: overtimeFreshness ?? this.overtimeFreshness,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [
        settings,
        overtimeBalance,
        lastOvertimeUpdate,
        overtimeFreshness,
        isLoading
      ];
}
