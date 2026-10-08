import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'package:flutter_work_time/core/config/api_config.dart';
import 'package:flutter_work_time/core/utils/logger.dart';
import '../../../domain/entities/break_entity.dart';
import '../../../domain/entities/work_entry_entity.dart';
import '../../models/work_entry_model.dart';
import 'package:flutter_work_time/core/utils/time_precision.dart';

/// Low-Level-Client für die .NET-Backend-API: HTTP + Firebase-ID-Token +
/// JSON↔Model-Mapping. Wird von [ApiDataSource] (Work/Overtime/Settings) und
/// direkt vom ReportsViewModel (Reports) genutzt.
class ApiClient {
  final firebase.FirebaseAuth _auth;
  final http.Client _http;

  ApiClient(this._auth, this._http);

  /// [profileId] wird nur als Query-Parameter angehängt, wenn es ein
  /// zusätzliches Arbeitszeit-Profil bezeichnet (siehe #239) — `null` oder
  /// `'default'` verwenden weiterhin den bestehenden, nicht migrierten Pfad
  /// ohne Parameter, damit sich an bestehenden Aufrufen nichts ändert.
  Uri _uri(String path, [String? profileId]) {
    final base = Uri.parse('${ApiConfig.baseUrl}/api$path');
    if (profileId == null || profileId == 'default') return base;
    return base.replace(queryParameters: {'profileId': profileId});
  }

