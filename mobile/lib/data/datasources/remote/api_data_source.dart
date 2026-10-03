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
  Future<bool> reauthenticate() => _auth.reauthenticate();

  @override
  Future<void> setUserProfile(String userId, Map<String, dynamic> data) =>
      _auth.setUserProfile(userId, data);

  // ── Work Entries → immer über die Backend-API (alle Profile, siehe #239) ──

  @override
  Future<WorkEntryModel?> getWorkEntry(String userId, DateTime date,
          {String? profileId}) =>
      _api.getWorkEntry(date.year, date.month, date.day, profileId: profileId);

  @override
  Future<void> saveWorkEntry(String userId, WorkEntryModel model,
          {String? profileId}) =>
      _api.saveWorkEntry(model, profileId: profileId);

  @override
  Future<List<WorkEntryModel>> getWorkEntriesForMonth(
          String userId, int year, int month,
          {String? profileId}) =>
      _api.getWorkEntriesForMonth(year, month, profileId: profileId);

  @override
  Future<void> deleteWorkEntry(String userId, String entryId,
      {String? profileId}) {
    final parts = entryId.split('-');
    return _api.deleteWorkEntry(
        int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]),
        profileId: profileId);
  }

  // ── Overtime → immer über die Backend-API (alle Profile, siehe #239) ─────

  @override
  Future<Duration> getOvertime(String userId, {String? profileId}) async {
    final result = await _api.getOvertime(profileId: profileId);
    return Duration(minutes: result.minutes);
  }

  @override
  Future<void> saveOvertime(String userId, Duration overtime,
          {String? profileId}) =>
      // Kaufmännisch runden statt inMinutes (schneidet Richtung Null ab und
      // ließe den Saldo im Minus anders driften als im Plus).
      _api.saveOvertime(toStoredMinutes(overtime), profileId: profileId);

  @override
  Future<DateTime?> getLastOvertimeUpdate(String userId,
      {String? profileId}) async {
    final result = await _api.getOvertime(profileId: profileId);
    return result.lastUpdated;
  }

  @override
  Future<void> saveLastOvertimeUpdate(String userId, DateTime date,
      {String? profileId}) async {
    // No-op: Das Backend setzt lastUpdated automatisch beim Speichern des Saldos.
  }

  // ── Settings → immer über die Backend-API (Read-Modify-Write, alle Profile) ─

  @override
  Future<Map<String, dynamic>?> getSettings(String userId,
          {String? profileId}) =>
      _api.getSettings(profileId: profileId);

  @override
  Future<void> saveSettings(String userId, Map<String, dynamic> settings,
      {String? profileId}) async {
    final current =
        await _api.getSettings(profileId: profileId) ?? <String, dynamic>{};
    await _api.putSettings({...current, ...settings}, profileId: profileId);
  }

  // ── Weekly Reflection → an Firestore-DataSource delegiert (kein Backend-
  //    Endpoint, siehe #137) ─────────────────────────────────────────────────

  @override
  Future<WeeklyReflectionEntity?> getWeeklyReflection(
          String userId, int year, int week) =>
      _auth.getWeeklyReflection(userId, year, week);

  @override
  Future<void> saveWeeklyReflection(
          String userId, WeeklyReflectionEntity reflection) =>
      _auth.saveWeeklyReflection(userId, reflection);

  // ── Arbeitszeit-Profile → an Firestore-DataSource delegiert (kein Backend-
  //    Endpoint, siehe #138) ────────────────────────────────────────────────

  @override
  Future<List<Map<String, dynamic>>> getWorkProfiles(String userId) =>
      _auth.getWorkProfiles(userId);

  @override
  Future<String> addWorkProfile(String userId, String name) =>
      _auth.addWorkProfile(userId, name);

  @override
  Future<void> deleteWorkProfile(String userId, String profileId) =>
      _auth.deleteWorkProfile(userId, profileId);
}
