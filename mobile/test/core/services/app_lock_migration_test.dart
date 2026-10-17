import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/services/app_lock_service.dart';
import 'package:flutter_work_time/core/services/app_lock_store.dart';
import 'package:flutter_work_time/domain/utils/pin_hash.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_app_lock_backend.dart';

/// Prefs mit Fehlerinjektion für Marker-Schreiben und Löschen.
class _FlakyPrefs implements SharedPreferences {
  final SharedPreferences inner;
  final Set<String> throwOnSet = {};
  final Set<String> falseOnSet = {};
  bool throwOnRemove = false;

  /// Hält `setInt` auf den Marker an, bis der Completer beendet ist.
  Completer<void>? holdMarkerSet;

  _FlakyPrefs(this.inner);

  @override
  Future<bool> setInt(String key, int value) async {
    final hold = holdMarkerSet;
    if (hold != null && key == _marker) await hold.future;
    if (throwOnSet.contains(key)) throw StateError('set failed');
    if (falseOnSet.contains(key)) return false;
    return inner.setInt(key, value);
  }

  @override
  Future<bool> remove(String key) async {
    if (throwOnRemove) throw StateError('remove failed');
    return inner.remove(key);
  }

  @override
  Future<bool> setBool(String key, bool value) => inner.setBool(key, value);

  @override
  Future<bool> setString(String key, String value) =>
      inner.setString(key, value);

  @override
  Object? get(String key) => inner.get(key);

  @override
  bool? getBool(String key) => inner.getBool(key);

  @override
  int? getInt(String key) => inner.getInt(key);

  @override
  String? getString(String key) => inner.getString(key);

  @override
  Set<String> getKeys() => inner.getKeys();

