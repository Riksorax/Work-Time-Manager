import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_work_time/core/utils/logger.dart';
import 'package:flutter_work_time/core/utils/api_errors.dart';
import 'package:flutter_work_time/data/datasources/remote/firestore_datasource.dart';
import 'package:flutter_work_time/domain/entities/overtime_freshness.dart';
import 'package:flutter_work_time/domain/repositories/overtime_repository.dart';
import 'package:flutter_work_time/core/utils/time_precision.dart';

/// Repository für Überstunden, das Firestore als Backend nutzt.
/// Wird verwendet, wenn der User eingeloggt ist.
///
/// **Zuletzt bekannter Saldo (#573):** Nach jedem erfolgreichen Laden und
/// Speichern merkt sich das Repository Saldo und `lastUpdated` in den
/// SharedPreferences, getrennt je Nutzer und Arbeitszeit-Profil
/// ([minutesKeyFor]/[lastUpdateKeyFor]). Scheitert das Laden mit einem
/// erwartbaren Ladefehler (`isExpectedLoadFailure`: kein Netz, kein
/// angemeldeter Nutzer), liefert es diesen Stand ([OvertimeFreshness.cached]);
/// gibt es keinen, wird der Fehler weitergereicht
/// ([OvertimeFreshness.unknown]). Andere Fehler haben keinen Ersatzwert.
class FirebaseOvertimeRepositoryImpl implements OvertimeRepository {
  final FirestoreDataSource _dataSource;
  final String _userId;

  /// Aktives Arbeitszeit-Profil (siehe #138) - `null`/`'default'` verwendet
  /// den bestehenden, nicht migrierten Datenpfad.
  final String? _profileId;

  /// Speicher für den zuletzt bekannten Saldo (#573); `null` = nicht merken.
  final SharedPreferences? _prefs;

  // Lokaler Cache für schnelle synchrone Reads
  Duration? _cachedOvertime;
  DateTime? _cachedLastUpdate;
  OvertimeFreshness _freshness = OvertimeFreshness.current;

  FirebaseOvertimeRepositoryImpl({
    required FirestoreDataSource dataSource,
    required String userId,
    String? profileId,
    SharedPreferences? prefs,
  })  : _dataSource = dataSource,
        _userId = userId,
        _profileId = profileId,
        _prefs = prefs;

  static String _suffix(String userId, String? profileId) {
    final profile =
        (profileId == null || profileId == 'default') ? '' : '_$profileId';
    return '$userId$profile';
  }

  /// Schlüssel des gemerkten Saldos (Minuten) je Nutzer und Profil (#573).
  static String minutesKeyFor({required String userId, String? profileId}) =>
      'last_known_overtime_minutes_${_suffix(userId, profileId)}';

  /// Schlüssel des gemerkten `lastUpdated` je Nutzer und Profil (#573).
  static String lastUpdateKeyFor({required String userId, String? profileId}) =>
      'last_known_overtime_updated_${_suffix(userId, profileId)}';

  String get _minutesKey =>
      minutesKeyFor(userId: _userId, profileId: _profileId);
  String get _lastUpdateKey =>
      lastUpdateKeyFor(userId: _userId, profileId: _profileId);

  Duration? _rememberedOvertime() {
    final minutes = _prefs?.getInt(_minutesKey);
    return minutes == null ? null : Duration(minutes: minutes);
  }

  DateTime? _rememberedLastUpdate() {
    final raw = _prefs?.getString(_lastUpdateKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> _rememberOvertime(Duration overtime) async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      await prefs.setInt(_minutesKey, toStoredMinutes(overtime));
    } catch (e) {
      // Merken ist nur ein Ersatz für später; der Saldo selbst ist geladen
      // bzw. gespeichert.
      logger.w(
          '[FirebaseOvertimeRepository] Saldo nicht gemerkt: ${errorLabel(e)}');
    }
  }