  Future<Map<String, String>> _headers() async {
    final token = await _auth.currentUser?.getIdToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Never _fail(String op, http.Response res) {
    logger.e('[ApiClient] $op fehlgeschlagen: ${res.statusCode} ${res.body}');
    throw Exception('API $op fehlgeschlagen (${res.statusCode})');
  }

  // ── Work Entries ────────────────────────────────────────────────────────

  Future<List<WorkEntryModel>> getWorkEntriesForMonth(int year, int month,
      {String? profileId}) async {
    final res = await _http.get(_uri('/work-entries/$year/$month', profileId),
        headers: await _headers());
    if (res.statusCode != 200) _fail('getWorkEntriesForMonth', res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => _entryFromJson(e as Map<String, dynamic>)).toList();
  }

  Future<WorkEntryModel?> getWorkEntry(int year, int month, int day,
      {String? profileId}) async {
    final res = await _http.get(
        _uri('/work-entries/$year/$month/$day', profileId),
        headers: await _headers());
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) _fail('getWorkEntry', res);
    return _entryFromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> saveWorkEntry(WorkEntryModel model, {String? profileId}) async {
    final res = await _http.put(
      _uri('/work-entries', profileId),
      headers: await _headers(),
      body: jsonEncode(_entryToJson(model)),
    );
    if (res.statusCode != 200 && res.statusCode != 204)
      _fail('saveWorkEntry', res);
  }

  Future<void> deleteWorkEntry(int year, int month, int day,
      {String? profileId}) async {
    final res = await _http.delete(
        _uri('/work-entries/$year/$month/$day', profileId),
        headers: await _headers());
    if (res.statusCode != 200 && res.statusCode != 204)
      _fail('deleteWorkEntry', res);
  }

  // ── Overtime ──────────────────────────────────────────────────────────────

  /// Liefert (Saldo, lastUpdated). Saldo in Minuten.
  Future<({int minutes, DateTime? lastUpdated})> getOvertime(
      {String? profileId}) async {
    final res = await _http.get(_uri('/overtime', profileId),
        headers: await _headers());
    if (res.statusCode != 200) _fail('getOvertime', res);
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return (
      minutes: (json['minutes'] as num?)?.toInt() ?? 0,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'] as String).toLocal()
          : null,
    );
  }

  Future<void> saveOvertime(int minutes,
      {String? profileId, bool keepLastUpdated = false}) async {
    final res = await _http.put(
      _uri('/overtime', profileId),
      headers: await _headers(),
      // Das Feld nur bei true senden: der Default-Body bleibt unverändert, ältere
      // APIs (vor #408) ignorieren das unbekannte Feld ohnehin.
      body: jsonEncode({
        'minutes': minutes,
        if (keepLastUpdated) 'keepLastUpdated': true,
      }),
    );
    if (res.statusCode != 200 && res.statusCode != 204)
      _fail('saveOvertime', res);
  }

  // ── Settings ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getSettings({String? profileId}) async {
    final res = await _http.get(_uri('/settings', profileId),
        headers: await _headers());
    if (res.statusCode != 200) _fail('getSettings', res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> putSettings(Map<String, dynamic> settings,
      {String? profileId}) async {
    final res = await _http.put(
      _uri('/settings', profileId),
      headers: await _headers(),
      body: jsonEncode(settings),
    );
    if (res.statusCode != 200 && res.statusCode != 204)
      _fail('putSettings', res);
  }

  // ── Reports (Roh-JSON; Zeiten in ms) ──────────────────────────────────────

  Future<Map<String, dynamic>> getDailyReport(int year, int month, int day,
          {String? profileId}) =>
      _getJson('/reports/daily/$year/$month/$day', 'getDailyReport', profileId);

  Future<Map<String, dynamic>> getWeeklyReport(int year, int month, int day,
          {String? profileId}) =>
      _getJson(
          '/reports/weekly/$year/$month/$day', 'getWeeklyReport', profileId);

  Future<Map<String, dynamic>> getMonthlyReport(int year, int month,
          {String? profileId}) =>
      _getJson('/reports/monthly/$year/$month', 'getMonthlyReport', profileId);

  Future<Map<String, dynamic>> _getJson(String path, String op,
      [String? profileId]) async {
    final res =
        await _http.get(_uri(path, profileId), headers: await _headers());
    if (res.statusCode != 200) _fail(op, res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Mapping ───────────────────────────────────────────────────────────────

  Map<String, dynamic> _entryToJson(WorkEntryModel m) => {
        'id': m.id,
        // UTC-Mitternacht aus lokalen Y/M/D — analog WorkEntryModel.toMap (Flutter-kanonisch)
        'date': DateTime.utc(m.date.year, m.date.month, m.date.day)
            .toIso8601String(),
        'workStart': m.workStart?.toUtc().toIso8601String(),
        'workEnd': m.workEnd?.toUtc().toIso8601String(),
        'type': m.type.name,
        'isManuallyEntered': m.isManuallyEntered,
        'manualOvertimeMinutes': m.manualOvertime?.inMinutes,
        'description': m.description,
        'breaks': m.breaks
            .map((b) => {
                  'id': b.id,
                  'name': b.name,
                  'isAutomatic': b.isAutomatic,
                  'start': b.start.toUtc().toIso8601String(),
                  'end': b.end?.toUtc().toIso8601String(),
                })
            .toList(),
      };

  WorkEntryModel _entryFromJson(Map<String, dynamic> j) => WorkEntryModel(
        id: j['id'] as String,
        date: DateTime.parse(j['date'] as String).toLocal(),
        // Minutengenau normalisieren — Altdaten können Sekunden enthalten.
        workStart: j['workStart'] != null
            ? roundToMinute(DateTime.parse(j['workStart'] as String).toLocal())
            : null,
        workEnd: j['workEnd'] != null
            ? roundToMinute(DateTime.parse(j['workEnd'] as String).toLocal())
            : null,
        breaks: ((j['breaks'] as List<dynamic>?) ?? [])
            .map((b) => BreakEntity(
                  id: (b['id'] as String?) ?? const Uuid().v4(),
                  name: (b['name'] as String?) ?? 'Pause',
                  start: roundToMinute(
                      DateTime.parse(b['start'] as String).toLocal()),
                  end: b['end'] != null
                      ? roundToMinute(
                          DateTime.parse(b['end'] as String).toLocal())
                      : null,
                  isAutomatic: (b['isAutomatic'] as bool?) ?? false,
                ))
            .toList(),
        manualOvertime: j['manualOvertimeMinutes'] != null
            ? Duration(minutes: (j['manualOvertimeMinutes'] as num).toInt())
            : null,
        description: j['description'] as String?,
        isManuallyEntered: (j['isManuallyEntered'] as bool?) ?? false,
        type: WorkEntryType.values.firstWhere(
          (e) => e.name == j['type'],
          orElse: () => WorkEntryType.work,
        ),
      );
}
