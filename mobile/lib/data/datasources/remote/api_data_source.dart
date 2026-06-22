import 'package:firebase_auth/firebase_auth.dart' as firebase;

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
  Future<void> setUserProfile(String userId, Map<String, dynamic> data) =>
      _auth.setUserProfile(userId, data);

  // ── Work Entries → API ────────────────────────────────────────────────────

  @override
  Future<WorkEntryModel?> getWorkEntry(String userId, DateTime date) =>
      _api.getWorkEntry(date.year, date.month, date.day);

  @override
  Future<void> saveWorkEntry(String userId, WorkEntryModel model) =>
      _api.saveWorkEntry(model);

  @override
  Future<List<WorkEntryModel>> getWorkEntriesForMonth(String userId, int year, int month) =>
      _api.getWorkEntriesForMonth(year, month);

  @override
  Future<void> deleteWorkEntry(String userId, String entryId) {
    final parts = entryId.split('-');
    return _api.deleteWorkEntry(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  // ── Overtime → API ──────────────────────────────────────────────────────

  @override
  Future<Duration> getOvertime(String userId) async {
    final result = await _api.getOvertime();
    return Duration(minutes: result.minutes);
  }

  @override
  Future<void> saveOvertime(String userId, Duration overtime) =>
      _api.saveOvertime(overtime.inMinutes);

  @override
  Future<DateTime?> getLastOvertimeUpdate(String userId) async {
    final result = await _api.getOvertime();
    return result.lastUpdated;
  }

  @override
  Future<void> saveLastOvertimeUpdate(String userId, DateTime date) async {
    // No-op: Das Backend setzt lastUpdated automatisch beim Speichern des Saldos.
  }

  // ── Settings → API (Read-Modify-Write, da Repository partielle Maps sendet) ─

  @override
  Future<Map<String, dynamic>?> getSettings(String userId) => _api.getSettings();

  @override
  Future<void> saveSettings(String userId, Map<String, dynamic> settings) async {
    final current = await _api.getSettings() ?? <String, dynamic>{};
    await _api.putSettings({...current, ...settings});
  }
}