  Future<void> _rememberLastUpdate(DateTime? date) async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      if (date == null) {
        await prefs.remove(_lastUpdateKey);
      } else {
        await prefs.setString(_lastUpdateKey, date.toIso8601String());
      }
    } catch (e) {
      logger.w(
          '[FirebaseOvertimeRepository] Datum nicht gemerkt: ${errorLabel(e)}');
    }
  }

  @override
  OvertimeFreshness get overtimeFreshness => _freshness;

  @override
  Duration getOvertime() {
    // Synchroner Zugriff - gibt gecachten Wert zurück, sonst den gemerkten
    // Stand (#573) oder Duration.zero. Der eigentliche Wert wird beim ersten
    // async-Zugriff geladen.
    if (_cachedOvertime != null) {
      logger.i(
          '[FirebaseOvertimeRepository] getOvertime (cached): ${_cachedOvertime!.inMinutes} min');
      return _cachedOvertime!;
    }

    // Starte async Laden im Hintergrund
    _loadFromFirestore();

    final remembered = _rememberedOvertime();
    if (remembered != null) {
      _freshness = OvertimeFreshness.cached;
      return remembered;
    }
    _freshness = OvertimeFreshness.unknown;
    logger.i(
        '[FirebaseOvertimeRepository] getOvertime: Cache leer, gebe 0 zurück (lädt async)');
    return Duration.zero;
  }

  @override
  Future<void> saveOvertime(Duration overtime,
      {bool keepLastUpdated = false}) async {
    // Minutengenau speichern — der Cache muss denselben Wert halten wie Firestore,
    // sonst driftet die Bilanz zwischen Cache und persistiertem Stand.
    final rounded = roundDurationToMinute(overtime);
    logger.i(
        '[FirebaseOvertimeRepository] saveOvertime: ${rounded.inMinutes} min');
    await _dataSource.saveOvertime(_userId, rounded,
        profileId: _profileId, keepLastUpdated: keepLastUpdated);
    // Erst nach erfolgreichem Write (#427): sonst hielte der Cache einen Saldo,
    // der nie gespeichert wurde.
    _cachedOvertime = rounded;
    _freshness = OvertimeFreshness.current;
    await _rememberOvertime(rounded);
  }

  @override
  DateTime? getLastUpdateDate() {
    // Synchroner Zugriff - gibt gecachten Wert zurück
    if (_cachedLastUpdate != null) {
      return _cachedLastUpdate;
    }

    // Starte async Laden im Hintergrund
    _loadFromFirestore();

    return _rememberedLastUpdate();
  }

  @override
  Future<void> saveLastUpdateDate(DateTime date) async {
    logger.i('[FirebaseOvertimeRepository] saveLastUpdateDate: $date');
    await _dataSource.saveLastOvertimeUpdate(_userId, date,
        profileId: _profileId);
    _cachedLastUpdate = date;
    await _rememberLastUpdate(date);
  }

  /// Lädt Daten async von Firestore und aktualisiert den Cache
  Future<void> _loadFromFirestore() async {
    try {
      final overtime =
          await _dataSource.getOvertime(_userId, profileId: _profileId);
      _cachedOvertime = overtime;
      _freshness = OvertimeFreshness.current;
      await _rememberOvertime(overtime);

      final lastUpdate = await _dataSource.getLastOvertimeUpdate(_userId,
          profileId: _profileId);
      _cachedLastUpdate = lastUpdate;
      await _rememberLastUpdate(lastUpdate);

      logger.i(
          '[FirebaseOvertimeRepository] Daten von Firestore geladen: ${overtime.inMinutes} min, lastUpdate: $lastUpdate');
    } catch (e) {
      if (isExpectedLoadFailure(e)) {
        // Verbindungsabbruch ist kein App-Fehler (#506): nur info.
        logger.i(
            '[FirebaseOvertimeRepository] Netzwerkfehler beim Laden von Firestore: ${errorLabel(e)}');
      } else {
        logger.e(
            '[FirebaseOvertimeRepository] Fehler beim Laden von Firestore: ${errorLabel(e)}');
      }
    }
  }

  /// Lädt die Daten explizit von Firestore (für initiale Synchronisation).
  ///
  /// Ohne Netz (erwartbarer Ladefehler) gilt der zuletzt bekannte Stand
  /// (#573); gibt es keinen, wird der Fehler weitergereicht.
  Future<Duration> loadOvertimeAsync() async {
    try {
      final overtime =
          await _dataSource.getOvertime(_userId, profileId: _profileId);
      _cachedOvertime = overtime;
      _freshness = OvertimeFreshness.current;
      await _rememberOvertime(overtime);
      return overtime;
    } catch (e) {
      if (!isExpectedLoadFailure(e)) rethrow;
      final known = _cachedOvertime ?? _rememberedOvertime();
      if (known == null) {
        _freshness = OvertimeFreshness.unknown;
        rethrow;
      }
      logger.i(
          '[FirebaseOvertimeRepository] Saldo nicht ladbar (${errorLabel(e)}), zuletzt bekannter Stand');
      _cachedOvertime = known;
      _freshness = OvertimeFreshness.cached;
      return known;
    }
  }

  /// Lädt das Update-Datum explizit von Firestore; ohne Netz gilt wie bei
  /// [loadOvertimeAsync] der zuletzt bekannte Stand (`null`, wenn keiner).
  Future<DateTime?> loadLastUpdateAsync() async {
    try {
      final lastUpdate = await _dataSource.getLastOvertimeUpdate(_userId,
          profileId: _profileId);
      _cachedLastUpdate = lastUpdate;
      await _rememberLastUpdate(lastUpdate);
      return lastUpdate;
    } catch (e) {
      if (!isExpectedLoadFailure(e)) rethrow;
      logger.i(
          '[FirebaseOvertimeRepository] Datum nicht ladbar (${errorLabel(e)}), zuletzt bekannter Stand');
      return _cachedLastUpdate ?? _rememberedLastUpdate();
    }
  }

  @override
  Future<Duration> ensureOvertimeLoaded() => loadOvertimeAsync();

  @override
  Future<DateTime?> ensureLastUpdateLoaded() => loadLastUpdateAsync();
}
