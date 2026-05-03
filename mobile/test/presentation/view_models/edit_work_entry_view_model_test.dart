import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/presentation/view_models/edit_work_entry_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/reports_view_model.dart';
import 'package:flutter_work_time/presentation/state/reports_state.dart';

import 'edit_work_entry_view_model_test.mocks.dart';

// Helper to capture the call
abstract class SaveWorkEntryCallback {
  void call(WorkEntryEntity entry);
}

@GenerateMocks([SaveWorkEntryCallback])
void main() {
  late MockSaveWorkEntryCallback mockCallback;
  late ProviderContainer container;

  final baseDate = DateTime(2023, 10, 26);
  final initialEntry = WorkEntryEntity(
    id: '1',
    date: baseDate,
    workStart: DateTime(2023, 10, 26, 8, 0),
    workEnd: DateTime(2023, 10, 26, 16, 0),
    type: WorkEntryType.work,
  );

  setUp(() {
    mockCallback = MockSaveWorkEntryCallback();
    container = ProviderContainer(
      overrides: [
        reportsViewModelProvider.overrideWith(() => FakeReportsViewModel(mockCallback)),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('EditWorkEntryViewModel', () {
    test('initial state should be derived from work entry', () {
      final state = container.read(editWorkEntryViewModelProvider(initialEntry));

      expect(state.type, WorkEntryType.work);
      expect(state.newStartTime, initialEntry.workStart);
      expect(state.newEndTime, initialEntry.workEnd);
    });

    test('setType should update type', () {
      final viewModel = container.read(editWorkEntryViewModelProvider(initialEntry).notifier);
      viewModel.setType(WorkEntryType.sick);
      
      final state = container.read(editWorkEntryViewModelProvider(initialEntry));
      expect(state.type, WorkEntryType.sick);
    });

    test('addBreak should add a new break to the list', () {
      final viewModel = container.read(editWorkEntryViewModelProvider(initialEntry).notifier);
      viewModel.addBreak();
      
      final state = container.read(editWorkEntryViewModelProvider(initialEntry));
      expect(state.breaks.length, 1);
      expect(state.breaks.first.name, contains('#1'));
    });

    test('updateBreak should modify existing break', () {
      final viewModel = container.read(editWorkEntryViewModelProvider(initialEntry).notifier);
      viewModel.addBreak();
      final breakId = container.read(editWorkEntryViewModelProvider(initialEntry)).breaks.first.id;
      
      final newStart = DateTime(2023, 10, 26, 12, 0);
      viewModel.updateBreak(breakId, newName: 'Lunch', newStart: newStart);
      
      final state = container.read(editWorkEntryViewModelProvider(initialEntry));
      expect(state.breaks.first.name, 'Lunch');
      expect(state.breaks.first.start, newStart);
    });

    test('deleteBreak should remove break from list', () {
      final viewModel = container.read(editWorkEntryViewModelProvider(initialEntry).notifier);
      viewModel.addBreak();
      final breakId = container.read(editWorkEntryViewModelProvider(initialEntry)).breaks.first.id;
      
      viewModel.deleteBreak(breakId);
      
      final state = container.read(editWorkEntryViewModelProvider(initialEntry));
      expect(state.breaks, isEmpty);
    });

    test('saveChanges should call reportsViewModel.saveWorkEntry with updated data', () async {
      final viewModel = container.read(editWorkEntryViewModelProvider(initialEntry).notifier);
      
      final newStartTime = DateTime(2023, 10, 26, 7, 30);
      viewModel.setStartTime(newStartTime);
      
      await viewModel.saveChanges();
      
      final captured = verify(mockCallback.call(captureAny)).captured.single as WorkEntryEntity;
      expect(captured.workStart, newStartTime);
      expect(captured.isManuallyEntered, true);
    });

    test('saveChanges should not save if work start is missing for type work', () async {
      final entryWithoutStart = WorkEntryEntity(id: '2', date: baseDate, workStart: null);
      final viewModel = container.read(editWorkEntryViewModelProvider(entryWithoutStart).notifier);
      
      await viewModel.saveChanges();
      
      verifyNever(mockCallback.call(any));
    });
  });
}

class FakeReportsViewModel extends ReportsViewModel {
  final SaveWorkEntryCallback onSave;

  FakeReportsViewModel(this.onSave);

  @override
  ReportsState build() {
    return ReportsState.initial();
  }

  @override
  Future<void> saveWorkEntry(WorkEntryEntity entry) async {
    onSave.call(entry);
  }
}
