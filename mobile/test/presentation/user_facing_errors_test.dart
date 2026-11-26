import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/providers/subscription_provider.dart';
import 'package:flutter_work_time/core/utils/api_errors.dart';
import 'package:flutter_work_time/domain/entities/settings_entity.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';
import 'package:flutter_work_time/domain/entities/weekly_reflection_entity.dart';
import 'package:flutter_work_time/domain/entities/work_profile_entity.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/screens/settings_page.dart';
import 'package:flutter_work_time/presentation/state/leave_balance_state.dart';
import 'package:flutter_work_time/presentation/state/settings_state.dart';
import 'package:flutter_work_time/presentation/state/weekly_reflection_state.dart';
import 'package:flutter_work_time/presentation/utils/user_error_message.dart';
import 'package:flutter_work_time/presentation/view_models/data_sync_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/leave_balance_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/settings_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/weekly_reflection_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/work_profile_view_model.dart';
import 'package:flutter_work_time/presentation/widgets/add_work_profile_dialog.dart';
import 'package:flutter_work_time/presentation/widgets/common/load_failure_notice.dart';
import 'package:flutter_work_time/presentation/widgets/manage_work_profiles_dialog.dart';
import 'package:flutter_work_time/presentation/widgets/weekly_reflection_dialog.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import '../support/offline_fixture.dart' show hostLookupError;
import '../support/reported_logs.dart';

// #582: Keine technischen Fehlertexte. Jede Stelle zeigt eine verständliche
// Meldung ohne Ausnahmetext, bei Netzwerkfehlern „Keine Verbindung …“; der
// Fehler geht ohne Ausnahmetext ins Log (erwartbar: logger.i, sonst logger.e).

/// Teile des rohen Ausnahmetexts, die nie zu sehen sein dürfen.
const _rawParts = [
  'Exception',
  'SocketException',
  'Failed host lookup',
  'uri=',
  'https://',
  'kaputt',
];

/// Im Log steht höchstens der Typ (`errorLabel`), nie der Text.
const _rawLogParts = [
  'SocketException',
  'Failed host lookup',
  'uri=',
  'kaputt'
];

/// Ein unerwarteter Fehler mit „technischem“ Text.
final _unexpected = StateError('kaputt https://api.example.org');

const _user =
    UserEntity(id: 'u1', email: 'lea@example.org', displayName: 'Lea');

class _Texts {
  const _Texts(this.locale, this.offline, this.sync, this.syncPartial,
      this.create, this.delete, this.save, this.profilesLoad);
  final String locale;
  final String offline;
  final String sync;
  final String syncPartial;
  final String create;
  final String delete;
  final String save;
  final String profilesLoad;
}

const _de = _Texts(
  'de',
  'Keine Verbindung. Prüfe deine Internetverbindung und versuche es erneut.',
  'Die Synchronisierung ist fehlgeschlagen. Bitte versuche es erneut.',
  'Die Synchronisierung war nur teilweise erfolgreich.\nArbeitseinträge: 3\n'
      'Bitte versuche es erneut.',
  'Das Profil konnte nicht angelegt werden. Bitte versuche es erneut.',
  'Das Profil konnte nicht gelöscht werden. Bitte versuche es erneut.',
  'Speichern fehlgeschlagen. Bitte versuche es erneut.',
  'Die Profile konnten nicht geladen werden.',
);

const _en = _Texts(
  'en',
  'No connection. Check your internet connection and try again.',
  'Sync failed. Please try again.',
  'Sync was only partly successful.\nWork entries: 3\nPlease try again.',
  'The profile could not be created. Please try again.',
  'The profile could not be deleted. Please try again.',
  'Saving failed. Please try again.',
  'The profiles could not be loaded.',
);

class _Settings extends SettingsViewModel {
  @override
  AsyncValue<SettingsState> build() => AsyncValue.data(SettingsState(
      settings: SettingsEntity(), overtimeBalance: Duration.zero));
}

class _Leave extends LeaveBalanceViewModel {
  @override
  LeaveBalanceState build() => const LeaveBalanceState();
}

class _NoProfile extends ActiveWorkProfileIdNotifier {
  @override
  String? build() => null;
}

class _Sync extends Fake implements DataSyncViewModel {
  _Sync({this.error, this.result});
  final Object? error;
  final DataSyncResult? result;
  @override
  Future<DataSyncResult> syncAll() async {
    if (error != null) throw error!;
    return result!;
  }
}

class _Profiles extends Fake implements WorkProfileViewModel {
  _Profiles(this.error);
  final Object error;
  @override
  Future<ProfileSwitchGuardResult> checkSwitchAllowed(
          {required Future<bool> Function() confirm}) async =>
      ProfileSwitchGuardResult.allowed;
  @override
  Future<WorkProfileEntity> addProfile(String name) async => throw error;
  @override
  Future<void> deleteProfile(String profileId) async => throw error;
}

