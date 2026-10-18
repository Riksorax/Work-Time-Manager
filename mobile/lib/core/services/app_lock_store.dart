import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/logger.dart';

/// Schlüssel der App-Sperre (siehe #223, #358, #375). Die Namen entsprechen
/// den früheren SharedPreferences-Keys; im sicheren Speicher stehen sie
/// unverändert.
abstract final class AppLockKeys {
  static const enabled = 'app_lock_enabled';
  static const pinHash = 'app_lock_pin_hash';
  static const pinSalt = 'app_lock_pin_salt';
  static const recoveryHash = 'app_lock_recovery_code_hash';
  static const failedAttempts = 'app_lock_failed_attempts';
  static const lockedUntil = 'app_lock_locked_until_ms';
  static const lastSeen = 'app_lock_last_seen_ms';

  /// Marker in den SharedPreferences (bleibt im Backup): die Migration in den
  /// sicheren Speicher ist abgeschlossen.
  static const storageVersion = 'app_lock_storage_version';

  /// Alle Sperr-Werte; `enabled` steht zuletzt (wird bei der Migration als
  /// Letztes geschrieben).
  static const all = [
    pinHash,
    pinSalt,
    recoveryHash,
    failedAttempts,
    lockedUntil,
    lastSeen,
    enabled,
  ];

  static const _boolKeys = {enabled};
  static const _intKeys = {failedAttempts, lockedUntil, lastSeen};
}

/// Persistenzschicht des [AppLockStore]. Alle Werte sind Strings.
abstract class AppLockBackend {
  Future<Map<String, String>> readAll();
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// `flutter_secure_storage` (Android: Keystore-gebunden, Dateien sind per
/// `dataExtractionRules`/`fullBackupContent` vom Backup ausgenommen).
class SecureAppLockBackend implements AppLockBackend {
  static const _opTimeout = Duration(seconds: 10);

  final FlutterSecureStorage _storage;

  SecureAppLockBackend([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<Map<String, String>> readAll() =>
      _storage.readAll().timeout(_opTimeout);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value).timeout(_opTimeout);

  @override
  Future<void> delete(String key) =>
      _storage.delete(key: key).timeout(_opTimeout);
}

/// Nur als Fallback, wenn die Migration scheitert: die Werte bleiben wie im
/// alten Build in den SharedPreferences (mit den ursprünglichen Typen), damit
/// niemand ausgesperrt wird.
class PrefsAppLockBackend implements AppLockBackend {
  final SharedPreferences _prefs;

  PrefsAppLockBackend(this._prefs);

  @override
  Future<Map<String, String>> readAll() async => _readLegacy(_prefs);

  @override
  Future<void> write(String key, String value) async {
    if (AppLockKeys._boolKeys.contains(key)) {
      await _prefs.setBool(key, value == 'true');
    } else if (AppLockKeys._intKeys.contains(key)) {
      await _prefs.setInt(key, int.parse(value));
    } else {
      await _prefs.setString(key, value);
    }
  }

  @override
  Future<void> delete(String key) async {
    await _prefs.remove(key);
  }
}

/// Nur im Speicher (Web, Tests, Default des Providers).
class InMemoryAppLockBackend implements AppLockBackend {
  final Map<String, String> _data = {};

  @override
  Future<Map<String, String>> readAll() async => {..._data};

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);
}

Map<String, String> _readLegacy(SharedPreferences prefs) {
  final result = <String, String>{};
  for (final key in AppLockKeys.all) {
    final value = prefs.get(key);
    if (value != null) result[key] = value.toString();
  }
  return result;
}

class _CancelToken {
  bool cancelled = false;

  /// Die Migration schreibt gerade den Marker (oder hat ihn geschrieben): ab
  /// hier ist der sichere Speicher die Wahrheit, ein Abbruch ist nicht mehr
  /// möglich und `load` muss das Ende der Migration abwarten.
  bool committed = false;
}

/// Synchron lesbarer Speicher der App-Sperre (siehe #375).
///
/// Ein In-Memory-Cache bedient die synchronen Getter (`AppLockService.hasPin`,
/// `isAppLockedProvider`, ...); Schreibzugriffe aktualisieren den Cache
/// **zuerst** und sind danach ein Write-Through in das [AppLockBackend]. Der
/// Cache ist damit nie älter als der letzte Schreibaufruf.
///
/// Genau eine Instanz pro Prozess (über `appLockStoreProvider`, in `main.dart`
/// überschrieben); sie wird vor `runApp` per [load] aufgebaut.
class AppLockStore {
  final AppLockBackend _backend;
  final Map<String, String> _cache;

