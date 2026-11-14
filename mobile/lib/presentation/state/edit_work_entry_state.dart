import 'package:equatable/equatable.dart';

import '../../../domain/entities/break_entity.dart';
import '../../../domain/entities/work_entry_entity.dart';
import '../../../domain/utils/work_locations.dart';

class EditWorkEntryState extends Equatable {
  final WorkEntryEntity originalEntry;
  final DateTime? newStartTime;
  final DateTime? newEndTime;
  final List<BreakEntity> breaks;
  final WorkEntryType type;
  final bool isHomeOffice;

  /// Arbeitsorte im Dialog (#526), bereinigt; nur bei Typ Arbeit bearbeitbar.
  final List<String> workLocations;

  const EditWorkEntryState({
    required this.originalEntry,
    this.newStartTime,
    this.newEndTime,
    required this.breaks,
    required this.type,
    this.isHomeOffice = false,
    this.workLocations = const [],
  });

  factory EditWorkEntryState.fromWorkEntry(WorkEntryEntity entry) {
    return EditWorkEntryState(
      originalEntry: entry,
      newStartTime: entry.workStart,
      newEndTime: entry.workEnd,
      breaks: entry.breaks,
      type: entry.type,
      isHomeOffice: entry.isHomeOffice,
      workLocations: normalizeWorkLocations(entry.workLocations),
    );
  }

  EditWorkEntryState copyWith({
    DateTime? newStartTime,
    DateTime? newEndTime,
    List<BreakEntity>? breaks,
    WorkEntryType? type,
    bool? isHomeOffice,
    List<String>? workLocations,
  }) {
    return EditWorkEntryState(
      originalEntry: originalEntry,
      newStartTime: newStartTime ?? this.newStartTime,
      newEndTime: newEndTime ?? this.newEndTime,
      breaks: breaks ?? this.breaks,
      type: type ?? this.type,
      isHomeOffice: isHomeOffice ?? this.isHomeOffice,
      workLocations: workLocations ?? this.workLocations,
    );
  }

  @override
  List<Object?> get props => [
        originalEntry,
        newStartTime,
        newEndTime,
        breaks,
        type,
        isHomeOffice,
        workLocations,
      ];
}
