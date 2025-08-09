import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/break_entity.dart';
import '../../domain/entities/work_entry_entity.dart';

@immutable
class DashboardState extends Equatable {
  final bool isTimerRunning;
  final DateTime? startTime;
  final DateTime? manualStartTime;
  final DateTime? manualEndTime;
  final Duration elapsedTime;
  final List<BreakEntity> breaks;
  final int? manualAdjustmentMinutes;

  const DashboardState({
    required this.isTimerRunning,
    this.startTime,
    this.manualStartTime,
    this.manualEndTime,
    required this.elapsedTime,
    required this.breaks,
    this.manualAdjustmentMinutes,
  });

  factory DashboardState.initial() {
    return const DashboardState(
      isTimerRunning: false,
      startTime: null,
      manualStartTime: null,
      manualEndTime: null,
      elapsedTime: Duration.zero,
      breaks: [],
      manualAdjustmentMinutes: null,
    );
  }

  /// Creates a DashboardState from a WorkEntryEntity.
  /// This is used to restore the state from the repository.
  factory DashboardState.fromWorkEntry(WorkEntryEntity entry) {
    // The timer is running if the entry has a start time but no end time.
    final isTimerRunning = entry.workStart != null && entry.workEnd == null;
    return DashboardState(
      isTimerRunning: isTimerRunning,
      startTime: entry.workStart,
      // We set the manual start time to the start time of the entry.
      manualStartTime: entry.workStart,
      // The manual end time is the end time of the entry.
      manualEndTime: entry.workEnd,
      // We will calculate the elapsed time in the view model.
      elapsedTime: Duration.zero,
      breaks: entry.breaks,
      manualAdjustmentMinutes: entry.manualOvertime?.inMinutes,
    );
  }

  DashboardState copyWith({
    bool? isTimerRunning,
    DateTime? startTime,
    DateTime? manualStartTime,
    // We need to be able to explicitly set manualEndTime to null
    ValueGetter<DateTime?>? manualEndTime,
    Duration? elapsedTime,
    List<BreakEntity>? breaks,
    int? manualAdjustmentMinutes,
  }) {
    return DashboardState(
      isTimerRunning: isTimerRunning ?? this.isTimerRunning,
      startTime: startTime ?? this.startTime,
      manualStartTime: manualStartTime ?? this.manualStartTime,
      manualEndTime: manualEndTime != null ? manualEndTime() : this.manualEndTime,
      elapsedTime: elapsedTime ?? this.elapsedTime,
      breaks: breaks ?? this.breaks,
      manualAdjustmentMinutes: manualAdjustmentMinutes ?? this.manualAdjustmentMinutes,
    );
  }

  @override
  List<Object?> get props => [
        isTimerRunning,
        startTime,
        manualStartTime,
        manualEndTime,
        elapsedTime,
        breaks,
        manualAdjustmentMinutes,
      ];
}
