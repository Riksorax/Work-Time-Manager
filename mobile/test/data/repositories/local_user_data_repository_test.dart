import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/utils/timezone_utils.dart';
import 'package:flutter_work_time/data/datasources/remote/firestore_datasource.dart';
import 'package:flutter_work_time/data/repositories/firebase_overtime_repository_impl.dart';
import 'package:flutter_work_time/data/repositories/local_user_data_repository_impl.dart';
import 'package:flutter_work_time/data/repositories/settings_repository_impl.dart';
import 'package:flutter_work_time/data/repositories/work_location_history.dart';
import 'package:flutter_work_time/domain/entities/app_theme_mode.dart';
import 'package:flutter_work_time/domain/entities/bundesland.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/repositories/auth_repository.dart';
import 'package:flutter_work_time/domain/repositories/local_user_data_repository.dart';
import 'package:flutter_work_time/domain/usecases/delete_account.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/reported_logs.dart';

// #581: Nach dem erfolgreichen Löschen des Kontos verschwinden alle lokalen
// Werte des Nutzers; andere Nutzer, Gast-Daten und geräteweite Einstellungen
// bleiben. Scheitert das Löschen, bleibt alles. Ohne Datum/Zeitzone (feste
// Tage, keine Uhr).

class _Firestore extends Fake implements FirestoreDataSource {
  @override
  Future<void> saveSettings(String userId, Map<String, dynamic> settings,
      {String? profileId}) async {}
}

/// Auth-Repository, dessen Löschen gelingt, scheitert oder (abgebrochene
/// erneute Anmeldung) ohne Fehler zurückkehrt, während der Nutzer angemeldet
/// bleibt.
class _Auth extends Fake implements AuthRepository {
  _Auth(this.signedIn);
  String? signedIn;
  Object? failWith;
  bool cancel = false;
  int calls = 0;

  @override
  Future<void> deleteAccount() async {
    calls++;
    if (failWith != null) throw failWith!;
    if (cancel) return;
    signedIn = null;
  }
}

class _User extends Fake implements firebase.User {
  _User(this.uid);
  @override
  final String uid;
}

/// `FirebaseAuth`, dessen angemeldeter Nutzer aus [_Auth] kommt.
class _FirebaseAuth extends Fake implements firebase.FirebaseAuth {
  _FirebaseAuth(this.auth);
  final _Auth auth;
  @override
  firebase.User? get currentUser =>
      auth.signedIn == null ? null : _User(auth.signedIn!);
}

class _FailingLocalData implements LocalUserDataRepository {
  @override
  Future<void> removeUserData(String userId) async =>
      throw StateError('kaputt');
}

const _a = 'uidAlice0000000000000000001';
const _b = 'uidBob000000000000000000002';

/// Schreibt die nutzerbezogenen Werte von [uid] über die echten
/// Repositories, für das Standard-Profil und ein zusätzliches Profil.
Future<void> _seedUser(SharedPreferences prefs, String uid) async {
  for (final profile in [null, 'p1']) {
    final settings = SettingsRepositoryImpl(prefs, _Firestore(), uid, profile);
    await settings.setTargetWeeklyHours(38.5);
    await settings.setWorkdays([1, 2, 3, 4]);
    await settings.setVacationDaysPerYear(28);
    await settings.setBundesland(Bundesland.bayern);
    await settings.setShowWorkLocationOnDashboard(true);
    await settings.setShowHomeOfficeOnDashboard(false);
    await prefs.setInt(
        FirebaseOvertimeRepositoryImpl.minutesKeyFor(
            userId: uid, profileId: profile),
        95);
    await prefs.setString(
        FirebaseOvertimeRepositoryImpl.lastUpdateKeyFor(
            userId: uid, profileId: profile),
        '2026-06-10T00:00:00.000');
    WorkLocationHistory(prefs, userId: uid, profileId: profile).record([
      WorkEntryEntity(
        id: '2026-06-10',
        date: DateTime(2026, 6, 10),
        workStart: DateTime(2026, 6, 10, 8),
        workEnd: DateTime(2026, 6, 10, 16),
        workLocations: const ['Büro'],
      ),
    ]);
  }
  // Altschlüssel vor #217 (wird nur noch gelesen) und gemerktes Profil.
  await prefs.setInt('workdays_per_week_$uid', 5);
  await prefs.setString('active_work_profile_$uid', 'p1');
}

