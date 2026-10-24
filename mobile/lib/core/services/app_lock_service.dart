import 'dart:async';

import 'package:local_auth/local_auth.dart';

import '../../domain/utils/app_lock_lockout.dart';
import '../../domain/utils/pin_hash.dart';
import '../utils/logger.dart';
import 'app_lock_store.dart';

/// Verwaltet die PIN-/Biometrie-Sperre der App (siehe #223).
///
/// Die PIN wird niemals im Klartext gespeichert, sondern nur als gesalzener
/// SHA-256-Hash (siehe [hashPin]). Alle Werte liegen im [AppLockStore]
/// (sicherer Speicher, vom Android-Backup ausgenommen, siehe #375). Biometrie läuft komplett über
/// `local_auth` und das Betriebssystem - die App selbst bekommt nie
/// Fingerabdruck-/Face-ID-Rohdaten zu sehen.
class AppLockService {
  static const _appLockEnabledKey = AppLockKeys.enabled;
  static const _pinHashKey = AppLockKeys.pinHash;
  static const _pinSaltKey = AppLockKeys.pinSalt;
  static const _recoveryHashKey = AppLockKeys.recoveryHash;

  // Brute-Force-Limit (siehe #358). Gerätebezogen, daher ohne uid/profileId.
  static const _failedAttemptsKey = AppLockKeys.failedAttempts;
  static const _lockedUntilKey = AppLockKeys.lockedUntil;
  static const _lastSeenKey = AppLockKeys.lastSeen;

  final AppLockStore _store;
  final LocalAuthentication _localAuth;
  final DateTime Function() _now;
  final Duration Function() _monotonic;

  // Sperre der laufenden Sitzung, gemessen mit der monotonen Uhr (immun gegen
  // Umstellen der Wanduhr). Nach einem Neustart gilt die Wanduhr.
  Duration? _sessionLockStart;
  Duration _sessionLockDuration = Duration.zero;

  AppLockService({
    required AppLockStore store,
    required LocalAuthentication localAuth,
    DateTime Function()? now,
    Duration Function()? monotonic,
  })  : _store = store,
        _localAuth = localAuth,
        _now = now ?? DateTime.now,
        _monotonic = monotonic ?? _stopwatchMonotonic();

  static Duration Function() _stopwatchMonotonic() {
    final stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsed;
  }

  int get _nowMs => _now().toUtc().millisecondsSinceEpoch;
  int get _failedAttempts => _store.getInt(_failedAttemptsKey) ?? 0;

  /// Ob die App-Sperre aktiviert ist.
  bool get isEnabled => _store.getBool(_appLockEnabledKey) ?? false;

  Future<void> setEnabled(bool enabled) => _persist(
      () => _store.setBool(_appLockEnabledKey, enabled, rollbackOnError: true));

  /// Einrichtungs-Schreibzugriffe (PIN, Code, `enabled`): Der Store rollt den
  /// Cache bei einem Fehler zurück; hier wird geloggt (ohne Werte) und die
  /// Exception weitergeworfen, damit die UI nie eine PIN zeigt, die nach einem
  /// Neustart weg wäre (#375).
  Future<void> _persist(Future<void> Function() write) async {
    try {
      await write();
    } catch (e) {
      logger.e('App-Sperre: Speichern fehlgeschlagen (${e.runtimeType})');
      rethrow;
    }
  }

  /// Zähler, Sperrzeit und `last_seen`: Der Cache bleibt (fail-closed im
  /// Prozess), ein Persistenzfehler wird nur geloggt und nicht weitergeworfen
  /// (sonst meldet ihn `PlatformDispatcher.onError` als fatalen Absturz).
  Future<void> _persistQuietly(Future<void> Function() write) async {
    try {
      await write();
    } catch (e) {
      logger.e('App-Sperre: Zähler nicht gespeichert (${e.runtimeType})');
    }
  }

  /// Ob bereits eine PIN als Fallback hinterlegt ist.
  bool get hasPin => _store.getString(_pinHashKey) != null;

