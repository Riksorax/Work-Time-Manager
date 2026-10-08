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

import '../../helpers/app_lock_fakes.dart';

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

  group('Brute-Force-Limit (#358)', () {
    // Solange der Countdown-Timer läuft, nie pumpAndSettle verwenden.
    late FakeClock clock;
    late FakeMonotonic mono;
    const failedKey = 'app_lock_failed_attempts';

    AppLockService build() => AppLockService(
          prefs: prefs,
          localAuth: LocalAuthentication(),
          now: clock.call,
          monotonic: mono.call,
        );

    setUp(() async {
      clock = FakeClock();
      mono = FakeMonotonic();
      service = build();
      await service.setPinWithRecoveryCode('1234', 'ABCDEFGHJKLMNPQR');
    });

    Future<void> openNoSettle(WidgetTester tester,
        {required bool loggedIn}) async {
      await tester.pumpWidget(createSubject(loggedIn: loggedIn));
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> tick(WidgetTester tester, Duration d) async {
      clock.advance(d);
      mono.advance(d);
      await tester.pump(d);
    }

    Future<void> submit(WidgetTester tester, String code) async {
      await tester.enterText(find.byType(TextField), code);
      await tester.tap(find.text('PIN zurücksetzen').last);
      await tester.pump();
      await tester.pump();
    }

    TextField field(WidgetTester tester) =>
        tester.widget<TextField>(find.byType(TextField));

    testWidgets('gemeinsamer Zähler: 2 Fehlversuche + falscher Code -> Sperre',
        (tester) async {
      await service.attemptPin('0000');
      await service.attemptPin('0000');
      await openNoSettle(tester, loggedIn: false);
      await submit(tester, 'AAAA-AAAA-AAAA-AAAA');
      expect(field(tester).enabled, isFalse);
      expect(
          tester
              .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'PIN zurücksetzen'))
              .onPressed,
          isNull);
      expect(find.text('Zu viele Fehlversuche. Versuche es in 00:05 erneut.'),
          findsOneWidget);
      await tick(tester, const Duration(seconds: 5));
    });

    testWidgets('Sperre besteht nach Schließen und Öffnen weiter',
        (tester) async {
      for (var i = 0; i < 3; i++) {
        await service.attemptPin('0000');
      }
      await openNoSettle(tester, loggedIn: false);
      expect(field(tester).enabled, isFalse);
      await tester.tap(find.text('Abbrechen'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(result, isFalse);
      // Abbrechen räumt den Timer auf.
      await tester.pump(const Duration(seconds: 10));
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(field(tester).enabled, isFalse);
      await tick(tester, const Duration(seconds: 5));
    });

    testWidgets('Re-Auth bleibt in der Sperre nutzbar und zählt nicht',
        (tester) async {
      when(repo.reauthenticate()).thenAnswer((_) async => true);
      for (var i = 0; i < 3; i++) {
        await service.attemptPin('0000');
      }
      await openNoSettle(tester, loggedIn: true);
      expect(field(tester).enabled, isFalse);
      await tester.tap(find.text('Mit Google bestätigen'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(result, isTrue);
      expect(prefs.getInt(failedKey), 3);
    });

    testWidgets('richtiger Code nach Ablauf liefert true und setzt zurück',
        (tester) async {
      for (var i = 0; i < 3; i++) {
        await service.attemptPin('0000');
      }
      await openNoSettle(tester, loggedIn: false);
      await tick(tester, const Duration(seconds: 5));
      await tester.pump();
      expect(field(tester).enabled, isTrue);
      await submit(tester, 'ABCDEFGHJKLMNPQR');
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect(prefs.getInt(failedKey), isNull);
    });

    testWidgets('Doppeltipp zählt nur einen Versuch', (tester) async {
      final rec = RecordingSharedPreferences(prefs);
      final gate = Completer<void>();
      rec.setIntDelay = gate.future;
      service = AppLockService(
          prefs: rec,
          localAuth: LocalAuthentication(),
          now: clock.call,
          monotonic: mono.call);
      await openNoSettle(tester, loggedIn: false);
      await tester.enterText(find.byType(TextField), 'AAAA-AAAA-AAAA-AAAA');
      final button = find.text('PIN zurücksetzen').last;
      await tester.tap(button);
      await tester.tap(button, warnIfMissed: false);
      await tester.pump();
      gate.complete();
      await tester.pump();
      await tester.pump();
      expect(prefs.getInt(failedKey), 1);
    });
  });
}
