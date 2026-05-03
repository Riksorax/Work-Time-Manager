import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_work_time/domain/entities/settings_entity.dart';
import 'package:flutter_work_time/presentation/state/settings_state.dart';
import 'package:flutter_work_time/presentation/view_models/settings_view_model.dart';
import 'package:flutter_work_time/presentation/widgets/common/edit_soll_arbeitsstunden_dialog.dart';
import 'package:flutter_work_time/presentation/widgets/common/add_manual_time_dialog.dart';

import 'dialogs_test.mocks.dart';

abstract class DialogActions {
  void updateWeeklyTargetHours(double hours);
}

@GenerateMocks([DialogActions])
void main() {
  late MockDialogActions mockActions;

  setUp(() {
    mockActions = MockDialogActions();
  });

  group('Dialog Widgets', () {
    testWidgets('EditSollArbeitsstundenDialog shows initial value and saves', (tester) async {
      final settingsViewModel = FakeSettingsViewModel(
        initialState: const AsyncValue.data(SettingsState(
          settings: SettingsEntity(weeklyTargetHours: 40.0),
          overtimeBalance: Duration.zero,
        )),
        actions: mockActions,
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [
          settingsViewModelProvider.overrideWith(() => settingsViewModel),
        ],
        child: const MaterialApp(
          home: Scaffold(body: EditSollArbeitsstundenDialog()),
        ),
      ));

      // Check initial value
      expect(find.text('40.0'), findsOneWidget);

      // Enter new value
      await tester.enterText(find.byType(TextField), '38');
      
      // Save
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();

      verify(mockActions.updateWeeklyTargetHours(38.0)).called(1);
    });

    testWidgets('AddManualTimeDialog shows all fields', (tester) async {
      await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: AddManualTimeDialog()),
        ),
      ));

      expect(find.text('Manuelle Zeitkorrektur'), findsOneWidget);
      expect(find.text('Dauer (HH:mm)'), findsOneWidget);
      expect(find.text('Grund'), findsOneWidget);
      expect(find.byType(DropdownButton<bool>), findsOneWidget);
    });

    testWidgets('AddManualTimeDialog validates input', (tester) async {
      await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: AddManualTimeDialog()),
        ),
      ));

      // Tap save without input
      await tester.tap(find.text('Speichern'));
      await tester.pump();

      expect(find.text('Bitte geben Sie eine Dauer an.'), findsOneWidget);
      expect(find.text('Bitte geben Sie einen Grund an.'), findsOneWidget);

      // Enter invalid format
      await tester.enterText(find.widgetWithText(TextFormField, 'Dauer (HH:mm)'), 'invalid');
      await tester.tap(find.text('Speichern'));
      await tester.pump();
      expect(find.text('Ungültiges Format (HH:mm).'), findsOneWidget);
    });
  });
}

// Re-using the Fake from previous tests or creating local one
class FakeSettingsViewModel extends SettingsViewModel {
  final AsyncValue<SettingsState> initialState;
  final MockDialogActions actions;

  FakeSettingsViewModel({required this.initialState, required this.actions});

  @override
  AsyncValue<SettingsState> build() {
    return initialState;
  }

  @override
  Future<void> updateWeeklyTargetHours(WidgetRef ref, double hours) async {
    actions.updateWeeklyTargetHours(hours);
  }
}