  AppLockStore(AppLockBackend backend, {Map<String, String>? initial})
      : _backend = backend,
        _cache = {...?initial};

  /// Nur im Speicher; Default des Providers, für Web und Tests.
  factory AppLockStore.inMemory([Map<String, String>? initial]) =>
      AppLockStore(InMemoryAppLockBackend(), initial: initial);

  bool? getBool(String key) => switch (_cache[key]) {
        'true' => true,
        'false' => false,
        _ => null,
      };

  int? getInt(String key) {
    final raw = _cache[key];
    return raw == null ? null : int.tryParse(raw);
  }

  String? getString(String key) => _cache[key];

  /// Mit [rollbackOnError] wird der Cache bei einem Backend-Fehler auf den
  /// vorherigen Wert zurückgesetzt (sofern er nicht inzwischen neu gesetzt
  /// wurde); die Exception wird in jedem Fall weitergeworfen.
  Future<void> setBool(String key, bool value,
          {bool rollbackOnError = false}) =>
      _put(key, '$value', rollbackOnError);

  Future<void> setInt(String key, int value, {bool rollbackOnError = false}) =>
      _put(key, '$value', rollbackOnError);

  Future<void> setString(String key, String value,
          {bool rollbackOnError = false}) =>
      _put(key, value, rollbackOnError);

  Future<void> remove(String key, {bool rollbackOnError = false}) =>
      _put(key, null, rollbackOnError);

  Future<void> _put(String key, String? value, bool rollback) async {
    final previous = _cache[key];
    _apply(key, value);
    try {
      if (value == null) {
        await _backend.delete(key);
      } else {
        await _backend.write(key, value);
      }
    } catch (_) {
      if (rollback && _cache[key] == value) _apply(key, previous);
      rethrow;
    }
  }

  void _apply(String key, String? value) {
    if (value == null) {
      _cache.remove(key);
    } else {
      _cache[key] = value;
    }
  }

  /// Baut den Store auf und migriert bestehende Installationen einmalig aus
  /// den SharedPreferences in den sicheren Speicher. Wirft nie.
  ///
  /// - Marker gesetzt: der sichere Speicher ist die Wahrheit; übrig gebliebene
  ///   Legacy-Keys in den Prefs werden entfernt. Nicht lesbar: leerer Store
  ///   (Sperre aus, bewusst fail-open).
  /// - Kein Marker, keine Legacy-Keys (Neuinstallation, Restore): Marker
  ///   setzen, leerer Store.
  /// - Kein Marker, Legacy-Keys (Update): kopieren, zurücklesen, vergleichen,
  ///   Marker setzen, Legacy-Keys löschen. Jeder Fehler lässt die Prefs
  ///   unverändert und der Store läuft im Fallback über [PrefsAppLockBackend]
  ///   (nächster Start versucht es erneut). Niemand wird ausgesperrt.
  static Future<AppLockStore> load({
    required SharedPreferences prefs,
    AppLockBackend? secure,
    bool? isWeb,
    Duration timeout = const Duration(seconds: 8),
    Duration retryDelay = const Duration(milliseconds: 300),
  }) async {
    if (isWeb ?? kIsWeb) return AppLockStore.inMemory();
    final backend = secure ?? SecureAppLockBackend();
    final token = _CancelToken();
    final inner = _loadInner(prefs, backend, token, retryDelay);
    try {
      return await inner.timeout(timeout);
    } catch (e) {
      // Zeitlimit (oder ein unerwarteter Fehler): eine noch laufende
      // Migration darf danach nichts mehr an den Prefs ändern.
      token.cancelled = true;
      logger.e('AppLockStore.load abgebrochen (${e.runtimeType})');
      if (token.committed) {
        // Der Marker ist (oder wird gerade) geschrieben: der nächste Start
        // läse den sicheren Speicher, ein Prefs-Fallback würde neue Werte
        // verlieren. Die Migration ist dann nur noch Rücklese-frei und kurz.
        try {
          return await inner;
        } catch (_) {
          // fällt unten in den Fallback
        }
      } else {
        inner.ignore();
      }
      return prefs.containsKey(AppLockKeys.storageVersion)
          ? AppLockStore(backend)
          : AppLockStore(PrefsAppLockBackend(prefs),
              initial: _readLegacy(prefs));
    }
  }

