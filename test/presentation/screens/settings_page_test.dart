import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_work_time/domain/entities/settings_entity.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';
import 'package:flutter_work_time/presentation/screens/settings_page.dart';
import 'package:flutter_work_time/presentation/state/settings_state.dart';
import 'package:flutter_work_time/presentation/view_models/auth_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/settings_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/theme_view_model.dart';
import 'package:flutter_work_time/presentation/widgets/add_adjustment_modal.dart';
import 'package:flutter_work_time/domain/usecases/sign_out.dart';
import 'package:flutter_work_time/domain/usecases/delete_account.dart';

import 'settings_page_test.mocks.dart';

// Helper abstract class to verify interactions
abstract class SettingsActions {
  void setTheme(ThemeMode mode);
  Future<void> signOut();
  Future<void> deleteAccount();
  Future<void> updateTargetHours(double hours);
  Future<void> updateWorkdays(int days);
}

@GenerateMocks([SettingsActions, SignOut, DeleteAccount])
void main() {
  late MockSettingsActions mockActions;
  late MockSignOut mockSignOut;
  late MockDeleteAccount mockDeleteAccount;

  setUp(() {
    mockActions = MockSettingsActions();
    mockSignOut = MockSignOut();
    mockDeleteAccount = MockDeleteAccount();

    // Setup delegations
    when(mockSignOut.call()).thenAnswer((_) => mockActions.signOut());
    when(mockDeleteAccount.call()).thenAnswer((_) => mockActions.deleteAccount());
    
    // Default Stubs for actions
    when(mockActions.signOut()).thenAnswer((_) async {});
    when(mockActions.deleteAccount()).thenAnswer((_) async {});
    // Use specific matchers or ignore stubbing if verification is enough
  });

  Widget createSubject({
    required SettingsViewModel settingsViewModel,
    required ThemeViewModel themeViewModel,
    required AsyncValue<UserEntity?> authState,
  }) {
    return ProviderScope(
      overrides: [
        settingsViewModelProvider.overrideWith(() => settingsViewModel),
        themeViewModelProvider.overrideWith(() => themeViewModel),
        authStateProvider.overrideWithValue(authState),
        signOutProvider.overrideWithValue(mockSignOut),
        deleteAccountProvider.overrideWithValue(mockDeleteAccount),
      ],
      child: MaterialApp(
        home: const SettingsPage(),
      ),
    );
  }

  group('SettingsPage Display', () {
    testWidgets('displays current settings correctly', (tester) async {
      final settings = SettingsEntity(
        weeklyTargetHours: 38.5,
        workdaysPerWeek: 4,
      );
      
      final settingsViewModel = FakeSettingsViewModel(
        initialState: AsyncValue.data(SettingsState(
          settings: settings, 
          overtimeBalance: const Duration(hours: 5),
        )),
        actions: mockActions,
      );

      final themeViewModel = FakeThemeViewModel(
        initialState: ThemeMode.system,
        actions: mockActions,
      );

      await tester.pumpWidget(createSubject(
        settingsViewModel: settingsViewModel,
        themeViewModel: themeViewModel,
        authState: const AsyncValue.data(null),
      ));

      expect(find.text('Einstellungen'), findsOneWidget);
      expect(find.text('38.5 h/Woche'), findsOneWidget);
      expect(find.text('4 Tage'), findsOneWidget);
      expect(find.textContaining('9.6 h/Tag'), findsOneWidget);
      
      expect(find.text('Gleitzeit-Bilanz'), findsOneWidget);
      expect(find.text('+05:00'), findsOneWidget);
    });

    testWidgets('shows Login button when not authenticated', (tester) async {
      final settingsViewModel = FakeSettingsViewModel(
        initialState: const AsyncValue.data(SettingsState(
          settings: SettingsEntity(), 
          overtimeBalance: Duration.zero,
        )),
        actions: mockActions,
      );
      final themeViewModel = FakeThemeViewModel(
        initialState: ThemeMode.system,
        actions: mockActions,
      );

      await tester.pumpWidget(createSubject(
        settingsViewModel: settingsViewModel,
        themeViewModel: themeViewModel,
        authState: const AsyncValue.data(null),
      ));

      expect(find.text('Anmelden'), findsOneWidget);
      expect(find.text('Nicht angemeldet'), findsOneWidget);
    });

    testWidgets('shows Profile and Logout button when authenticated', (tester) async {
      final settingsViewModel = FakeSettingsViewModel(
        initialState: const AsyncValue.data(SettingsState(
          settings: SettingsEntity(), 
          overtimeBalance: Duration.zero,
        )),
        actions: mockActions,
      );
      final themeViewModel = FakeThemeViewModel(
        initialState: ThemeMode.system,
        actions: mockActions,
      );

      await tester.pumpWidget(createSubject(
        settingsViewModel: settingsViewModel,
        themeViewModel: themeViewModel,
        authState: const AsyncValue.data(UserEntity(
          id: '1', 
          email: 'test@example.com',
          displayName: 'Max Mustermann'
        )),
      ));

      expect(find.text('Max Mustermann'), findsOneWidget);
      expect(find.text('test@example.com'), findsOneWidget);
      expect(find.text('Abmelden'), findsOneWidget);
    });
  });

  group('SettingsPage Interactions', () {
    testWidgets('toggling theme switch calls setTheme', (tester) async {
      final settingsViewModel = FakeSettingsViewModel(
        initialState: const AsyncValue.data(SettingsState(
          settings: SettingsEntity(),
          overtimeBalance: Duration.zero,
        )),
        actions: mockActions,
      );

      final themeViewModel = FakeThemeViewModel(
        initialState: ThemeMode.light,
        actions: mockActions,
      );
      
      await tester.pumpWidget(createSubject(
        settingsViewModel: settingsViewModel,
        themeViewModel: themeViewModel,
        authState: const AsyncValue.data(null),
      ));

      final switchTileFinder = find.text('Design');
      await tester.scrollUntilVisible(switchTileFinder, 500.0);
      
      await tester.tap(switchTileFinder);
      verify(mockActions.setTheme(ThemeMode.dark)).called(1);
    });

    testWidgets('Logout flow: Open dialog and confirm calls signOut', (tester) async {
      final settingsViewModel = FakeSettingsViewModel(
        initialState: const AsyncValue.data(SettingsState(
          settings: SettingsEntity(), 
          overtimeBalance: Duration.zero,
        )),
        actions: mockActions,
      );
      final themeViewModel = FakeThemeViewModel(
        initialState: ThemeMode.system,
        actions: mockActions,
      );

      await tester.pumpWidget(createSubject(
        settingsViewModel: settingsViewModel,
        themeViewModel: themeViewModel,
        authState: const AsyncValue.data(UserEntity(id: '1', email: 'user@test.com')),
      ));

      await tester.tap(find.text('Abmelden'));
      await tester.pumpAndSettle();

      expect(find.text('Möchten Sie sich wirklich abmelden?'), findsOneWidget);

      final confirmButton = find.widgetWithText(FilledButton, 'Abmelden');
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      verify(mockSignOut.call()).called(1);
    });

    testWidgets('Delete Account flow: Open dialog and confirm calls deleteAccount', (tester) async {
      final settingsViewModel = FakeSettingsViewModel(
        initialState: const AsyncValue.data(SettingsState(
          settings: SettingsEntity(), 
          overtimeBalance: Duration.zero,
        )),
        actions: mockActions,
      );
      final themeViewModel = FakeThemeViewModel(
        initialState: ThemeMode.system,
        actions: mockActions,
      );

      await tester.pumpWidget(createSubject(
        settingsViewModel: settingsViewModel,
        themeViewModel: themeViewModel,
        authState: const AsyncValue.data(UserEntity(id: '1', email: 'user@test.com')),
      ));

      final deleteTile = find.text('Account löschen');
      await tester.scrollUntilVisible(deleteTile, 500);
      await tester.tap(deleteTile);
      await tester.pumpAndSettle();

      expect(find.text('Account endgültig löschen'), findsOneWidget);

      final confirmButton = find.widgetWithText(FilledButton, 'Endgültig löschen');
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      verify(mockDeleteAccount.call()).called(1);
    });

    testWidgets('Edit Target Hours flow: Update value and save', (tester) async {
      final settings = const SettingsEntity(weeklyTargetHours: 40.0);
      
      final settingsViewModel = FakeSettingsViewModel(
        initialState: AsyncValue.data(SettingsState(
          settings: settings, 
          overtimeBalance: Duration.zero
        )),
        actions: mockActions,
      );
      final themeViewModel = FakeThemeViewModel(
        initialState: ThemeMode.system,
        actions: mockActions,
      );

      await tester.pumpWidget(createSubject(
        settingsViewModel: settingsViewModel,
        themeViewModel: themeViewModel,
        authState: const AsyncValue.data(null),
      ));

      await tester.tap(find.text('Soll-Arbeitsstunden'));
      await tester.pumpAndSettle();

      final textField = find.byType(TextFormField);
      await tester.enterText(textField, '35');
      await tester.pump();

      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();

      verify(mockActions.updateTargetHours(35.0)).called(1);
    });

    testWidgets('Edit Workdays flow: Toggle days and save', (tester) async {
      final settings = const SettingsEntity(workdaysPerWeek: 5);
      
      final settingsViewModel = FakeSettingsViewModel(
        initialState: AsyncValue.data(SettingsState(
          settings: settings, 
          overtimeBalance: Duration.zero
        )),
        actions: mockActions,
      );
      final themeViewModel = FakeThemeViewModel(
        initialState: ThemeMode.system,
        actions: mockActions,
      );

      await tester.pumpWidget(createSubject(
        settingsViewModel: settingsViewModel,
        themeViewModel: themeViewModel,
        authState: const AsyncValue.data(null),
      ));

      await tester.tap(find.text('Arbeitstage pro Woche'));
      await tester.pumpAndSettle();

      // Verify Modal Title (which is the same as the list tile, so findsWidgets)
      // We check if we can find the DropdownButton
      expect(find.byType(DropdownButton<int>), findsOneWidget);

      // 2. Open Dropdown
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();

      // 3. Select '4 Tage'
      await tester.tap(find.text('4 Tage').last); // .last because selected item might be duplicated in menu
      await tester.pumpAndSettle();

      // 4. Save
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();

      verify(mockActions.updateWorkdays(4)).called(1);
    });

    testWidgets('Adjust Overtime flow: Open dialog', (tester) async {
      final settingsViewModel = FakeSettingsViewModel(
        initialState: const AsyncValue.data(SettingsState(
          settings: SettingsEntity(), 
          overtimeBalance: Duration.zero
        )),
        actions: mockActions,
      );
      final themeViewModel = FakeThemeViewModel(
        initialState: ThemeMode.system,
        actions: mockActions,
      );

      await tester.pumpWidget(createSubject(
        settingsViewModel: settingsViewModel,
        themeViewModel: themeViewModel,
        authState: const AsyncValue.data(null),
      ));

      final btn = find.text('Überstunden / Minusstunden anpassen');
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(find.byType(AddAdjustmentModal), findsOneWidget);
    });

    testWidgets('tapping notifications opens dialog', (tester) async {
      final settingsViewModel = FakeSettingsViewModel(
        initialState: const AsyncValue.data(SettingsState(
          settings: SettingsEntity(), 
          overtimeBalance: Duration.zero,
        )),
        actions: mockActions,
      );
      final themeViewModel = FakeThemeViewModel(
        initialState: ThemeMode.system,
        actions: mockActions,
      );

      await tester.pumpWidget(createSubject(
        settingsViewModel: settingsViewModel,
        themeViewModel: themeViewModel,
        authState: const AsyncValue.data(null),
      ));

      final notificationTile = find.text('Benachrichtigungen');
      await tester.scrollUntilVisible(notificationTile, 500.0);
      await tester.tap(notificationTile);
      await tester.pumpAndSettle();

      expect(find.text('Benachrichtigungen aktivieren'), findsOneWidget);
    });
  });
}

class FakeSettingsViewModel extends SettingsViewModel {
  final AsyncValue<SettingsState> initialState;
  final SettingsActions actions;

  FakeSettingsViewModel({required this.initialState, required this.actions});

  @override
  AsyncValue<SettingsState> build() {
    return initialState;
  }

  @override
  Future<void> updateWeeklyTargetHours(WidgetRef ref, double hours) async {
    await actions.updateTargetHours(hours);
  }

  @override
  Future<void> updateWorkdaysPerWeek(WidgetRef ref, int days) async {
    await actions.updateWorkdays(days);
  }
}

class FakeThemeViewModel extends ThemeViewModel {
  final ThemeMode initialState;
  final SettingsActions actions;

  FakeThemeViewModel({required this.initialState, required this.actions});

  @override
  ThemeMode build() {
    return initialState;
  }

  @override
  Future<void> setTheme(ThemeMode newMode) async {
    actions.setTheme(newMode);
  }
}
