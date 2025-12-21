import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/break_entity.dart';
import '../../domain/entities/work_entry_entity.dart';
import '../state/edit_work_entry_state.dart';
import 'reports_view_model.dart';

final editWorkEntryViewModelProvider = StateNotifierProvider.autoDispose
    .family<EditWorkEntryViewModel, EditWorkEntryState, WorkEntryEntity>(
        (ref, entry) {
  return EditWorkEntryViewModel(entry, ref);
});

class EditWorkEntryViewModel extends StateNotifier<EditWorkEntryState> {
  final Uuid _uuid = const Uuid();
  final Ref _ref;

  EditWorkEntryViewModel(WorkEntryEntity entry, this._ref)
      : super(EditWorkEntryState.fromWorkEntry(entry));

  void setType(WorkEntryType type) {
    state = state.copyWith(type: type);
  }

  void setStartTime(DateTime startTime) {
    state = state.copyWith(newStartTime: startTime);
  }

  void setEndTime(DateTime? endTime) {
    state = state.copyWith(newEndTime: endTime);
  }

  void addBreak() {
    final newBreak = BreakEntity(
      id: _uuid.v4(),
      name: 'Pause #${state.breaks.length + 1}',
      start: state.newStartTime ?? DateTime.now(),
      end: (state.newStartTime ?? DateTime.now())
          .add(const Duration(minutes: 30)),
    );
    state = state.copyWith(breaks: [...state.breaks, newBreak]);
  }

  void updateBreak(
    String breakId, {
    DateTime? newStart,
    DateTime? newEnd,
    String? newName,
  }) {
    final updatedBreaks = state.breaks.map((b) {
      if (b.id == breakId) {
        return b.copyWith(
          start: newStart ?? b.start,
          end: newEnd ?? b.end,
          name: newName ?? b.name,
        );
      }
      return b;
    }).toList();

    state = state.copyWith(breaks: updatedBreaks);
  }

  void deleteBreak(String breakId) {
    final updatedBreaks =
        state.breaks.where((b) => b.id != breakId).toList();
    state = state.copyWith(breaks: updatedBreaks);
  }

  Future<void> saveChanges() async {
    // Wenn Typ 'work' ist, MUSS eine Startzeit existieren.
    if (state.type == WorkEntryType.work && state.newStartTime == null) return;

    final isStandardWork = state.type == WorkEntryType.work;

    final updatedEntry = state.originalEntry.copyWith(
      workStart: isStandardWork ? state.newStartTime : null,
      workEnd: isStandardWork ? state.newEndTime : null,
      breaks: isStandardWork ? state.breaks : [],
      type: state.type,
      // ManuallyEntered ist true, wenn wir hier speichern.
      isManuallyEntered: true,
    );
    await _ref.read(reportsViewModelProvider.notifier).saveWorkEntry(updatedEntry);
  }
}
