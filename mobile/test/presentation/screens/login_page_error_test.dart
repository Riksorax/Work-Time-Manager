import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/utils/sign_in_errors.dart';
import 'package:flutter_work_time/domain/entities/settings_entity.dart';
import 'package:flutter_work_time/domain/usecases/sign_in_with_google.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/screens/login_page.dart';
import 'package:flutter_work_time/presentation/state/settings_state.dart';
import 'package:flutter_work_time/presentation/view_models/settings_view_model.dart';
import 'package:flutter_work_time/presentation/widgets/common/markdown_dialog.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/offline_fixture.dart' show hostLookupError;
import '../../support/reported_logs.dart';

// #582: Die Anmeldeseite zeigt keinen Ausnahmetext. Netzwerkfehler →
// „Keine Verbindung …“, andere Fehler → allgemeine Meldung, Abbruch durch
// den Nutzer (Kontoauswahl geschlossen) → keine Meldung und kein logger.e.

class _Settings extends SettingsViewModel {
  @override
  AsyncValue<SettingsState> build() => AsyncValue.data(SettingsState(
      settings: SettingsEntity(), overtimeBalance: Duration.zero));
  @override
  Future<void> updateAcceptedTermsOfService(bool accepted) async {}
  @override
  Future<void> updateAcceptedPrivacyPolicy(bool accepted) async {}
}

class _SignIn extends Fake implements SignInWithGoogle {
  _SignIn(this.error);
  final Object error;
  int calls = 0;
  @override
  Future<void> call() async {
    calls++;
    throw error;
  }
}

const _rawParts = [
  'Exception',
  'SocketException',
  'uri=',
  'https://',
  'kaputt',
  'network-request-failed',
];

final _canceledGoogle =
    const GoogleSignInException(code: GoogleSignInExceptionCode.canceled);
final _canceledWeb = firebase.FirebaseAuthException(
    code: 'popup-closed-by-user', message: 'The popup has been closed');
final _firebaseOffline = firebase.FirebaseAuthException(
    code: 'network-request-failed', message: 'A network error occurred');
final _unexpected = StateError('kaputt https://api.example.org');
final _googleConfig = const GoogleSignInException(
    code: GoogleSignInExceptionCode.clientConfigurationError,
    description: 'kaputt');

void main() {
  final logs = <LogEvent>[];
  captureLogs(logs);

  Future<_SignIn> pump(WidgetTester tester, String locale, Object error) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final signIn = _SignIn(error);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsViewModelProvider.overrideWith(_Settings.new),
        signInWithGoogleUseCaseProvider.overrideWithValue(signIn),
      ],
      child: MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LoginPage(),
      ),
    ));
    await tester.pump();
    final l10n = lookupAppLocalizations(Locale(locale));
    await tester.tap(find.text(l10n.googleSignInButton));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return signIn;
  }

  void expectNoRawText() {
    for (final part in _rawParts) {
      expect(find.textContaining(part), findsNothing, reason: part);
    }
    for (final e in logs) {
      for (final part in ['SocketException', 'uri=', 'kaputt']) {
        expect(e.message.toString(), isNot(contains(part)),
            reason: 'Log ohne Ausnahmetext: ${e.message}');
      }
    }
  }

  test('isSignInCanceled / isSignInNetworkError', () {
    expect(isSignInCanceled(_canceledGoogle), isTrue);
    expect(isSignInCanceled(_canceledWeb), isTrue);
    expect(
        isSignInCanceled(
            firebase.FirebaseAuthException(code: 'cancelled-popup-request')),
        isTrue);
    expect(isSignInCanceled(_googleConfig), isFalse);
    expect(isSignInCanceled(hostLookupError), isFalse);
    expect(isSignInNetworkError(hostLookupError), isTrue);
    expect(isSignInNetworkError(_firebaseOffline), isTrue);
    expect(isSignInNetworkError(_canceledGoogle), isFalse);
    expect(isSignInNetworkError(_unexpected), isFalse);
  });

  for (final (locale, offline, general) in [
    (
      'de',
      'Keine Verbindung. Prüfe deine Internetverbindung und versuche es '
          'erneut.',
      'Die Anmeldung ist fehlgeschlagen. Bitte versuche es erneut.',
    ),
    (
      'en',
      'No connection. Check your internet connection and try again.',
      'Sign-in failed. Please try again.',
    ),
  ]) {
    group('Sprache $locale', () {
      for (final (name, error) in [
        ('ClientException', hostLookupError as Object),
        ('FirebaseAuth network-request-failed', _firebaseOffline),
      ]) {
        testWidgets('Netzwerkfehler ($name) → „Keine Verbindung“',
            (tester) async {
          await pump(tester, locale, error);
          expect(find.text(offline), findsOneWidget);
          expect(find.byType(LoginPage), findsOneWidget);
          expect(find.byType(AlertDialog), findsNothing,
              reason: 'Lade-Dialog geschlossen');
          expectNoRawText();
          expect(reported(logs, '[LoginPage]'), isEmpty);
        });
      }

      for (final (name, error) in [
        ('StateError', _unexpected as Object),
        ('GoogleSignIn Konfiguration', _googleConfig),
      ]) {
        testWidgets('anderer Fehler ($name) → allgemeine Meldung, logger.e',
            (tester) async {
          await pump(tester, locale, error);
          expect(find.text(general), findsOneWidget);
          expect(find.byType(AlertDialog), findsNothing);
          expectNoRawText();
          expect(reported(logs, '[LoginPage]'), hasLength(1));
        });
      }

      for (final (name, error) in [
        ('Google-Kontoauswahl geschlossen', _canceledGoogle as Object),
        ('Web-Popup geschlossen', _canceledWeb),
      ]) {
        testWidgets('Abbruch ($name) → keine Meldung, kein Fehler',
            (tester) async {
          final signIn = await pump(tester, locale, error);
          expect(signIn.calls, 1);
          expect(find.byType(SnackBar), findsNothing);
          expect(find.byType(AlertDialog), findsNothing,
              reason: 'Lade-Dialog geschlossen, Seite bedienbar');
          expect(find.byType(LoginPage), findsOneWidget);
          expect(reported(logs, '[LoginPage]'), isEmpty);
          expectNoRawText();
        });
      }

      testWidgets('Rechtstext nicht ladbar: Meldung ohne Ausnahmetext',
          (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MarkdownDialog(
                title: 'AGB',
                assetPath: 'assets/legal/gibt_es_nicht_$locale.md'),
          ),
        ));
        final l10n = lookupAppLocalizations(Locale(locale));
        for (var i = 0;
            i < 40 && find.text(l10n.errorLoadingContent).evaluate().isEmpty;
            i++) {
          await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 25)));
          await tester.pump();
        }
        expect(find.text(l10n.errorLoadingContent), findsOneWidget);
        expect(find.textContaining('gibt_es_nicht'), findsNothing);
        expect(find.textContaining('Unable to load'), findsNothing);
        expect(reported(logs, '[MarkdownDialog]'), hasLength(1));
      });
    });
  }
}
