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

  final SharedPreferences _prefs;
  final LocalAuthentication _localAuth;

  AppLockService({required SharedPreferences prefs, required LocalAuthentication localAuth})
      : _prefs = prefs,
        _localAuth = localAuth;

  /// Ob die App-Sperre aktiviert ist.
  bool get isEnabled => _prefs.getBool(_appLockEnabledKey) ?? false;

  Future<void> setEnabled(bool enabled) async {
    await _prefs.setBool(_appLockEnabledKey, enabled);
  }

  /// Ob bereits eine PIN als Fallback hinterlegt ist.
  bool get hasPin => _prefs.getString(_pinHashKey) != null;

  Future<void> setPin(String pin) async {
    final salt = generateSalt();
    await _prefs.setString(_pinSaltKey, salt);
    await _prefs.setString(_pinHashKey, hashPin(pin, salt));
  }

  bool verifyPin(String pin) {
    final storedHash = _prefs.getString(_pinHashKey);
    final salt = _prefs.getString(_pinSaltKey);
    if (storedHash == null || salt == null) return false;
    return hashPin(pin, salt) == storedHash;
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

  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Bitte authentifizieren Sie sich, um die App zu entsperren',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
    } catch (_) {
      return false;
    }
  }
}
