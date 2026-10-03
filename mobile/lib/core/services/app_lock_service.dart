import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  final SharedPreferences _prefs;
  final LocalAuthentication _localAuth;

  AppLockService(
      {required SharedPreferences prefs,
      required LocalAuthentication localAuth})
      : _prefs = prefs,
        _localAuth = localAuth;

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
