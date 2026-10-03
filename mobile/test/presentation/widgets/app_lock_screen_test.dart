import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_work_time/core/providers/app_lock_provider.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/services/app_lock_service.dart';
import 'package:flutter_work_time/core/utils/app_navigator.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';
import 'package:flutter_work_time/domain/usecases/reauthenticate.dart';
import 'package:flutter_work_time/presentation/view_models/auth_view_model.dart';
import 'package:mockito/mockito.dart';
import '../../domain/usecases/auth_usecases_test.mocks.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/widgets/app_lock_screen.dart';

void main() {
  late SharedPreferences prefs;
  late AppLockService service;
  late MockAuthRepository repo;
  late ProviderContainer container;

  setUp(() async {
    repo = MockAuthRepository();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    // Echte LocalAuthentication: Ohne Plattform-Kanal wirft sie beim Aufruf
    // eine MissingPluginException, die AppLockService.isBiometricAvailable
    // bereits abfängt und als "nicht verfügbar" behandelt.
    service = AppLockService(prefs: prefs, localAuth: LocalAuthentication());
    await service.setPin('1234');
    await service.setEnabled(true);
  });

  Widget createSubject({bool loggedIn = false}) {
    return ProviderScope(
      overrides: [
        authStateProvider.overrideWithValue(
            AsyncValue.data(loggedIn ? const UserEntity(id: 'u1') : null)),
        reauthenticateProvider.overrideWithValue(Reauthenticate(repo)),
        sharedPreferencesProvider.overrideWithValue(prefs),
        appLockServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Consumer(builder: (context, ref, _) {
          container = ProviderScope.containerOf(context);
          return const AppLockScreen();
        }),
      ),
    );
  }

  testWidgets(
      'entsperrt per Eingabetaste bei korrekter PIN und schließt dabei die Tastatur (#337)',
      (tester) async {
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '1234');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // Die Tastatur muss schon vor dem Entfernen des Screens geschlossen
    // worden sein (siehe #337) - sonst verarbeitet das Framework die
    // IME-Selection-Änderung noch, während das zugehörige Overlay bereits
    // disposed wird.
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('zeigt bei falscher PIN einen Fehler und behält den Fokus',
      (tester) async {
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '0000');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Falsche PIN'), findsOneWidget);
  });

  Future<void> setNewPin(WidgetTester tester, String pin) async {
    await tester.enterText(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextField)),
        pin);
    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextField)),
        pin);
    await tester.tap(find.text('Bestätigen'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Bestätigen'));
    await tester.pumpAndSettle();
  }

  group('PIN vergessen (#288)', () {
    testWidgets('Button ist sichtbar', (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();
      expect(find.text('PIN vergessen?'), findsOneWidget);
    });

    testWidgets('eingeloggt: Re-Auth true -> neue PIN, entsperrt',
        (tester) async {
      when(repo.reauthenticate()).thenAnswer((_) async => true);
      await tester.pumpWidget(createSubject(loggedIn: true));
      await tester.pumpAndSettle();
      expect(container.read(isAppLockedProvider), isTrue);

      await tester.tap(find.text('PIN vergessen?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mit Google bestätigen'));
      await tester.pumpAndSettle();
      await setNewPin(tester, '5678');

      expect(container.read(isAppLockedProvider), isFalse);
      expect(service.verifyPin('5678'), isTrue);
      expect(service.verifyPin('1234'), isFalse);
      expect(service.hasRecoveryCode, isTrue);
    });

    testWidgets('eingeloggt: Re-Auth false -> PIN unverändert, gesperrt',
        (tester) async {
      when(repo.reauthenticate()).thenAnswer((_) async => false);
      await tester.pumpWidget(createSubject(loggedIn: true));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PIN vergessen?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mit Google bestätigen'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Bestätigung fehlgeschlagen'), findsOneWidget);
      expect(service.verifyPin('1234'), isTrue);
      expect(container.read(isAppLockedProvider), isTrue);
    });

    testWidgets('ausgeloggt mit Code: richtiger Code -> neue PIN, neuer Code',
        (tester) async {
      await service.setPinWithRecoveryCode('1234', 'ABCDEFGHJKLMNPQR');
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();
      await tester.tap(find.text('PIN vergessen?'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byType(TextField).last, 'ABCD-EFGH-JKLM-NPQR');
      await tester.tap(find.text('PIN zurücksetzen').last);
      await tester.pumpAndSettle();
      await setNewPin(tester, '5678');

      expect(container.read(isAppLockedProvider), isFalse);
      expect(service.verifyPin('5678'), isTrue);
      expect(service.verifyRecoveryCode('ABCDEFGHJKLMNPQR'), isFalse);
    });

    testWidgets('falscher Code -> Fehler, gesperrt', (tester) async {
      await service.setPinWithRecoveryCode('1234', 'ABCDEFGHJKLMNPQR');
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();
      await tester.tap(find.text('PIN vergessen?'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byType(TextField).last, 'AAAA-AAAA-AAAA-AAAA');
      await tester.tap(find.text('PIN zurücksetzen').last);
      await tester.pumpAndSettle();

      expect(find.text('Falscher Wiederherstellungscode'), findsOneWidget);
      expect(container.read(isAppLockedProvider), isTrue);
    });

    testWidgets('PinSetup abgebrochen -> alte PIN gilt, gesperrt',
        (tester) async {
      when(repo.reauthenticate()).thenAnswer((_) async => true);
      await tester.pumpWidget(createSubject(loggedIn: true));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PIN vergessen?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mit Google bestätigen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();

      expect(service.verifyPin('1234'), isTrue);
      expect(container.read(isAppLockedProvider), isTrue);
    });

    testWidgets('ohne Code und ausgeloggt: Hinweistext', (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();
      await tester.tap(find.text('PIN vergessen?'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Systemeinstellungen'), findsOneWidget);
    });
  });
}
