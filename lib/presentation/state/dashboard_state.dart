import 'package:equatable/equatable.dart';

import '../../domain/entities/work_entry_entity.dart';

class DashboardState extends Equatable {
  final WorkEntryEntity workEntry;
  final Duration elapsedTime;
  final Duration overtimeBalance;
  final Duration? actualWorkDuration;
  final Duration? totalBalance;
  final bool isLoading;

  const DashboardState({
    required this.workEntry,
    required this.elapsedTime,
    required this.overtimeBalance,
    this.actualWorkDuration,
    this.totalBalance,
    this.isLoading = false,
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
      isLoading: true, // Start with loading
    );
  }

  DashboardState copyWith({
    WorkEntryEntity? workEntry,
    Duration? elapsedTime,
    Duration? overtimeBalance,
    Duration? actualWorkDuration,
    Duration? totalBalance,
    bool? isLoading,
  }) {
    return DashboardState(
      workEntry: workEntry ?? this.workEntry,
      elapsedTime: elapsedTime ?? this.elapsedTime,
      overtimeBalance: overtimeBalance ?? this.overtimeBalance,
      actualWorkDuration: actualWorkDuration ?? this.actualWorkDuration,
      totalBalance: totalBalance ?? this.totalBalance,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [
        workEntry,
        elapsedTime,
        overtimeBalance,
        actualWorkDuration,
        totalBalance,
        isLoading,
      ];
}