/// Gast-Daten und geräteweite Einstellungen.
Future<void> _seedDeviceAndGuest(SharedPreferences prefs) async {
  final guest = SettingsRepositoryImpl(prefs, _Firestore(), 'local');
  await guest.setTargetWeeklyHours(20);
  await guest.setBundesland(Bundesland.berlin);
  await guest.setThemeMode(AppThemeMode.dark);
  await guest.setLocale('en');
  await guest.setUse24HourFormat(false);
  await guest.setNotificationsEnabled(true);
  await guest.setNotificationTime('17:30');
  await guest.setAcceptedTermsOfService(true);
  await guest.setAcceptedPrivacyPolicy(true);
  await guest.setWarnOnOvertimeThreshold(true);
  await prefs.setString(timezoneOverridePrefsKey, 'Europe/Berlin');
  WorkLocationHistory(prefs, userId: 'local').record([
    WorkEntryEntity(
      id: '2026-06-09',
      date: DateTime(2026, 6, 9),
      workStart: DateTime(2026, 6, 9, 8),
      workLocations: const ['Zuhause'],
    ),
  ]);
  await prefs.setString('local_work_entries_2026-06', '{}');
  await prefs
      .setStringList('local_monthly_keys', ['local_work_entries_2026-06']);
  await prefs.setInt('local_overtime_minutes', 30);
  await prefs.setInt('app_review_completed_days_count', 3);
  await prefs.setString('app_lock_storage_version', '1');
  await prefs.setString('pending_timer_action', 'timer_start|0');
}

Map<String, Object?> _snapshot(SharedPreferences prefs) =>
    {for (final k in prefs.getKeys()) k: prefs.get(k)};

