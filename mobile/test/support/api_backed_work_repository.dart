import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/data/datasources/remote/api_client.dart';
import 'package:flutter_work_time/data/datasources/remote/api_data_source.dart';
import 'package:flutter_work_time/data/datasources/remote/firestore_datasource.dart';
import 'package:flutter_work_time/data/repositories/work_repository_impl.dart';
import 'package:http/http.dart' as http;

/// Auth-Teil der [ApiDataSource]; die Work-Pfade rufen ihn nie auf.
class _UnusedAuthDataSource extends Fake implements FirestoreDataSource {}

/// `_headers()` des [ApiClient] braucht nur `currentUser`.
class _NoUserAuth extends Fake implements firebase.FirebaseAuth {
  @override
  firebase.User? get currentUser => null;
}

/// Fake-Backend hinter einem [http.Client] (#418).
///
/// Liefert Work-Eintraege so, wie das echte Backend sie sendet: `date` als
/// UTC-Mitternacht-Zeichenkette (`...Z` oder `...+00:00`), `id` als
/// `yyyy-MM-dd`. Die Eintraege gehen durch den **echten** [ApiClient]-Mapper;
/// genau dort lag der Fehler, den Tests mit lokal gebautem `date` umgehen.
///
/// PUTs werden protokolliert ([puts], dekodierter Body) und - wie im Backend -
/// unter dem Tag des **gesendeten `date`** abgelegt (Slot-Wechsel sichtbar).
class FakeBackendHttpClient extends Fake implements http.Client {
  /// Serverseitige Eintraege: Schluessel `yyyy-MM-dd`, Wert = JSON-Objekt.
  final Map<String, Map<String, dynamic>> entries = {};

  /// Dekodierte Bodys aller `PUT /api/work-entries`.
  final List<Map<String, dynamic>> puts = [];

  /// Alle angefragten URIs in Reihenfolge.
  final List<Uri> requests = [];

  /// Antworten auf `/api/reports/...`; Default 500, damit `ReportsViewModel`
  /// auf die lokale Berechnung zurueckfaellt.
  final Map<String, http.Response> reports = {};

  /// Legt einen Eintrag ab. [dateJson] ist das gesendete `date`, Default
  /// UTC-Mitternacht von [id].
  void seed(
    String id, {
    String? dateJson,
    String? workStart,
    String? workEnd,
    String type = 'work',
    List<Map<String, dynamic>> breaks = const [],
    String? key,
  }) {
    entries[key ?? id] = {
      'id': id,
      'date': dateJson ?? '${id}T00:00:00.000Z',
      'workStart': workStart,
      'workEnd': workEnd,
      'type': type,
      'isManuallyEntered': false,
      'manualOvertimeMinutes': null,
      'description': null,
      'breaks': breaks,
    };
  }

  static String _key(int y, int m, int d) =>
      '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-'
      '${d.toString().padLeft(2, '0')}';

  http.Response _json(Object body, [int status = 200]) => http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    requests.add(url);
    final seg = url.pathSegments; // api, work-entries, y, m[, d]
    if (seg.length >= 2 && seg[1] == 'reports') {
      return reports[url.path] ?? http.Response('boom', 500);
    }
    if (seg.length >= 4 && seg[1] == 'work-entries') {
      final y = int.parse(seg[2]);
      final m = int.parse(seg[3]);
      if (seg.length == 5) {
        final hit = entries[_key(y, m, int.parse(seg[4]))];
        return hit == null ? http.Response('', 404) : _json(hit);
      }
      final prefix = _key(y, m, 1).substring(0, 8);
      final list = entries.entries
          .where((e) => e.key.startsWith(prefix))
          .map((e) => e.value)
          .toList();
      return _json(list);
    }
    return http.Response('{}', 404);
  }

  @override
  Future<http.Response> put(Uri url,
      {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    requests.add(url);
    final json = jsonDecode(body! as String) as Map<String, dynamic>;
    puts.add(json);
    final d = DateTime.parse(json['date'] as String).toUtc();
    entries[_key(d.year, d.month, d.day)] = json;
    return http.Response('', 204);
  }

  @override
  Future<http.Response> delete(Uri url,
      {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    requests.add(url);
    return http.Response('', 204);
  }
}

/// Verdrahtung `WorkRepositoryImpl` -> `ApiDataSource` -> echter [ApiClient]
/// -> [FakeBackendHttpClient] (wie `providers.dart:100`, ohne Hybrid-Local).
class ApiBackedWork {
  ApiBackedWork({String? profileId}) {
    api = ApiClient(_NoUserAuth(), backend);
    repository = WorkRepositoryImpl(
      dataSource: ApiDataSource(_UnusedAuthDataSource(), api),
      userId: 'u',
      profileId: profileId,
    );
  }

  final FakeBackendHttpClient backend = FakeBackendHttpClient();
  late final ApiClient api;
  late final WorkRepositoryImpl repository;
}
