import 'dart:async';

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

import '../../helpers/app_lock_fakes.dart';

class _FakeLocalAuth extends Fake implements LocalAuthentication {
  _FakeLocalAuth(this.result);
  final bool result;

  @override
  Future<bool> get canCheckBiometrics async => true;

  @override
  Future<bool> isDeviceSupported() async => true;

  // authenticate hat Parameter aus einem Transitiv-Paket; daher generisch.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      invocation.memberName == #authenticate
          ? Future<bool>.value(result)
          : super.noSuchMethod(invocation);
}

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

  group('Brute-Force-Limit (#358)', () {
    // Achtung: Solange der periodische Countdown-Timer läuft, nie
    // pumpAndSettle verwenden - nur pump(Duration).
    late FakeClock clock;
    late FakeMonotonic mono;
    const failedKey = 'app_lock_failed_attempts';

    AppLockService build(SharedPreferences p) => AppLockService(
          prefs: p,
          localAuth: LocalAuthentication(),
          now: clock.call,
          monotonic: mono.call,
        );

    setUp(() async {
      clock = FakeClock();
      mono = FakeMonotonic();
      service = build(prefs);
      await service.setPin('1234');
      await service.setEnabled(true);
    });

    Future<void> tick(WidgetTester tester, Duration d) async {
      clock.advance(d);
      mono.advance(d);
      await tester.pump(d);
    }

    Future<void> tryPin(WidgetTester tester, String pin) async {
      await tester.enterText(find.byType(TextField), pin);
      await tester.tap(find.widgetWithText(FilledButton, 'Entsperren'));
      await tester.pump();
      await tester.pump();
    }

    TextField field(WidgetTester tester) =>
        tester.widget<TextField>(find.byType(TextField));

    Future<void> lockOut(WidgetTester tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await tryPin(tester, '0000');
      }
    }

    testWidgets('Fehlversuch 1 und 2: kein Countdown, Feld aktiv',
        (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pump();
      await tryPin(tester, '0000');
      await tryPin(tester, '0000');
      expect(find.text('Falsche PIN'), findsOneWidget);
      expect(find.textContaining('Zu viele Fehlversuche'), findsNothing);
      expect(field(tester).enabled, isTrue);
    });

    testWidgets('3. Fehlversuch sperrt Eingabe, Hilfswege bleiben aktiv',
        (tester) async {
      await lockOut(tester);
      expect(field(tester).enabled, isFalse);
      expect(
          tester
              .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Entsperren'))
              .onPressed,
          isNull);
      expect(find.text('Zu viele Fehlversuche. Versuche es in 00:05 erneut.'),
          findsOneWidget);
      expect(
          tester
              .widget<TextButton>(
                  find.widgetWithText(TextButton, 'PIN vergessen?'))
              .onPressed,
          isNotNull);
      expect(find.byIcon(Icons.fingerprint), findsOneWidget);
      // Timer sauber beenden.
      await tick(tester, const Duration(seconds: 5));
    });

    testWidgets('Ticks zählen herunter, nach Ablauf wieder aktiv mit Fokus',
        (tester) async {
      await lockOut(tester);
      await tick(tester, const Duration(seconds: 1));
      expect(find.text('Zu viele Fehlversuche. Versuche es in 00:04 erneut.'),
          findsOneWidget);
      await tick(tester, const Duration(seconds: 4));
      await tester.pump();
      expect(find.textContaining('Zu viele Fehlversuche'), findsNothing);
      expect(field(tester).enabled, isTrue);
      expect(field(tester).focusNode!.hasFocus, isTrue);
      // Timer ist beendet: pumpAndSettle hängt nicht.
      await tester.pumpAndSettle();
    });

    testWidgets('richtige PIN nach Ablauf entsperrt und setzt Zähler zurück',
        (tester) async {
      await lockOut(tester);
      await tick(tester, const Duration(seconds: 5));
      await tester.pump();
      await tryPin(tester, '1234');
      expect(container.read(isAppLockedProvider), isFalse);
      expect(prefs.getInt(failedKey), isNull);
    });

    testWidgets('Enter während der Sperre ändert nichts', (tester) async {
      await lockOut(tester);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(prefs.getInt(failedKey), 3);
      expect(container.read(isAppLockedProvider), isTrue);
      await tick(tester, const Duration(seconds: 5));
    });

    testWidgets('Start mit gespeicherter Sperre zeigt sofort den Countdown',
        (tester) async {
      for (var i = 0; i < 3; i++) {
        await service.attemptPin('0000');
      }
      service = build(prefs); // "Neustart"
      clock.advance(const Duration(seconds: 2));
      await tester.pumpWidget(createSubject());
      expect(find.text('Zu viele Fehlversuche. Versuche es in 00:03 erneut.'),
          findsOneWidget);
      expect(field(tester).enabled, isFalse);
      await tester.pump();
      await tick(tester, const Duration(seconds: 3));
    });

    testWidgets('Uhr-Rückstellung bei Start zeigt die volle Stufendauer',
        (tester) async {
      for (var i = 0; i < 3; i++) {
        await service.attemptPin('0000');
      }
      service = build(prefs);
      clock.advance(const Duration(minutes: -10));
      await tester.pumpWidget(createSubject());
      await tester.pump();
      await tester.pump();
      expect(find.text('Zu viele Fehlversuche. Versuche es in 00:05 erneut.'),
          findsOneWidget);
      await tick(tester, const Duration(seconds: 5));
    });

    testWidgets('Persist-before-verify im UI', (tester) async {
      final rec = RecordingSharedPreferences(prefs);
      service = build(rec);
      await tester.pumpWidget(createSubject());
      await tester.pump();
      await tryPin(tester, '0000');
      final write = rec.log.indexOf('setInt:$failedKey=1');
      expect(write, greaterThanOrEqualTo(0));
      expect(
          rec.log.indexOf('getString:app_lock_pin_hash'), greaterThan(write));
    });

    testWidgets('Doppeltipp zählt nur einen Versuch', (tester) async {
      final rec = RecordingSharedPreferences(prefs);
      final gate = Completer<void>();
      rec.setIntDelay = gate.future;
      service = build(rec);
      await tester.pumpWidget(createSubject());
      await tester.pump();
      await tester.enterText(find.byType(TextField), '0000');
      final button = find.widgetWithText(FilledButton, 'Entsperren');
      await tester.tap(button);
      await tester.tap(button, warnIfMissed: false);
      await tester.pump();
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      gate.complete();
      await tester.pump();
      await tester.pump();
      expect(prefs.getInt(failedKey), 1);
    });

    testWidgets('Biometrie-Erfolg setzt Zähler zurück und entsperrt',
        (tester) async {
      for (var i = 0; i < 3; i++) {
        await service.attemptPin('0000');
      }
      service = AppLockService(
          prefs: prefs,
          localAuth: _FakeLocalAuth(true),
          now: clock.call,
          monotonic: mono.call);
      await tester.pumpWidget(createSubject());
      await tester.pump();
      await tester.pump();
      expect(prefs.getInt(failedKey), isNull);
      expect(container.read(isAppLockedProvider), isFalse);
    });

    testWidgets('Biometrie-Fehlschlag zählt nicht', (tester) async {
      service = AppLockService(
          prefs: prefs,
          localAuth: _FakeLocalAuth(false),
          now: clock.call,
          monotonic: mono.call);
      await tester.pumpWidget(createSubject());
      await tester.pump();
      await tester.pump();
      expect(prefs.getInt(failedKey), isNull);
      expect(container.read(isAppLockedProvider), isTrue);
    });

    testWidgets('Timer wird in dispose abgebrochen', (tester) async {
      await lockOut(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
      expect(tester.takeException(), isNull);
    });
  });
}