  @override
  bool containsKey(String key) => inner.containsKey(key);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

const _enabled = 'app_lock_enabled';
const _pinHash = 'app_lock_pin_hash';
const _pinSalt = 'app_lock_pin_salt';
const _recovery = 'app_lock_recovery_code_hash';
const _failed = 'app_lock_failed_attempts';
const _until = 'app_lock_locked_until_ms';
const _lastSeen = 'app_lock_last_seen_ms';
const _marker = 'app_lock_storage_version';

const _legacyKeys = [
  _enabled,
  _pinHash,
  _recovery,
  _failed,
  _until,
  _lastSeen,
];

Map<String, Object> _legacyValues() => {
      _enabled: true,
      _pinHash: 'salt1:${hashPin('1234', 'salt1')}',
      _recovery: 'salt2:${hashPin('ABCDEFGHJKLMNPQR', 'salt2')}',
      _failed: 3,
      _until: 1700000000000,
      _lastSeen: 1700000001000,
    };

Set<String> _lockKeys(SharedPreferences p) =>
    p.getKeys().where((k) => k.startsWith('app_lock_')).toSet();

AppLockService _service(AppLockStore store) => AppLockService(
      store: store,
      localAuth: LocalAuthentication(),
      now: () => DateTime.utc(2026, 1, 1),
    );

void main() {
  late FakeAppLockBackend backend;

  Future<SharedPreferences> prefsWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  Future<AppLockStore> load(
    SharedPreferences prefs, {
    Duration timeout = const Duration(seconds: 5),
  }) =>
      AppLockStore.load(
        prefs: prefs,
        secure: backend,
        isWeb: false,
        timeout: timeout,
        retryDelay: Duration.zero,
      );

  setUp(() => backend = FakeAppLockBackend());

  group('Update-Installation (Legacy-Keys in Prefs)', () {
    test('kopiert, prüft zurück, setzt Marker und löscht die Legacy-Keys',
        () async {
      final prefs = await prefsWith(_legacyValues());
      final store = await load(prefs);

      expect(backend.data, {
        _enabled: 'true',
        _pinHash: _legacyValues()[_pinHash],
        _recovery: _legacyValues()[_recovery],
        _failed: '3',
        _until: '1700000000000',
        _lastSeen: '1700000001000',
      });
      expect(prefs.getInt(_marker), 1);
      expect(_lockKeys(prefs), {_marker});
      expect(backend.writes.last, 'write:$_enabled',
          reason: 'enabled wird zuletzt geschrieben');

      final service = _service(store);
      expect(service.isEnabled, isTrue);
      expect(service.hasPin, isTrue);
      expect(service.verifyPin('1234'), isTrue);
      expect(service.verifyRecoveryCode('ABCDEFGHJKLMNPQR'), isTrue);
      expect(store.getInt(_failed), 3);
      expect(store.getInt(_until), 1700000000000);
      expect(store.getInt(_lastSeen), 1700000001000);
    });

    test('Zähler und Sperrzeit bleiben nach der Migration wirksam', () async {
      final prefs = await prefsWith({
        ..._legacyValues(),
        _failed: 5,
        _until: DateTime.utc(2026, 1, 1, 0, 0, 30).millisecondsSinceEpoch,
      });
      final store = await load(prefs);
      final service = _service(store);
      expect(service.remainingLockout, const Duration(seconds: 30));
    });

    test('Legacy-Salt-Form (Hash ohne ":" plus Salt) migriert und verifiziert',
        () async {
      final prefs = await prefsWith({
        _pinSalt: 'salt',
        _pinHash: hashPin('1234', 'salt'),
      });
      final store = await load(prefs);
      expect(backend.data[_pinSalt], 'salt');
      expect(_lockKeys(prefs), {_marker});
      final service = _service(store);
      expect(service.verifyPin('1234'), isTrue);
      expect(service.verifyPin('0000'), isFalse);
    });

    test('nur ein Teil der Keys vorhanden', () async {
      final prefs = await prefsWith({_enabled: false});
      final store = await load(prefs);
      expect(backend.data, {_enabled: 'false'});
      expect(store.getBool(_enabled), isFalse);
      expect(_lockKeys(prefs), {_marker});
    });

    test('veraltete Secure-Werte, die es in Prefs nicht gibt, werden entfernt',
        () async {
      backend = FakeAppLockBackend({_recovery: 'stale', _pinHash: 'stale'});
      final prefs = await prefsWith({_pinHash: 'neu:hash'});
      final store = await load(prefs);
      expect(backend.data, {_pinHash: 'neu:hash'});
      expect(store.getString(_recovery), isNull);
      expect(prefs.getInt(_marker), 1);
    });
  });

  group('Fehler bei der Migration: Prefs bleiben, kein Aussperren', () {
    void expectFallbackWorks(AppLockStore store) {
      final service = _service(store);
      expect(service.hasPin, isTrue);
      expect(service.isEnabled, isTrue);
      expect(service.verifyPin('1234'), isTrue);
      expect(store.getInt(_failed), 3);
    }

    void expectPrefsUntouched(SharedPreferences prefs) {
      final expected = _legacyValues();
      expect(_lockKeys(prefs), expected.keys.toSet());
      for (final e in expected.entries) {
        expect(prefs.get(e.key), e.value, reason: e.key);
      }
    }

    for (final key in _legacyKeys) {
      test('Schreibfehler bei $key', () async {
        final prefs = await prefsWith(_legacyValues());
        backend.failWriteKeys.add(key);
        final store = await load(prefs);

        expectPrefsUntouched(prefs);
        expectFallbackWorks(store);

        // Nächster Start mit behobenem Fehler migriert erfolgreich.
        backend.failWriteKeys.clear();
        final second = await load(prefs);
        expect(_lockKeys(prefs), {_marker});
        expect(_service(second).verifyPin('1234'), isTrue);
      });
    }

    test('Rücklese-Mismatch', () async {
      final prefs = await prefsWith(_legacyValues());
      backend.corruptKeys.add(_pinHash);
      final store = await load(prefs);
      expectPrefsUntouched(prefs);
      expect(prefs.getInt(_marker), isNull);
      expectFallbackWorks(store);
    });

    test('Lese-Exception beim Zurücklesen', () async {
      final prefs = await prefsWith(_legacyValues());
      // readAll #1 (Altbestand) ok, #2 (Rücklesen) wirft
      final wrapped = _ThrowOnNthRead(FakeAppLockBackend(), 2);
      final store = await AppLockStore.load(
        prefs: prefs,
        secure: wrapped,
        isWeb: false,
        timeout: const Duration(seconds: 5),
        retryDelay: Duration.zero,
      );
      expectPrefsUntouched(prefs);
      expect(prefs.getInt(_marker), isNull);
      expectFallbackWorks(store);
    });

    test('Lese-Exception schon beim Lesen des Altbestands', () async {
      final prefs = await prefsWith(_legacyValues());
      backend.failReads = 1;
      final store = await load(prefs);
      expectPrefsUntouched(prefs);
      expectFallbackWorks(store);
    });

    test('Zeitlimit: Fallback, und eine späte Migration setzt keinen Marker',
        () async {
      final prefs = await prefsWith(_legacyValues());
      final hold = Completer<void>();
      backend.holdReads = hold;
      final store =
          await load(prefs, timeout: const Duration(milliseconds: 50));

      expectPrefsUntouched(prefs);
      expectFallbackWorks(store);

      // Das hängende Backend erwacht nach dem Zeitlimit: die abgebrochene
      // Migration darf nichts mehr an den Prefs ändern.
      hold.complete();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expectPrefsUntouched(prefs);
      expect(prefs.getInt(_marker), isNull);
    });

    test(
        'Zeitlimit feuert während des Marker-Schreibens: Store bleibt auf dem '
        'sicheren Speicher (neue PIN geht nicht verloren)', () async {
      final prefs = _FlakyPrefs(await prefsWith(_legacyValues()));
      final hold = Completer<void>();
      prefs.holdMarkerSet = hold;
      Future<void>.delayed(const Duration(milliseconds: 150), hold.complete);

      final store =
          await load(prefs, timeout: const Duration(milliseconds: 50));

      expect(prefs.getInt(_marker), 1);
      expect(store.getBool(_enabled), isTrue);
      await store.setString(_pinHash, 'neu:hash');
      expect(backend.data[_pinHash], 'neu:hash');

      // Nächster Start: der sichere Speicher gewinnt, übrige Legacy-Keys gehen.
      final next = await load(prefs);
      expect(next.getString(_pinHash), 'neu:hash');
      expect(_lockKeys(prefs), {_marker});
    });

    test('Marker kann nicht gesetzt werden (Exception): Fallback', () async {
      final prefs = _FlakyPrefs(await prefsWith(_legacyValues()));
      prefs.throwOnSet.add(_marker);
      final store = await load(prefs);
      expectPrefsUntouched(prefs);
      expectFallbackWorks(store);
    });

    test('Marker kann nicht gesetzt werden (false): Fallback', () async {
      final prefs = _FlakyPrefs(await prefsWith(_legacyValues()));
      prefs.falseOnSet.add(_marker);
      final store = await load(prefs);
      expectPrefsUntouched(prefs);
      expectFallbackWorks(store);
    });

    test(
        'Abbruch nach Secure-Schreiben vor dem Marker: zweiter Lauf ist idempotent',
        () async {
      final prefs = _FlakyPrefs(await prefsWith(_legacyValues()));
      prefs.throwOnSet.add(_marker);
      await load(prefs);
      final afterFirst = {...backend.data};
      expect(afterFirst.length, 6, reason: 'Secure enthält schon die Kopie');

      prefs.throwOnSet.clear();
      final store = await load(prefs);
      expect(backend.data, afterFirst);
      expect(_lockKeys(prefs), {_marker});
      expect(_service(store).verifyPin('1234'), isTrue);
    });

    test('Fallback schreibt Typen wie der alte Build in die Prefs', () async {
      final prefs = await prefsWith(_legacyValues());
      backend.failAllWrites = true;
      final store = await load(prefs);

      await store.setBool(_enabled, false);
      await store.setInt(_failed, 4);
      await store.setString(_pinHash, 'x:y');
      expect(prefs.getBool(_enabled), isFalse);
      expect(prefs.getInt(_failed), 4);
      expect(prefs.getString(_pinHash), 'x:y');
      await store.remove(_failed);
      expect(prefs.containsKey(_failed), isFalse);
    });

    test('Änderung im Fallback gewinnt beim nächsten Migrationsversuch',
        () async {
      final prefs = await prefsWith(_legacyValues());
      backend.failAllWrites = true;
      final store = await load(prefs);
      await _service(store).setPin('9999');

      backend.failAllWrites = false;
      final second = await load(prefs);
      final service = _service(second);
      expect(service.verifyPin('9999'), isTrue);
      expect(service.verifyPin('1234'), isFalse);
    });
  });

  group('Marker gesetzt: Secure-Speicher ist die Wahrheit', () {
    test('Abbruch nach Marker vor Löschen: Legacy-Keys werden entfernt',
        () async {
      backend = FakeAppLockBackend({_pinHash: 'secure:hash', _enabled: 'true'});
      final prefs = await prefsWith({
        _marker: 1,
        _pinHash: 'legacy:hash',
        _failed: 2,
      });
      final store = await load(prefs);
      expect(store.getString(_pinHash), 'secure:hash');
      expect(store.getInt(_failed), isNull);
      expect(_lockKeys(prefs), {_marker});
      expect(backend.writes, isEmpty);
    });

    test('Löschen der Legacy-Keys scheitert: Marker bleibt, kein Fehler',
        () async {
      backend = FakeAppLockBackend({_pinHash: 'secure:hash'});
      final prefs = _FlakyPrefs(await prefsWith({
        _marker: 1,
        _pinHash: 'legacy:hash',
      }));
      prefs.throwOnRemove = true;
      final store = await load(prefs);
      expect(store.getString(_pinHash), 'secure:hash');
      expect(prefs.getInt(_marker), 1);
    });

    test(
        'Löschen scheitert nach erfolgreicher Migration: Store läuft über Secure',
        () async {
      final prefs = _FlakyPrefs(await prefsWith(_legacyValues()));
      prefs.throwOnRemove = true;
      final store = await load(prefs);
      expect(prefs.getInt(_marker), 1);
      expect(_service(store).verifyPin('1234'), isTrue);

      // Neuer Start: Marker gesetzt, Legacy-Reste werden aufgeräumt.
      prefs.throwOnRemove = false;
      await load(prefs);
      expect(_lockKeys(prefs), {_marker});
    });

    test('Restore: Marker in Prefs, Secure leer -> Sperre aus, keine PIN',
        () async {
      final prefs = await prefsWith({_marker: 1});
      final store = await load(prefs);
      final service = _service(store);
      expect(service.hasPin, isFalse);
      expect(service.isEnabled, isFalse);
      expect(service.hasRecoveryCode, isFalse);
      expect(backend.writes, isEmpty);
    });

    test('nach einem Restore lässt sich die Sperre normal neu einrichten',
        () async {
      final prefs = await prefsWith({_marker: 1});
      final store = await load(prefs);
      final service = _service(store);
      await service.setPin('4711');
      await service.setEnabled(true);
      expect(backend.data[_enabled], 'true');
      expect(backend.data[_pinHash], isNotNull);
      expect(_lockKeys(prefs), {_marker});
    });

    test('Lesefehler im Normalbetrieb: ein Wiederholversuch hilft', () async {
      backend = FakeAppLockBackend({_pinHash: 's:h'});
      backend.failReads = 1;
      final prefs = await prefsWith({_marker: 1});
      final store = await load(prefs);
      expect(backend.readCount, 2);
      expect(store.getString(_pinHash), 's:h');
    });

    test('Lesefehler im Normalbetrieb: nach dem Retry leer, keine Exception',
        () async {
      backend = FakeAppLockBackend({_pinHash: 's:h'});
      backend.failReads = 5;
      final prefs = await prefsWith({_marker: 1});
      final store = await load(prefs);
      expect(backend.readCount, 2);
      final service = _service(store);
      expect(service.hasPin, isFalse);
      expect(service.isEnabled, isFalse);
      expect(prefs.getInt(_marker), 1);
    });

    test('Zeitlimit im Normalbetrieb: leerer Store', () async {
      backend = FakeAppLockBackend({_pinHash: 's:h'});
      final hold = Completer<void>();
      backend.holdReads = hold;
      final prefs = await prefsWith({_marker: 1});
      final store =
          await load(prefs, timeout: const Duration(milliseconds: 50));
      expect(store.getString(_pinHash), isNull);
      hold.complete();
    });
  });

  group('Neuinstallation und Web', () {
    test('Neuinstallation: Marker gesetzt, leerer Store, nichts geschrieben',
        () async {
      final prefs = await prefsWith({});
      final store = await load(prefs);
      expect(prefs.getInt(_marker), 1);
      expect(_service(store).hasPin, isFalse);
      expect(_service(store).isEnabled, isFalse);
      expect(backend.writes, isEmpty);
    });

    test('Web: kein Backend-Aufruf, Prefs unberührt', () async {
      final prefs = await prefsWith(_legacyValues());
      final store = await AppLockStore.load(
        prefs: prefs,
        secure: backend,
        isWeb: true,
      );
      expect(backend.log, isEmpty);
      expect(prefs.getInt(_marker), isNull);
      expect(store.getString(_pinHash), isNull);
    });
  });
}

/// Wirft beim n-ten `readAll`.
class _ThrowOnNthRead implements AppLockBackend {
  final AppLockBackend inner;
  final int n;
  int _count = 0;

  _ThrowOnNthRead(this.inner, this.n);

  @override
  Future<Map<String, String>> readAll() async {
    if (++_count == n) throw StateError('read failed');
    return inner.readAll();
  }

  @override
  Future<void> write(String key, String value) => inner.write(key, value);

  @override
  Future<void> delete(String key) => inner.delete(key);
}
