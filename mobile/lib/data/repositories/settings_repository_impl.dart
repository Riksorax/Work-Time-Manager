import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_work_time/core/utils/logger.dart';
import 'package:flutter_work_time/core/utils/timezone_utils.dart';

import '../../domain/entities/app_theme_mode.dart';
import '../../domain/entities/bundesland.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/utils/leave_balance_utils.dart';
import '../datasources/remote/firestore_datasource.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  // Theme ist global (nicht userId-spezifisch)
  static const String _themeModeKey = 'theme_mode';
  // Rechtliche Zustimmungen sind global (nicht userId-spezifisch)
  static const String _acceptedTermsOfServiceKey = 'accepted_terms_of_service';
  static const String _acceptedPrivacyPolicyKey = 'accepted_privacy_policy';
  // Benachrichtigungen sind global (nicht userId-spezifisch)
  static const String _notificationsEnabledKey = 'notifications_enabled';
  static const String _notificationTimeKey = 'notification_time';
  static const String _notificationDaysKey = 'notification_days';
  static const String _notifyWorkStartKey = 'notify_work_start';
  static const String _notifyWorkEndKey = 'notify_work_end';
  static const String _notifyBreaksKey = 'notify_breaks';
  // Alter globaler Key (vor #279, nicht profil-/kontospezifisch) - nur noch
  // als Fallback beim Lesen relevant.
  static const String _legacyGlobalBundeslandKey = 'bundesland';
  static const String _warnOnOvertimeThresholdKey =
      'warn_on_overtime_threshold';
  static const String _overtimeThresholdHoursKey = 'overtime_threshold_hours';
  static const String _warnOnUndertimeThresholdKey =
      'warn_on_undertime_threshold';
  static const String _undertimeThresholdHoursKey = 'undertime_threshold_hours';
  // Zeitformat ist geräteweit, nicht userId-spezifisch (wie Theme/Benachrichtigungen).
  static const String _use24HourFormatKey = 'use_24_hour_format';
  // Sprache ist geräteweit, nicht userId-spezifisch (wie Zeitformat) - siehe #221.
  static const String _localeKey = 'locale';

  final SharedPreferences _prefs;
  final FirestoreDataSource _firestoreDataSource;
  final String _userId;

  /// Aktives Arbeitszeit-Profil (siehe #138). Soll-Wochenstunden, Arbeitstage,
  /// Urlaubsanspruch und Bundesland sind profil-spezifisch - alle anderen
  /// Einstellungen (Theme, Benachrichtigungen, Zeitformat, Sprache, ...)
  /// bleiben bewusst geräte-/kontoweit (siehe Kommentare unten).
  final String? _profileId;

  SettingsRepositoryImpl(this._prefs, this._firestoreDataSource, this._userId,
      [this._profileId]);

  String get _profileSuffix =>
      (_profileId == null || _profileId == 'default') ? '' : '_$_profileId';

  // Generiere userId- (und profil-)spezifische Keys für Einstellungen
  String get _targetHoursKey => 'target_weekly_hours_$_userId$_profileSuffix';
  String get _workdaysKey => 'workdays_$_userId$_profileSuffix';
  // Urlaubsanspruch ist profil-spezifisch (siehe #278).
  String get _vacationDaysKey =>
      'vacation_days_per_year_$_userId$_profileSuffix';
  // Bundesland ist profil-spezifisch (siehe #279).
  String get _bundeslandKey => 'bundesland_$_userId$_profileSuffix';
  // Vor dem Login gewähltes Bundesland (Nutzer 'local', gleiches Profil).
  String get _localBundeslandKey => 'bundesland_local$_profileSuffix';
  // Alter Schlüssel (reine Anzahl statt konkreter Wochentage) - nur noch
  // zur Migration bestehender Nutzer beim ersten Lesen relevant (#217).
  String get _legacyWorkdaysPerWeekKey =>
      'workdays_per_week_$_userId$_profileSuffix';

  @override
  AppThemeMode getThemeMode() {
    final themeModeString = _prefs.getString(_themeModeKey);
    if (themeModeString == 'dark') {
      return AppThemeMode.dark;
    } else if (themeModeString == 'light') {
      return AppThemeMode.light;
    } else {
      return AppThemeMode.system;
    }
  }

  @override
  Future<void> setThemeMode(AppThemeMode mode) async {
    await _prefs.setString(_themeModeKey, mode.name);
  }

  @override
  double getTargetWeeklyHours() {
    final value = _prefs.getDouble(_targetHoursKey);
    return value ?? 40.0;
  }

  @override
  Future<void> setTargetWeeklyHours(double hours) async {
    logger.i(
        '[SettingsRepository] setTargetWeeklyHours for user $_userId: $hours');
    await _prefs.setDouble(_targetHoursKey, hours);
    _syncToFirestore({'weeklyTargetHours': hours});
  }

  @override
  List<int> getWorkdays() {
    final stored = _prefs.getString(_workdaysKey);
    if (stored != null && stored.isNotEmpty) {
      return stored.split(',').map(int.parse).toList();
    }
    // Migration: bestehende Nutzer hatten nur eine Anzahl gespeichert -
    // das entsprach implizit "die ersten N Tage ab Montag" (siehe #217).
    final legacyCount = _prefs.getInt(_legacyWorkdaysPerWeekKey);
    if (legacyCount != null) {
      return List.generate(legacyCount.clamp(0, 7), (i) => i + 1);
    }
    return const [1, 2, 3, 4, 5];
  }

  @override
  Future<void> setWorkdays(List<int> days) async {
    logger.i('[SettingsRepository] setWorkdays for user $_userId: $days');
    await _prefs.setString(_workdaysKey, days.join(','));
    _syncToFirestore({'workdays': days});
  }

  @override
  int getVacationDaysPerYear() {
    try {
      final value = _prefs.getInt(_vacationDaysKey);
      if (value != null && value >= 0 && value <= maxVacationDaysPerYear) {
        return value;
      }
    } catch (_) {
      // Fremdtyp unter dem Key - auf Default zurückfallen.
    }
    return defaultVacationDaysPerYear;
  }

  @override
  Future<void> setVacationDaysPerYear(int days) async {
    logger.i(
        '[SettingsRepository] setVacationDaysPerYear for user $_userId: $days');
    await _prefs.setInt(_vacationDaysKey, days);
    _syncToFirestore({'vacationDaysPerYear': days});
  }

  /// Beim Login: Firestore-Einstellungen in SharedPreferences übernehmen.
  /// Nur weeklyTargetHours, workdays, vacationDaysPerYear und bundesland werden
  /// synchronisiert — Benachrichtigungen sind gerätespezifisch.
  ///
  /// Liefert `true`, wenn sich dadurch das Bundesland geändert hat (damit die
  /// UI neu laden kann, siehe #279).
  Future<bool> syncFromFirestore() async {
    if (_userId == 'local' || _userId.isEmpty) return false;
    try {
      final before = getBundesland();
      final data = await _firestoreDataSource.getSettings(_userId,
          profileId: _profileId);
      if (data == null) return false;
      if (data['weeklyTargetHours'] != null) {
        await _prefs.setDouble(
            _targetHoursKey, (data['weeklyTargetHours'] as num).toDouble());
      }
      if (data['workdays'] != null) {
        final days =
            (data['workdays'] as List).map((e) => (e as num).toInt()).toList();
        await _prefs.setString(_workdaysKey, days.join(','));
      } else if (data['workdaysPerWeek'] != null) {
        final legacyCount = (data['workdaysPerWeek'] as num).toInt();
        await _prefs.setString(
          _workdaysKey,
          List.generate(legacyCount.clamp(0, 7), (i) => i + 1).join(','),
        );
      }
      final vacation = data['vacationDaysPerYear'];
      if (vacation is num &&
          vacation == vacation.toInt() &&
          vacation >= 0 &&
          vacation <= maxVacationDaysPerYear) {
        await _prefs.setInt(_vacationDaysKey, vacation.toInt());
      }
      await _syncBundeslandFromRemote(data['bundesland']);
      logger.i('[SettingsRepository] Einstellungen von Firestore geladen.');
      return getBundesland() != before;
    } catch (e) {
      logger.w('[SettingsRepository] Firestore-Import fehlgeschlagen: $e');
      return false;
    }
  }

  Future<void> _syncBundeslandFromRemote(Object? remote) async {
    if (remote is String && remote.isNotEmpty) {
      // Nur gültige Namen übernehmen, Unbekanntes ignorieren.
      if (bundeslandFromName(remote) != null) {
        await _prefs.setString(_bundeslandKey, remote);
      }
      return;
    }
    if (remote != null && remote is! String) return; // Fremdtyp
    // Remote leer/nicht vorhanden.
    if (_hasOwnBundeslandKey()) {
      // Remote leer = nicht gewählt.
      await _prefs.setString(_bundeslandKey, '');
      return;
    }
    // Legacy-Migration: lokal gewählt (Fallback-Kette), aber noch nie
    // hochgeladen -> hochladen und in den neuen Key übernehmen.
    final legacy = getBundesland();
    if (legacy != null) {
      await _prefs.setString(_bundeslandKey, legacy.name);
      await _firestoreDataSource.saveSettings(
          _userId, {'bundesland': legacy.name},
          profileId: _profileId);
    }
  }

  bool _hasOwnBundeslandKey() {
    try {
      return _prefs.getString(_bundeslandKey) != null;
    } catch (_) {
      return true;
    }
  }

  void _syncToFirestore(Map<String, dynamic> data) {
    if (_userId == 'local' || _userId.isEmpty) return;
    _firestoreDataSource
        .saveSettings(_userId, data, profileId: _profileId)
        .catchError((e) =>
            logger.w('[SettingsRepository] Firestore-Sync fehlgeschlagen: $e'));
  }

  @override
  bool hasAcceptedTermsOfService() {
    return _prefs.getBool(_acceptedTermsOfServiceKey) ?? false;
  }

  @override
  Future<void> setAcceptedTermsOfService(bool accepted) async {
    await _prefs.setBool(_acceptedTermsOfServiceKey, accepted);
  }

  @override
  bool hasAcceptedPrivacyPolicy() {
    return _prefs.getBool(_acceptedPrivacyPolicyKey) ?? false;
  }

  @override
  Future<void> setAcceptedPrivacyPolicy(bool accepted) async {
    await _prefs.setBool(_acceptedPrivacyPolicyKey, accepted);
  }

  @override
  bool getNotificationsEnabled() {
    return _prefs.getBool(_notificationsEnabledKey) ?? false;
  }

  @override
  Future<void> setNotificationsEnabled(bool enabled) async {
    await _prefs.setBool(_notificationsEnabledKey, enabled);
  }

  @override
  String getNotificationTime() {
    return _prefs.getString(_notificationTimeKey) ?? '18:00';
  }

  @override
  Future<void> setNotificationTime(String time) async {
    await _prefs.setString(_notificationTimeKey, time);
  }

  @override
  List<int> getNotificationDays() {
    final daysString = _prefs.getString(_notificationDaysKey);
    if (daysString == null || daysString.isEmpty) {
      return [1, 2, 3, 4, 5]; // Default: Monday to Friday
    }
    return daysString.split(',').map((e) => int.parse(e)).toList();
  }

  @override
  Future<void> setNotificationDays(List<int> days) async {
    await _prefs.setString(_notificationDaysKey, days.join(','));
  }

  @override
  bool getNotifyWorkStart() {
    return _prefs.getBool(_notifyWorkStartKey) ?? true;
  }

  @override
  Future<void> setNotifyWorkStart(bool enabled) async {
    await _prefs.setBool(_notifyWorkStartKey, enabled);
  }

  @override
  bool getNotifyWorkEnd() {
    return _prefs.getBool(_notifyWorkEndKey) ?? true;
  }

  @override
  Future<void> setNotifyWorkEnd(bool enabled) async {
    await _prefs.setBool(_notifyWorkEndKey, enabled);
  }

  @override
  bool getNotifyBreaks() {
    return _prefs.getBool(_notifyBreaksKey) ?? true;
  }

  @override
  Future<void> setNotifyBreaks(bool enabled) async {
    await _prefs.setBool(_notifyBreaksKey, enabled);
  }

  @override
  Bundesland? getBundesland() {
    try {
      final own = _prefs.getString(_bundeslandKey);
      if (own != null) {
        // '' = bewusst nicht gewählt, kein Fallback.
        return bundeslandFromName(own);
      }
      if (_userId != 'local') {
        final local = _prefs.getString(_localBundeslandKey);
        if (local != null) return bundeslandFromName(local);
      }
      return bundeslandFromName(_prefs.getString(_legacyGlobalBundeslandKey));
    } catch (_) {
      // Fremdtyp unter dem Key - als nicht gewählt behandeln.
      return null;
    }
  }

  @override
  Future<void> setBundesland(Bundesland? bundesland) async {
    if (bundesland == null) {
      // '' statt remove: markiert "bewusst nicht gewählt", damit die
      // Fallback-Kette nicht wieder einen Altwert liefert. Das Backend löscht
      // das Feld ebenfalls nur über ''. Achtung: Das Löschen des globalen
      // Legacy-Keys betrifft alle Profile ohne eigenen Key.
      await _prefs.setString(_bundeslandKey, '');
      await _prefs.remove(_legacyGlobalBundeslandKey);
    } else {
      await _prefs.setString(_bundeslandKey, bundesland.name);
    }
    _syncToFirestore({'bundesland': bundesland?.name ?? ''});
  }

  @override
  bool getWarnOnOvertimeThreshold() {
    return _prefs.getBool(_warnOnOvertimeThresholdKey) ?? false;
  }

  @override
  Future<void> setWarnOnOvertimeThreshold(bool enabled) async {
    await _prefs.setBool(_warnOnOvertimeThresholdKey, enabled);
  }

  @override
  double getOvertimeThresholdHours() {
    return _prefs.getDouble(_overtimeThresholdHoursKey) ?? 10.0;
  }

  @override
  Future<void> setOvertimeThresholdHours(double hours) async {
    await _prefs.setDouble(_overtimeThresholdHoursKey, hours);
  }

  @override
  bool getWarnOnUndertimeThreshold() {
    return _prefs.getBool(_warnOnUndertimeThresholdKey) ?? false;
  }

  @override
  Future<void> setWarnOnUndertimeThreshold(bool enabled) async {
    await _prefs.setBool(_warnOnUndertimeThresholdKey, enabled);
  }

  @override
  double getUndertimeThresholdHours() {
    return _prefs.getDouble(_undertimeThresholdHoursKey) ?? 10.0;
  }

  @override
  Future<void> setUndertimeThresholdHours(double hours) async {
    await _prefs.setDouble(_undertimeThresholdHoursKey, hours);
  }

  @override
  bool getUse24HourFormat() {
    return _prefs.getBool(_use24HourFormatKey) ?? true;
  }

  @override
  Future<void> setUse24HourFormat(bool use24Hour) async {
    await _prefs.setBool(_use24HourFormatKey, use24Hour);
  }

  @override
  String? getTimezoneOverride() {
    return _prefs.getString(timezoneOverridePrefsKey);
  }

  @override
  Future<void> setTimezoneOverride(String? timezone) async {
    if (timezone == null) {
      await _prefs.remove(timezoneOverridePrefsKey);
    } else {
      await _prefs.setString(timezoneOverridePrefsKey, timezone);
    }
  }

  @override
  String getLocale() {
    return _prefs.getString(_localeKey) ?? 'de';
  }

  @override
  Future<void> setLocale(String locale) async {
    await _prefs.setString(_localeKey, locale);
  }
}
