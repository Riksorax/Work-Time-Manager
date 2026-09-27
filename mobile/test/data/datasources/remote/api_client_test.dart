import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_work_time/data/datasources/remote/api_client.dart';
import 'package:flutter_work_time/data/models/work_entry_model.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';

/// Handgeschriebener Fake statt Mockito-Codegen: `FirebaseAuth` lässt sich
/// nicht sinnvoll per `@GenerateMocks` erzeugen (Plugin-Klasse ohne
/// öffentlichen Konstruktor). `currentUser` reicht hier aus, `_headers()`
/// braucht nur diesen einen Getter.
class _FakeFirebaseAuth extends Fake implements firebase.FirebaseAuth {
  @override
  firebase.User? get currentUser => null;
}

/// Zeichnet den letzten Request auf, statt echte HTTP-Aufrufe zu machen.
class _RecordingHttpClient extends Fake implements http.Client {
  Uri? lastUri;
  http.Response nextResponse = http.Response('{}', 200);

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    lastUri = url;
    return nextResponse;
  }

  @override
  Future<http.Response> put(Uri url,
      {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    lastUri = url;
    return nextResponse;
  }

  @override
  Future<http.Response> delete(Uri url,
      {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    lastUri = url;
    return nextResponse;
  }
}

void main() {
  late _RecordingHttpClient http_;
  late ApiClient api;

  setUp(() {
    http_ = _RecordingHttpClient();
    api = ApiClient(_FakeFirebaseAuth(), http_);
  });

  group('ApiClient — profileId-Query-Parameter (siehe #239/#291/#292)', () {
    test('getDailyReport ohne profileId hängt keinen Query-Parameter an',
        () async {
      await api.getDailyReport(2026, 9, 26);
      expect(http_.lastUri!.queryParameters, isEmpty);
      expect(http_.lastUri!.path, '/api/reports/daily/2026/9/26');
    });

    test(
        'getDailyReport mit profileId "default" hängt keinen Query-Parameter an',
        () async {
      await api.getDailyReport(2026, 9, 26, profileId: 'default');
      expect(http_.lastUri!.queryParameters, isEmpty);
    });

    test('getDailyReport mit zusätzlichem Profil hängt ?profileId= an',
        () async {
      await api.getDailyReport(2026, 9, 26, profileId: 'p1');
      expect(http_.lastUri!.queryParameters, {'profileId': 'p1'});
    });

    test('getWeeklyReport gibt profileId weiter', () async {
      await api.getWeeklyReport(2026, 9, 26, profileId: 'p1');
      expect(http_.lastUri!.queryParameters, {'profileId': 'p1'});
      expect(http_.lastUri!.path, '/api/reports/weekly/2026/9/26');
    });

    test('getMonthlyReport gibt profileId weiter', () async {
      await api.getMonthlyReport(2026, 9, profileId: 'p1');
      expect(http_.lastUri!.queryParameters, {'profileId': 'p1'});
      expect(http_.lastUri!.path, '/api/reports/monthly/2026/9');
    });

    test('getWorkEntriesForMonth gibt profileId weiter', () async {
      http_.nextResponse = http.Response('[]', 200);
      await api.getWorkEntriesForMonth(2026, 9, profileId: 'p1');
      expect(http_.lastUri!.queryParameters, {'profileId': 'p1'});
    });

    test('saveWorkEntry gibt profileId weiter', () async {
      http_.nextResponse = http.Response('', 204);
      final entry = WorkEntryModel(
        id: '2026-9-26',
        date: DateTime(2026, 9, 26),
        type: WorkEntryType.work,
      );
      await api.saveWorkEntry(entry, profileId: 'p1');
      expect(http_.lastUri!.queryParameters, {'profileId': 'p1'});
    });

    test('deleteWorkEntry gibt profileId weiter', () async {
      http_.nextResponse = http.Response('', 204);
      await api.deleteWorkEntry(2026, 9, 26, profileId: 'p1');
      expect(http_.lastUri!.queryParameters, {'profileId': 'p1'});
    });

    test('getOvertime ohne profileId hängt keinen Query-Parameter an',
        () async {
      http_.nextResponse = http.Response('{"minutes": 0}', 200);
      await api.getOvertime();
      expect(http_.lastUri!.queryParameters, isEmpty);
    });

    test('getOvertime gibt profileId weiter', () async {
      http_.nextResponse = http.Response('{"minutes": 0}', 200);
      await api.getOvertime(profileId: 'p1');
      expect(http_.lastUri!.queryParameters, {'profileId': 'p1'});
    });

    test('saveOvertime gibt profileId weiter', () async {
      http_.nextResponse = http.Response('', 204);
      await api.saveOvertime(30, profileId: 'p1');
      expect(http_.lastUri!.queryParameters, {'profileId': 'p1'});
    });

    test('getSettings gibt profileId weiter', () async {
      http_.nextResponse = http.Response('{}', 200);
      await api.getSettings(profileId: 'p1');
      expect(http_.lastUri!.queryParameters, {'profileId': 'p1'});
    });

    test('putSettings gibt profileId weiter', () async {
      http_.nextResponse = http.Response('', 204);
      await api.putSettings({}, profileId: 'p1');
      expect(http_.lastUri!.queryParameters, {'profileId': 'p1'});
    });
  });
}
