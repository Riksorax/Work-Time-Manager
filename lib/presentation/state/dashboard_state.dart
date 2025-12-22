import 'package:equatable/equatable.dart';

import '../../domain/entities/work_entry_entity.dart';

class DashboardState extends Equatable {
  final WorkEntryEntity workEntry;
  final Duration elapsedTime;
  final Duration? actualWorkDuration;
  final bool isLoading;
  final Duration? totalOvertime;
  final Duration? initialOvertime; // Überstundenstand zu Beginn des Tages/Session
  final Duration? dailyOvertime;
  final Duration? grossWorkDuration; // Brutto-Arbeitszeit (inkl. Pausen)
  final DateTime? expectedEndTime; // Voraussichtliche Feierabendzeit für ±0

  const DashboardState({
    required this.workEntry,
    required this.elapsedTime,
    this.actualWorkDuration,
    this.isLoading = false,
    this.totalOvertime,
    this.initialOvertime,
    this.dailyOvertime,
    this.grossWorkDuration,
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
      totalOvertime: null,
      initialOvertime: null,
      dailyOvertime: null,
      grossWorkDuration: null,
      expectedEndTime: null,
    );
  }

  DashboardState copyWith({
    WorkEntryEntity? workEntry,
    Duration? elapsedTime,
    Duration? actualWorkDuration,
    bool? isLoading,
    Duration? totalOvertime,
    Duration? initialOvertime,
    Duration? dailyOvertime,
    Duration? grossWorkDuration,
    DateTime? expectedEndTime,
  }) {
    return DashboardState(
      workEntry: workEntry ?? this.workEntry,
      elapsedTime: elapsedTime ?? this.elapsedTime,
      actualWorkDuration: actualWorkDuration ?? this.actualWorkDuration,
      isLoading: isLoading ?? this.isLoading,
      totalOvertime: totalOvertime ?? this.totalOvertime,
      initialOvertime: initialOvertime ?? this.initialOvertime,
      dailyOvertime: dailyOvertime ?? this.dailyOvertime,
      grossWorkDuration: grossWorkDuration ?? this.grossWorkDuration,
      expectedEndTime: expectedEndTime ?? this.expectedEndTime,
    );
  }

  @override
  List<Object?> get props => [
        workEntry,
        elapsedTime,
        actualWorkDuration,
        isLoading,
        totalOvertime,
        initialOvertime,
        dailyOvertime,
        grossWorkDuration,
        expectedEndTime,
      ];
}
