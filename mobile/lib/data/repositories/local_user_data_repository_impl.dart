import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/local_user_data_repository.dart';

/// Entfernt die nutzer- und profilbezogenen Schlüssel eines Nutzers aus den
/// SharedPreferences (#581). Die vollständige Liste mit Begründung, was
/// bleibt, steht in `mobile/CLAUDE.md`, „Konto-Löschung“.
///
/// Alle Schlüssel haben die Form `<präfix><uid>` (Standard-Profil) bzw.
/// `<präfix><uid>_<profilId>` (zusätzliches Profil). Firebase-UIDs enthalten
/// keinen Unterstrich, deshalb trifft `<präfix><uid>_` nie einen anderen
/// Nutzer. Gast-Werte (`…_local…`, `local_*`) und geräteweite Werte haben
/// keine UID im Schlüssel und bleiben stehen.
class LocalUserDataRepositoryImpl implements LocalUserDataRepository {
  LocalUserDataRepositoryImpl(this._prefs);

  final SharedPreferences _prefs;

  /// Präfixe der Schlüssel je Nutzer und Profil. Neue nutzerbezogene
  /// Schlüssel hier ergänzen (der Test `local_user_data_repository_test`
  /// schreibt über die echten Repositories und prüft, dass danach kein
  /// Schlüssel mit der UID übrig ist).
  static const userScopedKeyPrefixes = <String>[
    // SettingsRepositoryImpl (je Profil)
    'target_weekly_hours_',
    'workdays_',
    'workdays_per_week_', // Altschlüssel vor #217, nur noch gelesen
    'vacation_days_per_year_',
    'bundesland_',
    'show_work_location_on_dashboard_',
    'show_home_office_on_dashboard_',
    // FirebaseOvertimeRepositoryImpl: gemerkter Saldo (#573)
    'last_known_overtime_minutes_',
    'last_known_overtime_updated_',
    // WorkLocationHistory (#526)
    'work_location_history_',
    // ActiveWorkProfileIdNotifier: gemerktes Profil (nur je Nutzer)
    'active_work_profile_',
  ];

  /// Ob [key] ein Schlüssel des Nutzers [userId] ist.
  static bool isUserKey(String key, String userId) {
    if (userId.isEmpty || userId == 'local') return false;
    for (final prefix in userScopedKeyPrefixes) {
      final base = '$prefix$userId';
      if (key == base || key.startsWith('${base}_')) return true;
    }
    return false;
  }

  @override
  Future<void> removeUserData(String userId) async {
    final keys = _prefs.getKeys().where((k) => isUserKey(k, userId)).toList();
    for (final key in keys) {
      await _prefs.remove(key);
    }
  }
}