class _Reflection extends WeeklyReflectionViewModel {
  _Reflection(this.error);
  final Object error;
  @override
  WeeklyReflectionState build() => WeeklyReflectionState.initial();
  @override
  Future<void> loadReflection(DateTime startOfWeek) async {
    state = state.copyWith(
        isLoading: false,
        reflection: const WeeklyReflectionEntity(year: 2026, week: 24));
  }

  @override
  Future<void> saveReflection(
          {required String whatWentWell, required String whatWasHard}) async =>
      throw error;
}

void main() {
  final logs = <LogEvent>[];
  captureLogs(logs);
  setUpAll(tz_data.initializeTimeZones);

  void expectNoRawText(WidgetTester tester) {
    for (final part in _rawParts) {
      expect(find.textContaining(part), findsNothing, reason: part);
    }
    for (final e in logs) {
      for (final part in _rawLogParts) {
        expect(e.message.toString(), isNot(contains(part)),
            reason: 'Log ohne Ausnahmetext: ${e.message}');
      }
    }
  }

  /// Seite mit einem Knopf, der [dialog] öffnet (Snackbars landen im
  /// Scaffold dahinter wie in der App).
  Widget host(Widget dialog) => Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () =>
                  showDialog<void>(context: context, builder: (_) => dialog),
              child: const Text('open'),
            ),
          ),
        ),
      );

  Future<void> pump(WidgetTester tester, String locale, Widget home,
      {List overrides = const [], bool signedIn = true}) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      // Ohne automatisches Wiederholen: der Fehlerzustand kommt sofort.
      retry: (_, __) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsViewModelProvider.overrideWith(_Settings.new),
        leaveBalanceViewModelProvider.overrideWith(_Leave.new),
        activeWorkProfileIdProvider.overrideWith(_NoProfile.new),
        if (signedIn)
          authStateProvider
              .overrideWithValue(const AsyncValue<UserEntity?>.data(_user)),
        isPremiumProvider.overrideWithValue(true),
        activeEntitlementProvider.overrideWithValue(null),
        ...overrides.cast(),
      ],
      child: MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  test('userErrorMessage und logUserFacingError', () {
    final l10n = lookupAppLocalizations(const Locale('de'));
    expect(userErrorMessage(l10n, hostLookupError, general: 'allgemein'),
        _de.offline);
    expect(userErrorMessage(l10n, TimeoutException('x'), general: 'allgemein'),
        _de.offline);
    expect(
        userErrorMessage(l10n, const ApiException('x', 500),
            general: 'allgemein'),
        'allgemein');
    // Abgemeldet ist erwartbar (kein logger.e), aber keine Netzwerkmeldung.
    expect(
        userErrorMessage(l10n, const NotSignedInException('x'),
            general: 'allgemein'),
        'allgemein');

    logUserFacingError('[T1]', hostLookupError);
    logUserFacingError('[T2]', const NotSignedInException('x'));
    logUserFacingError('[T3]', const ApiException('x', 503));
    logUserFacingError('[T4]', _unexpected);
    expect(reported(logs, '[T1]'), isEmpty);
    expect(reported(logs, '[T2]'), isEmpty);
    expect(reported(logs, '[T3]').single.message, '[T3] (ApiException(503))');
    expect(reported(logs, '[T4]').single.message, '[T4] (StateError)');
    expect(logs.map((e) => e.message.toString()).join('|'),
        isNot(contains('Failed host lookup')));
  });

  for (final t in [_de, _en]) {
    group('Sprache ${t.locale}', () {
      final l10n = lookupAppLocalizations(Locale(t.locale));

      Future<void> tapSync(WidgetTester tester) async {
        final button = find.text(l10n.syncToCloudButton);
        await tester.scrollUntilVisible(button, 300,
            scrollable: find.byType(Scrollable).first);
        await tester.tap(button);
        await settle(tester);
      }

      testWidgets('Sync: Netzwerkfehler', (tester) async {
        await pump(tester, t.locale, const SettingsPage(), overrides: [
          dataSyncViewModelProvider
              .overrideWithValue(_Sync(error: hostLookupError)),
        ]);
        await tapSync(tester);
        expect(find.text(t.offline), findsOneWidget);
        expectNoRawText(tester);
        expect(reported(logs, '[SettingsPage]'), isEmpty);
      });

      testWidgets('Sync: anderer Fehler', (tester) async {
        await pump(tester, t.locale, const SettingsPage(), overrides: [
          dataSyncViewModelProvider
              .overrideWithValue(_Sync(error: _unexpected)),
        ]);
        await tapSync(tester);
        expect(find.text(t.sync), findsOneWidget);
        expectNoRawText(tester);
        expect(reported(logs, '[SettingsPage]'), hasLength(1));
      });

      testWidgets('Sync: teilweise fehlgeschlagen, ohne Fehlerliste',
          (tester) async {
        await pump(tester, t.locale, const SettingsPage(), overrides: [
          dataSyncViewModelProvider.overrideWithValue(_Sync(
              result: DataSyncResult(
                  workEntriesSynced: 3,
                  overtimeSynced: false,
                  errors: ['Überstunden: $hostLookupError']))),
        ]);
        await tapSync(tester);
        expect(find.text(t.syncPartial), findsOneWidget);
        expectNoRawText(tester);
      });

      for (final (name, error, text) in [
        ('Netzwerkfehler', hostLookupError as Object, t.offline),
        ('anderer Fehler', _unexpected, t.create),
      ]) {
        testWidgets('Profil anlegen: $name', (tester) async {
          await pump(tester, t.locale, host(const AddWorkProfileDialog()),
              overrides: [
                workProfileViewModelProvider
                    .overrideWithValue(_Profiles(error)),
                workProfilesProvider.overrideWith(
                    (ref) async => [WorkProfileEntity.defaultProfile()]),
              ]);
          await tester.tap(find.text('open'));
          await settle(tester);
          await tester.enterText(find.byType(TextField), 'Nebenjob');
          await tester.tap(find.text(l10n.createAction));
          await settle(tester);
          expect(find.text(text), findsOneWidget);
          // Dialog bleibt offen und bedienbar.
          expect(find.byType(AddWorkProfileDialog), findsOneWidget);
          expectNoRawText(tester);
          expect(reported(logs, '[AddWorkProfileDialog]'),
              hasLength(error == hostLookupError ? 0 : 1));
        });
      }

      for (final (name, error, text) in [
        ('Netzwerkfehler', hostLookupError as Object, t.offline),
        ('anderer Fehler', _unexpected, t.delete),
      ]) {
        testWidgets('Profil löschen: $name', (tester) async {
          await pump(tester, t.locale, host(const ManageWorkProfilesDialog()),
              overrides: [
                workProfileViewModelProvider
                    .overrideWithValue(_Profiles(error)),
                workProfilesProvider.overrideWith((ref) async => [
                      WorkProfileEntity.defaultProfile(),
                      const WorkProfileEntity(id: 'p1', name: 'Nebenjob'),
                    ]),
              ]);
          await tester.tap(find.text('open'));
          await settle(tester);
          await tester.tap(find.byIcon(Icons.delete_outline));
          await settle(tester);
          await tester.tap(find.text(l10n.deleteAction));
          await settle(tester);
          expect(find.text(text), findsOneWidget);
          expectNoRawText(tester);
          expect(reported(logs, '[ManageWorkProfilesDialog]'),
              hasLength(error == hostLookupError ? 0 : 1));
        });
      }

      for (final (name, error, offline) in [
        ('Netzwerkfehler', hostLookupError as Object, true),
        ('anderer Fehler', _unexpected, false),
      ]) {
        testWidgets('Profile laden: $name, Erneut versuchen', (tester) async {
          var calls = 0;
          await pump(tester, t.locale, host(const ManageWorkProfilesDialog()),
              overrides: [
                workProfilesProvider.overrideWith((ref) async {
                  calls++;
                  if (calls == 1) throw error;
                  return [
                    WorkProfileEntity.defaultProfile(),
                    const WorkProfileEntity(id: 'p1', name: 'Nebenjob'),
                  ];
                }),
              ]);
          await tester.tap(find.text('open'));
          await settle(tester);
          final notice =
              tester.widget<LoadFailureNotice>(find.byType(LoadFailureNotice));
          expect(notice.offline, offline);
          expect(find.text(t.profilesLoad), findsOneWidget);
          if (offline) {
            expect(find.text(l10n.reportsOfflineTitle), findsOneWidget);
          }
          expectNoRawText(tester);
          expect(reported(logs, '[ManageWorkProfilesDialog]'),
              hasLength(offline ? 0 : 1));

          await tester.tap(find.text(l10n.retryButton));
          await settle(tester);
          expect(find.text('Nebenjob'), findsOneWidget);
          expect(find.byType(LoadFailureNotice), findsNothing);
        });
      }

      for (final (name, error, text) in [
        ('Netzwerkfehler', hostLookupError as Object, t.offline),
        ('anderer Fehler', _unexpected, t.save),
      ]) {
        testWidgets('Wochen-Reflexion speichern: $name', (tester) async {
          await pump(tester, t.locale,
              host(WeeklyReflectionDialog(startOfWeek: DateTime(2026, 6, 8))),
              overrides: [
                weeklyReflectionViewModelProvider
                    .overrideWith(() => _Reflection(error)),
              ]);
          await tester.tap(find.text('open'));
          await settle(tester);
          await tester.tap(find.text(l10n.save));
          await settle(tester);
          expect(find.text(text), findsOneWidget);
          expect(find.byType(WeeklyReflectionDialog), findsOneWidget);
          expectNoRawText(tester);
        });
      }
    });
  }
}
