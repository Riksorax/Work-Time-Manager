import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_work_time/core/providers/app_lock_provider.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/services/app_lock_service.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/view_models/auth_view_model.dart';
import 'package:flutter_work_time/presentation/widgets/forgot_pin_dialog.dart';

import '../../domain/usecases/auth_usecases_test.mocks.dart';
import 'package:flutter_work_time/domain/usecases/reauthenticate.dart';
import 'package:mockito/mockito.dart';

void main() {
  late SharedPreferences prefs;
  late AppLockService service;
  late MockAuthRepository repo;
  bool? result;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    service = AppLockService(prefs: prefs, localAuth: LocalAuthentication());
    repo = MockAuthRepository();
    result = null;
  });

  Widget createSubject({required bool loggedIn}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appLockServiceProvider.overrideWithValue(service),
        authStateProvider.overrideWithValue(
            AsyncValue.data(loggedIn ? const UserEntity(id: 'u1') : null)),
        reauthenticateProvider.overrideWithValue(Reauthenticate(repo)),
      ],
      child: MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await ForgotPinDialog.show(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
  }

  Future<void> open(WidgetTester tester, {required bool loggedIn}) async {
    await tester.pumpWidget(createSubject(loggedIn: loggedIn));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('eingeloggt: Re-Auth true -> Dialog liefert true',
      (tester) async {
    when(repo.reauthenticate()).thenAnswer((_) async => true);
    await open(tester, loggedIn: true);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('Mit Google bestätigen'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('eingeloggt: Re-Auth false -> Fehler, Dialog bleibt',
      (tester) async {
    when(repo.reauthenticate()).thenAnswer((_) async => false);
    await open(tester, loggedIn: true);
    await tester.tap(find.text('Mit Google bestätigen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bestätigung fehlgeschlagen'), findsOneWidget);
    expect(result, isNull);
  });

  testWidgets('Code vorhanden: richtiger Code -> true', (tester) async {
    await service.setPinWithRecoveryCode('1234', 'ABCDEFGHJKLMNPQR');
    await open(tester, loggedIn: false);
    expect(find.text('Mit Google bestätigen'), findsNothing);
    await tester.enterText(find.byType(TextField), 'abcd-efgh-jklm-npqr');
    await tester.tap(find.text('PIN zurücksetzen').last);
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('Code vorhanden: falscher Code -> Fehler', (tester) async {
    await service.setPinWithRecoveryCode('1234', 'ABCDEFGHJKLMNPQR');
    await open(tester, loggedIn: false);
    await tester.enterText(find.byType(TextField), 'AAAA-AAAA-AAAA-AAAA');
    await tester.tap(find.text('PIN zurücksetzen').last);
    await tester.pumpAndSettle();
    expect(find.text('Falscher Wiederherstellungscode'), findsOneWidget);
    expect(result, isNull);
  });

  testWidgets('weder Login noch Code: nur Hinweistext', (tester) async {
    await open(tester, loggedIn: false);
    expect(find.textContaining('Systemeinstellungen'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Mit Google bestätigen'), findsNothing);
  });

  testWidgets('eingeloggt ohne Code: nur Re-Auth', (tester) async {
    await open(tester, loggedIn: true);
    expect(find.text('Mit Google bestätigen'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('Systemeinstellungen'), findsNothing);
  });

  testWidgets('Abbrechen liefert false', (tester) async {
    await open(tester, loggedIn: false);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('falscher Code leert das Feld, danach richtiger Code -> true',
      (tester) async {
    await service.setPinWithRecoveryCode('1234', 'ABCDEFGHJKLMNPQR');
    await open(tester, loggedIn: false);
    await tester.enterText(find.byType(TextField), 'AAAA-AAAA-AAAA-AAAA');
    await tester.tap(find.text('PIN zurücksetzen').last);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
    await tester.enterText(find.byType(TextField), 'ABCDEFGHJKLMNPQR');
    await tester.tap(find.text('PIN zurücksetzen').last);
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('eingeloggt mit Code: beide Wege sichtbar', (tester) async {
    await service.setPinWithRecoveryCode('1234', 'ABCDEFGHJKLMNPQR');
    await open(tester, loggedIn: true);
    expect(find.text('Mit Google bestätigen'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.textContaining('Systemeinstellungen'), findsNothing);
  });

  testWidgets(
      'Re-Auth läuft: Button deaktiviert, danach Fehler und wieder aktiv',
      (tester) async {
    final completer = Completer<bool>();
    when(repo.reauthenticate()).thenAnswer((_) => completer.future);
    await open(tester, loggedIn: true);
    await tester.tap(find.text('Mit Google bestätigen'));
    await tester.pump();
    FilledButton button() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Mit Google bestätigen'));
    expect(button().onPressed, isNull);
    completer.complete(false);
    await tester.pumpAndSettle();
    expect(button().onPressed, isNotNull);
    expect(find.textContaining('Bestätigung fehlgeschlagen'), findsOneWidget);
    expect(result, isNull);
  });

  testWidgets('Re-Auth wirft Exception: Fehler sichtbar, Button wieder aktiv',
      (tester) async {
    when(repo.reauthenticate()).thenThrow(Exception('boom'));
    await open(tester, loggedIn: true);
    await tester.tap(find.text('Mit Google bestätigen'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Bestätigung fehlgeschlagen'), findsOneWidget);
    final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Mit Google bestätigen'));
    expect(button.onPressed, isNotNull);
    expect(result, isNull);
  });
}