  /// Ob die Sperre die App beim Start wirklich sperrt (aktiviert und PIN da).
  bool get isActive => isEnabled && hasPin;

  /// Salt und Hash stehen in EINEM Wert (`salt:hash`), damit ein Abbruch
  /// (z. B. Prozess-Kill) nie einen unpassenden Salt/Hash-Mix hinterlässt.
  /// Ältere Installationen haben den Salt noch in [_pinSaltKey] (Hash ohne `:`).
  Future<void> setPin(String pin) async {
    final salt = generateSalt();
    await _persist(() => _store.setString(
        _pinHashKey, '$salt:${hashPin(pin, salt)}',
        rollbackOnError: true));
    // Der Hash trägt jetzt seinen Salt selbst; ein übrig gebliebener
    // Legacy-Salt ist wirkungslos, sein Entfernen daher nicht kritisch.
    await _persistQuietly(() => _store.remove(_pinSaltKey));
    await resetAttempts();
  }

  bool verifyPin(String pin) {
    final stored = _store.getString(_pinHashKey);
    if (stored == null) return false;
    final parts = stored.split(':');
    if (parts.length == 2) return hashPin(pin, parts[0]) == parts[1];
    final salt = _store.getString(_pinSaltKey);
    if (salt == null) return false;
    return hashPin(pin, salt) == stored;
  }

  /// Ob ein Wiederherstellungscode gespeichert ist (siehe #288).
  bool get hasRecoveryCode => _store.getString(_recoveryHashKey) != null;

  /// Setzt PIN und Wiederherstellungscode gemeinsam (ersetzt beides). Der
  /// Code wird nur als gesalzener Hash gespeichert und nie geloggt.
  ///
  /// Reihenfolge: erst der Code (neuer Wert, einzelner Schreibvorgang), dann
  /// die PIN. Bei einem Abbruch dazwischen gilt weiter die alte PIN; ein
  /// Salt/Hash-Mismatch (Aussperrung) ist ausgeschlossen. Scheitert `setPin`,
  /// wird der vorherige Code wiederhergestellt (alte PIN + alter Code gelten).
  Future<void> setPinWithRecoveryCode(String pin, String recoveryCode) async {
    final codeSalt = generateSalt();
    final code = normalizeRecoveryCode(recoveryCode);
    final previousCode = _store.getString(_recoveryHashKey);
    await _persist(() => _store.setString(
        _recoveryHashKey, '$codeSalt:${hashPin(code, codeSalt)}',
        rollbackOnError: true));
    try {
      await setPin(pin);
    } catch (_) {
      await _persistQuietly(() => previousCode == null
          ? _store.remove(_recoveryHashKey)
          : _store.setString(_recoveryHashKey, previousCode));
      rethrow;
    }
  }

  bool verifyRecoveryCode(String input) {
    final stored = _store.getString(_recoveryHashKey);
    if (stored == null) return false;
    final parts = stored.split(':');
    if (parts.length != 2) return false;
    return hashPin(normalizeRecoveryCode(input), parts[0]) == parts[1];
  }

  Future<void> clearPin() async {
    await _persist(() => _store.remove(_pinHashKey, rollbackOnError: true));
    await _persistQuietly(() => _store.remove(_pinSaltKey));
    await resetAttempts();
  }

  /// Verbleibende Wartezeit der Sperre (rein lesend, siehe #358).
  Duration get remainingLockout {
    final start = _sessionLockStart;
    if (start != null) {
      final left = _sessionLockDuration - (_monotonic() - start);
      return left.isNegative ? Duration.zero : left;
    }
    final lockedUntil = _store.getInt(_lockedUntilKey);
    if (lockedUntil == null) return Duration.zero;
    final leftMs = lockedUntil - _nowMs;
    return leftMs <= 0 ? Duration.zero : Duration(milliseconds: leftMs);
  }

