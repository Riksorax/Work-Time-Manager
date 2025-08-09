import 'package:equatable/equatable.dart';

import '../../domain/entities/work_entry_entity.dart';

class DashboardState extends Equatable {
  final WorkEntryEntity workEntry;
  final Duration elapsedTime;
  final Duration overtimeBalance;
  final Duration? actualWorkDuration; // Neu: Für die Anzeige der finalen Arbeitszeit

  const DashboardState({
    required this.workEntry,
    required this.elapsedTime,
    required this.overtimeBalance,
    this.actualWorkDuration,
  });

  factory DashboardState.initial() {
    return DashboardState(
      workEntry: WorkEntryEntity(
        id: DateTime.now().toIso8601String(),
        date: DateTime.now(),
      ),
      elapsedTime: Duration.zero,
      overtimeBalance: Duration.zero,
      actualWorkDuration: null,
    );
  }

  factory DashboardState.fromWorkEntry(WorkEntryEntity workEntry) {
    Duration finalDuration = Duration.zero;
    if (workEntry.workEnd != null) {
      finalDuration = workEntry.effectiveWorkDuration;
    }

    return DashboardState(
      workEntry: workEntry,
      elapsedTime: finalDuration,
      overtimeBalance: Duration.zero, // Wird im ViewModel separat behandelt
      actualWorkDuration: workEntry.workEnd != null ? finalDuration : null,
    );
  }

  DashboardState copyWith({
    WorkEntryEntity? workEntry,
    Duration? elapsedTime,
    Duration? overtimeBalance,
    Duration? actualWorkDuration,
  }) {
    return DashboardState(
      workEntry: workEntry ?? this.workEntry,
      elapsedTime: elapsedTime ?? this.elapsedTime,
      overtimeBalance: overtimeBalance ?? this.overtimeBalance,
      actualWorkDuration: actualWorkDuration ?? this.actualWorkDuration,
    );
  }

  @override
  List<Object?> get props => [
        workEntry,
        elapsedTime,
        overtimeBalance,
        actualWorkDuration,
      ];
}
