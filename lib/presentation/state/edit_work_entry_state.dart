import 'package:equatable/equatable.dart';

import '../../../domain/entities/break_entity.dart';
import '../../../domain/entities/work_entry_entity.dart';

class EditWorkEntryState extends Equatable {
  final WorkEntryEntity originalEntry;
  final DateTime? newStartTime;
  final DateTime? newEndTime;
  final List<BreakEntity> breaks;

  const EditWorkEntryState({
    required this.originalEntry,
    this.newStartTime,
    this.newEndTime,
    required this.breaks,
  });

  factory EditWorkEntryState.fromWorkEntry(WorkEntryEntity entry) {
    return EditWorkEntryState(
      originalEntry: entry,
      newStartTime: entry.workStart,
      newEndTime: entry.workEnd,
      breaks: entry.breaks,
    );
  }

  EditWorkEntryState copyWith({
    DateTime? newStartTime,
    DateTime? newEndTime,
    List<BreakEntity>? breaks,
  }) {
    return EditWorkEntryState(
      originalEntry: originalEntry,
      newStartTime: newStartTime ?? this.newStartTime,
      newEndTime: newEndTime ?? this.newEndTime,
      breaks: breaks ?? this.breaks,
    );
  }

  @override
  List<Object?> get props => [originalEntry, newStartTime, newEndTime, breaks];
}