  /// Gleicht die Sperre beim Öffnen des Screens mit der Uhr ab. Eine
  /// zurückgestellte Uhr (mehr als [appLockClockTolerance] hinter der zuletzt
  /// beobachteten Zeit) setzt die volle aktuelle Stufendauer neu an.
  Future<Duration> syncLockout() async {
    final now = _nowMs;
    final lastSeen = _store.getInt(_lastSeenKey);
    if (_sessionLockStart != null) {
      if (lastSeen == null || now > lastSeen) {
        await _persistQuietly(() => _store.setInt(_lastSeenKey, now));
      }
      return remainingLockout;
    }
    if (lastSeen != null &&
        now < lastSeen - appLockClockTolerance.inMilliseconds) {
      final failed = _failedAttempts;
      if (failed > 0) {
        final duration = lockoutDurationFor(failed);
        if (duration > Duration.zero) {
          await _persistQuietly(() =>
              _store.setInt(_lockedUntilKey, now + duration.inMilliseconds));
        }
      }
      await _persistQuietly(() => _store.setInt(_lastSeenKey, now));
    } else if (lastSeen == null || now > lastSeen) {
      await _persistQuietly(() => _store.setInt(_lastSeenKey, now));
    }
    return remainingLockout;
  }

  /// Setzt Zähler und Sperre zurück; `lastSeen` bleibt erhalten.
  Future<void> resetAttempts() async {
    _sessionLockStart = null;
    _sessionLockDuration = Duration.zero;
    await _persistQuietly(() => _store.remove(_failedAttemptsKey));
    await _persistQuietly(() => _store.remove(_lockedUntilKey));
  }

  /// Gezählter PIN-Versuch (siehe #358).
  Future<AttemptResult> attemptPin(String pin) =>
      _attempt(() => verifyPin(pin));

  /// Gezählter Wiederherstellungscode-Versuch (gemeinsamer Zähler).
  Future<AttemptResult> attemptRecoveryCode(String code) =>
      _attempt(() => verifyRecoveryCode(code));

  // Serialisiert Versuche: Prüfung der Sperre, Zählen und Verifizieren
  // laufen je Versuch am Stück, parallele Aufrufe (Doppeltipp, zwei Dialoge,
  // programmatisch) können die Sperre nicht unterlaufen. Ohne laufenden
  // Versuch entsteht kein zusätzlicher Warte-Schritt.
  Future<void>? _attemptInFlight;

  Future<AttemptResult> _attempt(bool Function() verify) {
    final previous = _attemptInFlight;
    if (previous != null) return previous.then((_) => _attempt(verify));
    final done = Completer<void>();
    _attemptInFlight = done.future;
    final result = _attemptSerialized(verify);
    void finish() {
      _attemptInFlight = null;
      done.complete();
    }

    result.then((_) => finish(), onError: (_) => finish());
    return result;
  }

  Future<AttemptResult> _attemptSerialized(bool Function() verify) async {
    final remaining = await syncLockout();
    if (remaining > Duration.zero) return AttemptLocked(remaining);

    // Persist-before-verify: der Versuch darf auch bei Hard-Kill nach dem
    // Tippen nicht verloren gehen.
    final failed = _failedAttempts + 1;
    final duration = lockoutDurationFor(failed);
    final now = _nowMs;
    final lastSeen = _store.getInt(_lastSeenKey) ?? now;
    await Future.wait([
      _persistQuietly(() => _store.setInt(_failedAttemptsKey, failed)),
      if (duration > Duration.zero)
        _persistQuietly(
            () => _store.setInt(_lockedUntilKey, now + duration.inMilliseconds))
      else
        _persistQuietly(() => _store.remove(_lockedUntilKey)),
      _persistQuietly(
          () => _store.setInt(_lastSeenKey, now > lastSeen ? now : lastSeen)),
    ]);
    if (duration > Duration.zero) {
      _sessionLockStart = _monotonic();
      _sessionLockDuration = duration;
    } else {
      _sessionLockStart = null;
      _sessionLockDuration = Duration.zero;
    }

    if (verify()) {
      await resetAttempts();
      return const AttemptSuccess();
    }
    return AttemptWrong(duration);
  }

  Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics(
      {required String localizedReason}) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: true,
        // Setzt die Authentifizierung nach Rückkehr aus dem Hintergrund
        // automatisch fort, statt mit einem Fehler abzubrechen.
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
