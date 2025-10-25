import 'package:equatable/equatable.dart';

import '../../domain/entities/work_entry_entity.dart';

class DashboardState extends Equatable {
  final WorkEntryEntity workEntry;
  final Duration elapsedTime;
  final Duration? actualWorkDuration;
  final bool isLoading;
  final Duration? overtime;
  final Duration? dailyOvertime;
  final DateTime? expectedEndTime; // Voraussichtliche Feierabendzeit für ±0

  const DashboardState({
    required this.workEntry,
    required this.elapsedTime,
    this.actualWorkDuration,
    this.isLoading = false,
    this.overtime,
    this.dailyOvertime,
    this.expectedEndTime,
  });

  factory DashboardState.initial() {
    return DashboardState(
      workEntry: WorkEntryEntity(
        id: DateTime.now().toIso8601String(),
        date: DateTime.now(),
      ),
      elapsedTime: Duration.zero,
      actualWorkDuration: null,
      isLoading: true, // Start with loading
      overtime: null,
      dailyOvertime: null,
      expectedEndTime: null,
    );
  }

  DashboardState copyWith({
    WorkEntryEntity? workEntry,
    Duration? elapsedTime,
    Duration? actualWorkDuration,
    bool? isLoading,
    Duration? overtime,
    Duration? dailyOvertime,
    DateTime? expectedEndTime,
  }) {
    return DashboardState(
      workEntry: workEntry ?? this.workEntry,
      elapsedTime: elapsedTime ?? this.elapsedTime,
      actualWorkDuration: actualWorkDuration ?? this.actualWorkDuration,
      isLoading: isLoading ?? this.isLoading,
      overtime: overtime ?? this.overtime,
      dailyOvertime: dailyOvertime ?? this.dailyOvertime,
      expectedEndTime: expectedEndTime ?? this.expectedEndTime,
    );
  }

  @override
  List<Object?> get props => [
        workEntry,
        elapsedTime,
        actualWorkDuration,
        isLoading,
        overtime,
        dailyOvertime,
        expectedEndTime,
      ];
}
