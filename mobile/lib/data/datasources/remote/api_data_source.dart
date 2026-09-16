import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:flutter_work_time/core/utils/time_precision.dart';
import 'package:flutter_work_time/domain/entities/weekly_reflection_entity.dart';

import '../../models/work_entry_model.dart';
import 'api_client.dart';
import 'firestore_datasource.dart';

/// [FirestoreDataSource]-Implementierung, die Daten­operationen (Work/Overtime/
/// Settings) über die .NET-Backend-API abwickelt. Auth- und Profil­operationen
/// werden an die echte [FirestoreDataSource] delegiert (Firebase-Auth bleibt
/// unverändert — Hybrid-Echtzeit/Token-Quelle).
class ApiDataSource implements FirestoreDataSource {
  final FirestoreDataSource _auth;
  final ApiClient _api;

  ApiDataSource(this._auth, this._api);

  /// Das Backend kennt bislang nur das Standard-Profil (siehe #138) - für
  /// zusätzliche Profile wird direkt gegen Firestore gearbeitet, statt die
  /// .NET-API (die keine Profil-Dimension kennt) um einen Sonderfall zu
  /// erweitern.
  bool _isAdditionalProfile(String? profileId) =>
      profileId != null && profileId != 'default';

  // ── Auth / Profil → an Firestore-DataSource delegiert ─────────────────────

  @override
  Stream<firebase.User?> get authStateChanges => _auth.authStateChanges;

  @override
  Future<void> signInWithGoogle() => _auth.signInWithGoogle();

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> deleteAccount() => _auth.deleteAccount();

  @override
  Future<void> setUserProfile(String userId, Map<String, dynamic> data) =>
      _auth.setUserProfile(userId, data);

  // ── Work Entries → API (Standard-Profil) / Firestore (zusätzliche Profile) ─

  @override
  Future<WorkEntryModel?> getWorkEntry(String userId, DateTime date, {String? profileId}) {
    if (_isAdditionalProfile(profileId)) {
      return _auth.getWorkEntry(userId, date, profileId: profileId);
    }
    return _api.getWorkEntry(date.year, date.month, date.day);
  }

  @override
  Future<void> saveWorkEntry(String userId, WorkEntryModel model, {String? profileId}) {
    if (_isAdditionalProfile(profileId)) {
      return _auth.saveWorkEntry(userId, model, profileId: profileId);
    }
    return _api.saveWorkEntry(model);
  }

  @override
  Future<List<WorkEntryModel>> getWorkEntriesForMonth(String userId, int year, int month,
      {String? profileId}) {
    if (_isAdditionalProfile(profileId)) {
      return _auth.getWorkEntriesForMonth(userId, year, month, profileId: profileId);
    }
    return _api.getWorkEntriesForMonth(year, month);
  }

  @override
  Future<void> deleteWorkEntry(String userId, String entryId, {String? profileId}) {
    if (_isAdditionalProfile(profileId)) {
      return _auth.deleteWorkEntry(userId, entryId, profileId: profileId);
    }
    final parts = entryId.split('-');
    return _api.deleteWorkEntry(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  // ── Overtime → API (Standard-Profil) / Firestore (zusätzliche Profile) ────

  @override
  Future<Duration> getOvertime(String userId, {String? profileId}) async {
    if (_isAdditionalProfile(profileId)) {
      return _auth.getOvertime(userId, profileId: profileId);
    }
    final result = await _api.getOvertime();
    return Duration(minutes: result.minutes);
  }

  @override
  Future<void> saveOvertime(String userId, Duration overtime, {String? profileId}) {
    if (_isAdditionalProfile(profileId)) {
      return _auth.saveOvertime(userId, overtime, profileId: profileId);
    }
    // Kaufmännisch runden statt inMinutes (schneidet Richtung Null ab und
    // ließe den Saldo im Minus anders driften als im Plus).
    return _api.saveOvertime(toStoredMinutes(overtime));
  }

  @override
  Future<DateTime?> getLastOvertimeUpdate(String userId, {String? profileId}) async {
    if (_isAdditionalProfile(profileId)) {
      return _auth.getLastOvertimeUpdate(userId, profileId: profileId);
    }
    final result = await _api.getOvertime();
    return result.lastUpdated;
  }

  @override
  Future<void> saveLastOvertimeUpdate(String userId, DateTime date, {String? profileId}) async {
    if (_isAdditionalProfile(profileId)) {
      return _auth.saveLastOvertimeUpdate(userId, date, profileId: profileId);
    }
    // No-op: Das Backend setzt lastUpdated automatisch beim Speichern des Saldos.
  }

  // ── Settings → API (Standard-Profil, Read-Modify-Write) / Firestore ───────

  @override
  Future<Map<String, dynamic>?> getSettings(String userId, {String? profileId}) {
    if (_isAdditionalProfile(profileId)) {
      return _auth.getSettings(userId, profileId: profileId);
    }
    return _api.getSettings();
  }

  @override
  Future<void> saveSettings(String userId, Map<String, dynamic> settings,
      {String? profileId}) async {
    if (_isAdditionalProfile(profileId)) {
      return _auth.saveSettings(userId, settings, profileId: profileId);
    }
    final current = await _api.getSettings() ?? <String, dynamic>{};
    await _api.putSettings({...current, ...settings});
  }

  // ── Weekly Reflection → an Firestore-DataSource delegiert (kein Backend-
  //    Endpoint, siehe #137) ─────────────────────────────────────────────────

  @override
  Future<WeeklyReflectionEntity?> getWeeklyReflection(String userId, int year, int week) =>
      _auth.getWeeklyReflection(userId, year, week);

  @override
  Future<void> saveWeeklyReflection(String userId, WeeklyReflectionEntity reflection) =>
      _auth.saveWeeklyReflection(userId, reflection);

  // ── Arbeitszeit-Profile → an Firestore-DataSource delegiert (kein Backend-
  //    Endpoint, siehe #138) ────────────────────────────────────────────────

  @override
  Future<List<Map<String, dynamic>>> getWorkProfiles(String userId) =>
      _auth.getWorkProfiles(userId);

  @override
  Future<String> addWorkProfile(String userId, String name) =>
      _auth.addWorkProfile(userId, name);
}
