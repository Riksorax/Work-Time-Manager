import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/entities/break_entity.dart';
import '../../../domain/entities/work_entry_entity.dart';
import '../../../domain/repositories/work_repository.dart';
import '../../core/providers/providers.dart' hide workRepositoryProvider;
import '../state/edit_work_entry_state.dart';
import 'dashboard_view_model.dart';

final editWorkEntryViewModelProvider = StateNotifierProvider.autoDispose
    .family<EditWorkEntryViewModel, EditWorkEntryState, WorkEntryEntity>(
        (ref, entry) {
  final workRepositoryAsync = ref.watch(workRepositoryProvider);

  // We can only create the ViewModel when the repository is successfully loaded.
  final workRepository = workRepositoryAsync.asData?.value;

  if (workRepository == null) {
    // This is a temporary state until the FutureProvider resolves.
    // The ViewModel requires a non-null repository.
    // A better approach is for the UI to handle the loading state of workRepositoryProvider.
    // For now, we create a dummy repository that will be replaced.
    return EditWorkEntryViewModel(const DummyWorkRepository(), entry);
  }
  return EditWorkEntryViewModel(workRepository, entry);
});

class EditWorkEntryViewModel extends StateNotifier<EditWorkEntryState> {
  final WorkRepository _workRepository;
  final Uuid _uuid = const Uuid();

  EditWorkEntryViewModel(this._workRepository, WorkEntryEntity entry)
      : super(EditWorkEntryState.fromWorkEntry(entry));

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
    // Prevent saving with the dummy repository
    if (_workRepository is DummyWorkRepository) return;
    if (state.newStartTime == null) return;

    final updatedEntry = state.originalEntry.copyWith(
      workStart: state.newStartTime,
      workEnd: state.newEndTime,
      breaks: state.breaks,
    );
    await _workRepository.saveWorkEntry(updatedEntry);
  }
}
