import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'package:flutter_work_time/core/config/api_config.dart';
import 'package:flutter_work_time/core/utils/logger.dart';
import '../../../domain/entities/break_entity.dart';
import '../../../domain/entities/work_entry_entity.dart';
import '../../models/work_entry_model.dart';

/// Low-Level-Client für die .NET-Backend-API: HTTP + Firebase-ID-Token +
/// JSON↔Model-Mapping. Wird von [ApiDataSource] (Work/Overtime/Settings) und
/// direkt vom ReportsViewModel (Reports) genutzt.
class ApiClient {
  final firebase.FirebaseAuth _auth;
  final http.Client _http;

  ApiClient(this._auth, this._http);

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}/api$path');

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

  Future<List<WorkEntryModel>> getWorkEntriesForMonth(int year, int month) async {
    final res = await _http.get(_uri('/work-entries/$year/$month'), headers: await _headers());
    if (res.statusCode != 200) _fail('getWorkEntriesForMonth', res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => _entryFromJson(e as Map<String, dynamic>)).toList();
  }

  Future<WorkEntryModel?> getWorkEntry(int year, int month, int day) async {
    final res = await _http.get(_uri('/work-entries/$year/$month/$day'), headers: await _headers());
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) _fail('getWorkEntry', res);
    return _entryFromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> saveWorkEntry(WorkEntryModel model) async {
    final res = await _http.put(
      _uri('/work-entries'),
      headers: await _headers(),
      body: jsonEncode(_entryToJson(model)),
    );
    if (res.statusCode != 200 && res.statusCode != 204) _fail('saveWorkEntry', res);
  }

  Future<void> deleteWorkEntry(int year, int month, int day) async {
    final res = await _http.delete(_uri('/work-entries/$year/$month/$day'), headers: await _headers());
    if (res.statusCode != 200 && res.statusCode != 204) _fail('deleteWorkEntry', res);
  }

  // ── Overtime ──────────────────────────────────────────────────────────────

  /// Liefert (Saldo, lastUpdated). Saldo in Minuten.
  Future<({int minutes, DateTime? lastUpdated})> getOvertime() async {
    final res = await _http.get(_uri('/overtime'), headers: await _headers());
    if (res.statusCode != 200) _fail('getOvertime', res);
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return (
      minutes: (json['minutes'] as num?)?.toInt() ?? 0,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'] as String).toLocal()
          : null,
    );
  }

  Future<void> saveOvertime(int minutes) async {
    final res = await _http.put(
      _uri('/overtime'),
      headers: await _headers(),
      body: jsonEncode({'minutes': minutes}),
    );
    if (res.statusCode != 200 && res.statusCode != 204) _fail('saveOvertime', res);
  }

  // ── Settings ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getSettings() async {
    final res = await _http.get(_uri('/settings'), headers: await _headers());
    if (res.statusCode != 200) _fail('getSettings', res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> putSettings(Map<String, dynamic> settings) async {
    final res = await _http.put(
      _uri('/settings'),
      headers: await _headers(),
      body: jsonEncode(settings),
    );
    if (res.statusCode != 200 && res.statusCode != 204) _fail('putSettings', res);
  }

  // ── Reports (Roh-JSON; Zeiten in ms) ──────────────────────────────────────

  Future<Map<String, dynamic>> getDailyReport(int year, int month, int day) =>
      _getJson('/reports/daily/$year/$month/$day', 'getDailyReport');

  Future<Map<String, dynamic>> getWeeklyReport(int year, int month, int day) =>
      _getJson('/reports/weekly/$year/$month/$day', 'getWeeklyReport');

  Future<Map<String, dynamic>> getMonthlyReport(int year, int month) =>
      _getJson('/reports/monthly/$year/$month', 'getMonthlyReport');

  Future<Map<String, dynamic>> _getJson(String path, String op) async {
    final res = await _http.get(_uri(path), headers: await _headers());
    if (res.statusCode != 200) _fail(op, res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Mapping ───────────────────────────────────────────────────────────────

  Map<String, dynamic> _entryToJson(WorkEntryModel m) => {
        'id': m.id,
        // UTC-Mitternacht aus lokalen Y/M/D — analog WorkEntryModel.toMap (Flutter-kanonisch)
        'date': DateTime.utc(m.date.year, m.date.month, m.date.day).toIso8601String(),
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
        workStart: j['workStart'] != null ? DateTime.parse(j['workStart'] as String).toLocal() : null,
        workEnd: j['workEnd'] != null ? DateTime.parse(j['workEnd'] as String).toLocal() : null,
        breaks: ((j['breaks'] as List<dynamic>?) ?? [])
            .map((b) => BreakEntity(
                  id: (b['id'] as String?) ?? const Uuid().v4(),
                  name: (b['name'] as String?) ?? 'Pause',
                  start: DateTime.parse(b['start'] as String).toLocal(),
                  end: b['end'] != null ? DateTime.parse(b['end'] as String).toLocal() : null,
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