  static Future<AppLockStore> _loadInner(
    SharedPreferences prefs,
    AppLockBackend backend,
    _CancelToken token,
    Duration retryDelay,
  ) async {
    final legacy = _readLegacy(prefs);

    if (prefs.containsKey(AppLockKeys.storageVersion)) {
      if (legacy.isNotEmpty) await _removeLegacy(prefs, legacy.keys, token);
      try {
        return AppLockStore(backend,
            initial: await _readWithRetry(backend, retryDelay));
      } catch (e) {
        logger.e('App-Sperre: sicherer Speicher nicht lesbar '
            '(${e.runtimeType}), Sperre ist aus');
        return AppLockStore(backend);
      }
    }

    if (legacy.isEmpty) {
      try {
        await _setMarker(prefs);
      } catch (e) {
        logger.e('App-Sperre: Marker nicht gesetzt (${e.runtimeType})');
      }
      return AppLockStore(backend);
    }

    try {
      final migrated = await _migrate(prefs, backend, legacy, token);
      return AppLockStore(backend, initial: migrated);
    } catch (e) {
      logger.e('App-Sperre: Migration fehlgeschlagen (${e.runtimeType}), '
          'Fallback auf SharedPreferences');
      return AppLockStore(PrefsAppLockBackend(prefs), initial: legacy);
    }
  }

  static Future<Map<String, String>> _readWithRetry(
      AppLockBackend backend, Duration retryDelay) async {
    try {
      return await backend.readAll();
    } catch (_) {
      await Future<void>.delayed(retryDelay);
      return backend.readAll();
    }
  }

  static Future<Map<String, String>> _migrate(
    SharedPreferences prefs,
    AppLockBackend backend,
    Map<String, String> legacy,
    _CancelToken token,
  ) async {
    // Die Prefs-Werte gewinnen (ein früherer, abgebrochener Lauf hat evtl.
    // veraltete Kopien hinterlassen); Reste ohne Gegenstück werden entfernt.
    final existing = await backend.readAll();
    final stale = AppLockKeys.all
        .where((k) => existing.containsKey(k) && !legacy.containsKey(k))
        .toList();
    for (final key in stale) {
      await backend.delete(key);
    }
    for (final key in AppLockKeys.all) {
      final value = legacy[key];
      if (value != null) await backend.write(key, value);
    }

    final back = await backend.readAll();
    for (final entry in legacy.entries) {
      if (back[entry.key] != entry.value) {
        throw StateError('Rücklesen: Wert für ${entry.key} weicht ab');
      }
    }
    for (final key in stale) {
      if (back.containsKey(key)) {
        throw StateError('Rücklesen: $key nicht entfernt');
      }
    }

    if (token.cancelled) throw StateError('Migration abgebrochen');
    // Synchron zur Prüfung oben (kein await dazwischen): ab hier gilt der
    // sichere Speicher, auch wenn das Zeitlimit während des Schreibens feuert.
    token.committed = true;
    try {
      await _setMarker(prefs);
    } catch (_) {
      token.committed = false;
      rethrow;
    }
    await _removeLegacy(prefs, legacy.keys, token);
    return {for (final k in legacy.keys) k: back[k]!};
  }

  static Future<void> _setMarker(SharedPreferences prefs) async {
    if (!await prefs.setInt(AppLockKeys.storageVersion, 1)) {
      throw StateError('Marker nicht geschrieben');
    }
  }

  /// Löscht die Legacy-Keys best effort (Fehler nur geloggt).
  static Future<void> _removeLegacy(
    SharedPreferences prefs,
    Iterable<String> keys,
    _CancelToken token,
  ) async {
    for (final key in keys.toList()) {
      if (token.cancelled) return;
      try {
        await prefs.remove(key);
      } catch (e) {
        logger.e('App-Sperre: Legacy-Key nicht gelöscht (${e.runtimeType})');
      }
    }
  }
}
