import 'dart:async';

import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/utils/app_lock_lockout.dart';
import '../../domain/utils/pin_hash.dart';

/// Verwaltet die PIN-/Biometrie-Sperre der App (siehe #223).
///
/// Die PIN wird niemals im Klartext gespeichert, sondern nur als gesalzener
/// SHA-256-Hash (siehe [hashPin]). Biometrie läuft komplett über
/// `local_auth` und das Betriebssystem - die App selbst bekommt nie
/// Fingerabdruck-/Face-ID-Rohdaten zu sehen.
class AppLockService {
  static const _appLockEnabledKey = 'app_lock_enabled';
  static const _pinHashKey = 'app_lock_pin_hash';
  static const _pinSaltKey = 'app_lock_pin_salt';
  static const _recoveryHashKey = 'app_lock_recovery_code_hash';

  // Brute-Force-Limit (siehe #358). Gerätebezogen, daher ohne uid/profileId.
  static const _failedAttemptsKey = 'app_lock_failed_attempts';
  static const _lockedUntilKey = 'app_lock_locked_until_ms';
  static const _lastSeenKey = 'app_lock_last_seen_ms';

  final SharedPreferences _prefs;
  final LocalAuthentication _localAuth;
  final DateTime Function() _now;
  final Duration Function() _monotonic;

  // Sperre der laufenden Sitzung, gemessen mit der monotonen Uhr (immun gegen
  // Umstellen der Wanduhr). Nach einem Neustart gilt die Wanduhr.
  Duration? _sessionLockStart;
  Duration _sessionLockDuration = Duration.zero;

  AppLockService({
    required SharedPreferences prefs,
    required LocalAuthentication localAuth,
    DateTime Function()? now,
    Duration Function()? monotonic,
  })  : _prefs = prefs,
        _localAuth = localAuth,
        _now = now ?? DateTime.now,
        _monotonic = monotonic ?? _stopwatchMonotonic();

  static Duration Function() _stopwatchMonotonic() {
    final stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsed;
  }

  int get _nowMs => _now().toUtc().millisecondsSinceEpoch;
  int get _failedAttempts => _prefs.getInt(_failedAttemptsKey) ?? 0;

  /// Ob die App-Sperre aktiviert ist.
  bool get isEnabled => _prefs.getBool(_appLockEnabledKey) ?? false;

  Future<void> setEnabled(bool enabled) async {
    await _prefs.setBool(_appLockEnabledKey, enabled);
  }

  /// Ob bereits eine PIN als Fallback hinterlegt ist.
  bool get hasPin => _prefs.getString(_pinHashKey) != null;

  /// Salt und Hash stehen in EINEM Wert (`salt:hash`), damit ein Abbruch
  /// (z. B. Prozess-Kill) nie einen unpassenden Salt/Hash-Mix hinterlässt.
  /// Ältere Installationen haben den Salt noch in [_pinSaltKey] (Hash ohne `:`).
  Future<void> setPin(String pin) async {
    final salt = generateSalt();
    await _prefs.setString(_pinHashKey, '$salt:${hashPin(pin, salt)}');
    await _prefs.remove(_pinSaltKey);
    await resetAttempts();
  }

  bool verifyPin(String pin) {
    final stored = _prefs.getString(_pinHashKey);
    if (stored == null) return false;
    final parts = stored.split(':');
    if (parts.length == 2) return hashPin(pin, parts[0]) == parts[1];
    final salt = _prefs.getString(_pinSaltKey);
    if (salt == null) return false;
    return hashPin(pin, salt) == stored;
  }

  /// Ob ein Wiederherstellungscode gespeichert ist (siehe #288).
  bool get hasRecoveryCode => _prefs.getString(_recoveryHashKey) != null;

  /// Setzt PIN und Wiederherstellungscode gemeinsam (ersetzt beides). Der
  /// Code wird nur als gesalzener Hash gespeichert und nie geloggt.
  ///
  /// Reihenfolge: erst der Code (neuer Wert, einzelner Schreibvorgang), dann
  /// die PIN. Bei einem Abbruch dazwischen gilt weiter die alte PIN; ein
  /// Salt/Hash-Mismatch (Aussperrung) ist ausgeschlossen.
  Future<void> setPinWithRecoveryCode(String pin, String recoveryCode) async {
    final codeSalt = generateSalt();
    final code = normalizeRecoveryCode(recoveryCode);
    await _prefs.setString(
        _recoveryHashKey, '$codeSalt:${hashPin(code, codeSalt)}');
    await setPin(pin);
  }

  bool verifyRecoveryCode(String input) {
    final stored = _prefs.getString(_recoveryHashKey);
    if (stored == null) return false;
    final parts = stored.split(':');
    if (parts.length != 2) return false;
    return hashPin(normalizeRecoveryCode(input), parts[0]) == parts[1];
  }

  Future<void> clearPin() async {
    await _prefs.remove(_pinHashKey);
    await _prefs.remove(_pinSaltKey);
    await resetAttempts();
  }

  /// Verbleibende Wartezeit der Sperre (rein lesend, siehe #358).
  Duration get remainingLockout {
    final start = _sessionLockStart;
    if (start != null) {
      final left = _sessionLockDuration - (_monotonic() - start);
      return left.isNegative ? Duration.zero : left;
    }
    final lockedUntil = _prefs.getInt(_lockedUntilKey);
    if (lockedUntil == null) return Duration.zero;
    final leftMs = lockedUntil - _nowMs;
    return leftMs <= 0 ? Duration.zero : Duration(milliseconds: leftMs);
  }

  /// Gleicht die Sperre beim Öffnen des Screens mit der Uhr ab. Eine
  /// zurückgestellte Uhr (mehr als [appLockClockTolerance] hinter der zuletzt
  /// beobachteten Zeit) setzt die volle aktuelle Stufendauer neu an.
  Future<Duration> syncLockout() async {
    final now = _nowMs;
    final lastSeen = _prefs.getInt(_lastSeenKey);
    if (_sessionLockStart != null) {
      if (lastSeen == null || now > lastSeen) {
        await _prefs.setInt(_lastSeenKey, now);
      }
      return remainingLockout;
    }
    if (lastSeen != null &&
        now < lastSeen - appLockClockTolerance.inMilliseconds) {
      final failed = _failedAttempts;
      if (failed > 0) {
        final duration = lockoutDurationFor(failed);
        if (duration > Duration.zero) {
          await _prefs.setInt(_lockedUntilKey, now + duration.inMilliseconds);
        }
      }
      await _prefs.setInt(_lastSeenKey, now);
    } else if (lastSeen == null || now > lastSeen) {
      await _prefs.setInt(_lastSeenKey, now);
    }
    return remainingLockout;
  }

  /// Setzt Zähler und Sperre zurück; `lastSeen` bleibt erhalten.
  Future<void> resetAttempts() async {
    _sessionLockStart = null;
    _sessionLockDuration = Duration.zero;
    await _prefs.remove(_failedAttemptsKey);
    await _prefs.remove(_lockedUntilKey);
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
    final lastSeen = _prefs.getInt(_lastSeenKey) ?? now;
    await Future.wait([
      _prefs.setInt(_failedAttemptsKey, failed),
      if (duration > Duration.zero)
        _prefs.setInt(_lockedUntilKey, now + duration.inMilliseconds)
      else
        _prefs.remove(_lockedUntilKey),
      _prefs.setInt(_lastSeenKey, now > lastSeen ? now : lastSeen),
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