void main() {
  final logs = <LogEvent>[];
  captureLogs(logs);

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await _seedUser(prefs, _a);
    await _seedUser(prefs, _b);
    await _seedDeviceAndGuest(prefs);
  });

  group('LocalUserDataRepositoryImpl', () {
    test('Voraussetzung: beide Nutzer haben Werte in jedem Präfix', () {
      for (final uid in [_a, _b]) {
        for (final prefix
            in LocalUserDataRepositoryImpl.userScopedKeyPrefixes) {
          expect(
              prefs.getKeys().any((k) => k.startsWith('$prefix$uid')), isTrue,
              reason: '$prefix$uid');
        }
        // Zusätzliches Profil ebenfalls vorhanden.
        expect(
            prefs.getKeys().where((k) => k.endsWith('${uid}_p1')), isNotEmpty);
      }
    });

    test('entfernt alle Schlüssel des Nutzers, sonst nichts', () async {
      final before = _snapshot(prefs);
      await LocalUserDataRepositoryImpl(prefs).removeUserData(_a);
      final after = _snapshot(prefs);

      expect(after.keys.where((k) => k.contains(_a)), isEmpty,
          reason: 'kein Schlüssel mit der UID übrig');
      final expected = Map.of(before)..removeWhere((k, _) => k.contains(_a));
      expect(after, expected, reason: 'alle anderen Werte unverändert');
      // Stichproben: anderer Nutzer, Gast, geräteweit.
      expect(after['target_weekly_hours_$_b'], 38.5);
      expect(after['last_known_overtime_minutes_${_b}_p1'], 95);
      expect(after['target_weekly_hours_local'], 20);
      expect(after['bundesland_local'], isNotNull);
      expect(after['theme_mode'], 'dark');
      expect(after['locale'], 'en');
      expect(after['use_24_hour_format'], false);
      expect(after['local_overtime_minutes'], 30);
      expect(after['work_location_history_local'], isNotNull);
    });

    test('UID als Präfix einer anderen UID trifft diese nicht', () {
      expect(LocalUserDataRepositoryImpl.isUserKey('workdays_abcdef', 'abc'),
          isFalse);
      expect(
          LocalUserDataRepositoryImpl.isUserKey('workdays_abc', 'abc'), isTrue);
      expect(LocalUserDataRepositoryImpl.isUserKey('workdays_abc_p9', 'abc'),
          isTrue);
      // „local“ und leere UID entfernen nie Gast-Daten.
      expect(LocalUserDataRepositoryImpl.isUserKey('workdays_local', 'local'),
          isFalse);
      expect(LocalUserDataRepositoryImpl.isUserKey('workdays_', ''), isFalse);
    });
  });

  group('DeleteAccount', () {
    DeleteAccount useCase(_Auth auth, {LocalUserDataRepository? local}) =>
        DeleteAccount(auth,
            localUserData: local ?? LocalUserDataRepositoryImpl(prefs),
            currentUserId: () => auth.signedIn);

    test('erfolgreich gelöscht: lokale Daten des Nutzers sind weg', () async {
      final auth = _Auth(_a);
      final before = _snapshot(prefs);
      await useCase(auth)();
      expect(auth.calls, 1);
      final after = _snapshot(prefs);
      expect(after.keys.where((k) => k.contains(_a)), isEmpty);
      expect(after, Map.of(before)..removeWhere((k, _) => k.contains(_a)));
    });

    test('Löschen scheitert: alles bleibt, Fehler geht weiter', () async {
      final err = Exception('requires-recent-login');
      final auth = _Auth(_a)..failWith = err;
      final before = _snapshot(prefs);
      await expectLater(useCase(auth)(), throwsA(same(err)));
      expect(_snapshot(prefs), before);
    });

    test(
        'erneute Anmeldung abgebrochen (Nutzer bleibt angemeldet): alles '
        'bleibt', () async {
      final auth = _Auth(_a)..cancel = true;
      final before = _snapshot(prefs);
      await useCase(auth)();
      expect(_snapshot(prefs), before);
    });

    test('niemand angemeldet: nichts zu entfernen', () async {
      final auth = _Auth(null);
      final before = _snapshot(prefs);
      await useCase(auth)();
      expect(_snapshot(prefs), before);
    });

    test('Aufräumen scheitert: kein Fehler für den Nutzer, logger.e', () async {
      final auth = _Auth(_a);
      await useCase(auth, local: _FailingLocalData())();
      final r = reported(logs, '[DeleteAccount]');
      expect(r, hasLength(1));
      expect(r.single.message.toString(), isNot(contains('kaputt')));
    });

    test('ohne Aufräum-Repository (alter Aufbau) bleibt alles', () async {
      final auth = _Auth(_a);
      final before = _snapshot(prefs);
      await DeleteAccount(auth)();
      expect(_snapshot(prefs), before);
    });
  });

  group('Provider deleteAccountUseCaseProvider', () {
    for (final (name, configure, removed) in [
      ('gelöscht', (_Auth a) {}, true),
      ('abgebrochen', (_Auth a) => a.cancel = true, false),
    ]) {
      test('$name: lokale Daten ${removed ? 'weg' : 'bleiben'}', () async {
        final auth = _Auth(_a);
        configure(auth);
        final container = ProviderContainer(overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(auth),
          firebaseAuthProvider.overrideWithValue(_FirebaseAuth(auth)),
        ]);
        addTearDown(container.dispose);
        final before = _snapshot(prefs);
        await container.read(deleteAccountUseCaseProvider)();
        final after = _snapshot(prefs);
        expect(after.keys.any((k) => k.contains(_a)), !removed);
        expect(after.keys.where((k) => k.contains(_b)).length,
            before.keys.where((k) => k.contains(_b)).length);
      });
    }
  });
}
