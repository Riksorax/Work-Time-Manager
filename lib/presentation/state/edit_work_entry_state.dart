import 'package:equatable/equatable.dart';

import '../../../domain/entities/break_entity.dart';
import '../../../domain/entities/work_entry_entity.dart';

class EditWorkEntryState extends Equatable {
  final WorkEntryEntity originalEntry;
  final DateTime? newStartTime;
  final DateTime? newEndTime;
  final List<BreakEntity> breaks;
  final WorkEntryType type;

  const EditWorkEntryState({
    required this.originalEntry,
    this.newStartTime,
    this.newEndTime,
    required this.breaks,
    required this.type,
  });

  factory EditWorkEntryState.fromWorkEntry(WorkEntryEntity entry) {
    return EditWorkEntryState(
      originalEntry: entry,
      newStartTime: entry.workStart,
      newEndTime: entry.workEnd,
      breaks: entry.breaks,
      type: entry.type,
    );
  }

  EditWorkEntryState copyWith({
    DateTime? newStartTime,
    DateTime? newEndTime,
    List<BreakEntity>? breaks,
    WorkEntryType? type,
  }) {
    return EditWorkEntryState(
      originalEntry: originalEntry,
      newStartTime: newStartTime ?? this.newStartTime,
      newEndTime: newEndTime ?? this.newEndTime,
      breaks: breaks ?? this.breaks,
      type: type ?? this.type,
    );
  }

  @override
  List<Object?> get props => [originalEntry, newStartTime, newEndTime, breaks, type];
}
