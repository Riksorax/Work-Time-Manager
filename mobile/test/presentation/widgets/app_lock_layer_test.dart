import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_work_time/core/providers/app_lock_provider.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/services/app_lock_service.dart';
import 'package:flutter_work_time/core/services/app_lock_store.dart';
import 'package:flutter_work_time/core/utils/app_navigator.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';
import 'package:flutter_work_time/domain/usecases/reauthenticate.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/view_models/auth_view_model.dart';
import 'package:flutter_work_time/presentation/widgets/app_lock_layer.dart';
import 'package:flutter_work_time/presentation/widgets/app_lock_screen.dart';
import 'package:flutter_work_time/presentation/widgets/forgot_pin_dialog.dart';

import '../../domain/usecases/auth_usecases_test.mocks.dart';
import '../../support/fake_app_lock_backend.dart';

class _FakeLocalAuth extends Fake implements LocalAuthentication {
  @override
  Future<bool> get canCheckBiometrics async => true;

  @override
  Future<bool> isDeviceSupported() async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      invocation.memberName == #authenticate
          ? Future<bool>.value(true)
          : super.noSuchMethod(invocation);
}

/// Regression #450: Der Sperrbildschirm liegt in `MaterialApp.builder` über dem
/// App-Navigator. Dialoge von dort müssen sichtbar und bedienbar sein.
void main() {
  late SharedPreferences prefs;
  late FakeAppLockBackend backend;
  late AppLockStore store;
  late AppLockService service;
  late MockAuthRepository repo;
  late ProviderContainer container;

  setUp(() async {
    repo = MockAuthRepository();
    when(repo.reauthenticate()).thenAnswer((_) async => true);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    backend = FakeAppLockBackend();
    store = AppLockStore(backend);
    service = AppLockService(store: store, localAuth: LocalAuthentication());
    await service.setPin('1234');
    await service.setEnabled(true);
  });

  // Gleicher Aufbau wie in main.dart: navigatorKey + builder mit AppLockLayer.
  Widget createSubject() {
    return ProviderScope(
      overrides: [
        authStateProvider
            .overrideWithValue(const AsyncValue.data(UserEntity(id: 'u1'))),
        reauthenticateProvider.overrideWithValue(Reauthenticate(repo)),
        sharedPreferencesProvider.overrideWithValue(prefs),
        appLockServiceProvider.overrideWithValue(service),
      ],
      child: Consumer(builder: (context, ref, _) {
        container = ProviderScope.containerOf(context);
        final isLocked = ref.watch(isAppLockedProvider);
        return MaterialApp(
          navigatorKey: navigatorKey,
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) =>
              AppLockLayer(isLocked: isLocked, child: child!),
          home: const Scaffold(body: Center(child: Text('Home'))),
        );
      }),
    );
  }

  Future<void> openForgotDialog(WidgetTester tester) async {
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();
    await tester.tap(find.text('PIN vergessen?'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'PIN-vergessen-Dialog liegt sichtbar und bedienbar über der Sperre',
      (tester) async {
    await openForgotDialog(tester);

    expect(find.byType(ForgotPinDialog), findsOneWidget);
    expect(find.text('Mit Google bestätigen').hitTestable(), findsOneWidget);
    expect(find.text('Abbrechen').hitTestable(), findsOneWidget);
  });

  testWidgets('Zurücksetzen über den Dialog entsperrt', (tester) async {
    await openForgotDialog(tester);
    await tester.tap(find.text('Mit Google bestätigen'));
    await tester.pumpAndSettle();

    // PinSetupDialog muss ebenfalls bedienbar sein.
    final field = find.descendant(
        of: find.byType(AlertDialog), matching: find.byType(TextField));
    expect(field.hitTestable(), findsOneWidget);
    await tester.enterText(field, '5678');
    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();
    await tester.enterText(field, '5678');
    await tester.tap(find.text('Bestätigen'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Bestätigen'));
    await tester.pumpAndSettle();

    expect(container.read(isAppLockedProvider), isFalse);
    expect(find.byType(AppLockScreen), findsNothing);
    expect(find.text('Home').hitTestable(), findsOneWidget);
    expect(service.verifyPin('5678'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Abbrechen im Dialog führt zurück zum Sperrbildschirm',
      (tester) async {
    await openForgotDialog(tester);
    await tester.tap(find.text('Abbrechen').hitTestable());
    await tester.pumpAndSettle();

    expect(find.byType(ForgotPinDialog), findsNothing);
    expect(find.byType(AppLockScreen), findsOneWidget);
    expect(find.text('PIN vergessen?').hitTestable(), findsOneWidget);
    expect(container.read(isAppLockedProvider), isTrue);
  });

  testWidgets('Zurück-Taste verlässt den Sperrbildschirm nicht',
      (tester) async {
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AppLockScreen), findsOneWidget);
    expect(container.read(isAppLockedProvider), isTrue);

    await tester.tap(find.text('PIN vergessen?'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AppLockScreen), findsOneWidget);
    expect(find.byType(ForgotPinDialog), findsOneWidget);
    expect(container.read(isAppLockedProvider), isTrue);
  });

  testWidgets('Entsperren per PIN entfernt die Sperre ohne Fehler',
      (tester) async {
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '1234');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(container.read(isAppLockedProvider), isFalse);
    expect(find.byType(AppLockScreen), findsNothing);
    expect(find.text('Home').hitTestable(), findsOneWidget);
    expect(tester.testTextInput.isVisible, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Entsperren per Biometrie entfernt die Sperre ohne Fehler',
      (tester) async {
    service = AppLockService(store: store, localAuth: _FakeLocalAuth());
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    expect(container.read(isAppLockedProvider), isFalse);
    expect(find.byType(AppLockScreen), findsNothing);
    expect(find.text('Home').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
