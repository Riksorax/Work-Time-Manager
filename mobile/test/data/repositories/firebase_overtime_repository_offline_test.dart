import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/utils/api_errors.dart';
import 'package:flutter_work_time/data/datasources/remote/firestore_datasource.dart';
import 'package:flutter_work_time/data/repositories/firebase_overtime_repository_impl.dart';
import 'package:flutter_work_time/data/repositories/hybrid_overtime_repository_impl.dart';
import 'package:flutter_work_time/data/repositories/local_overtime_repository_impl.dart';
import 'package:flutter_work_time/domain/entities/overtime_freshness.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/reported_logs.dart';

/// Server-Saldo je Nutzer und Profil; [offline] lässt jeden Aufruf mit einem
/// Netzwerkfehler scheitern, [failWith] mit einem beliebigen Fehler.
class _ServerDs extends Fake implements FirestoreDataSource {
  final Map<String, Duration> balance = {};
  final Map<String, DateTime?> lastUpdate = {};
  bool offline = false;
  Object? failWith;

  String _k(String uid, String? p) => '$uid|${p ?? 'default'}';

  void _check() {
    if (offline) {
      throw const SocketException('Failed host lookup',
          osError: OSError('No address associated with hostname', 7));
    }
    final f = failWith;
    if (f != null) throw f;
  }

  @override
  Future<Duration> getOvertime(String userId, {String? profileId}) async {
    _check();
    return balance[_k(userId, profileId)] ?? Duration.zero;
  }

  @override
  Future<DateTime?> getLastOvertimeUpdate(String userId,
      {String? profileId}) async {
    _check();
    return lastUpdate[_k(userId, profileId)];
  }

  @override
  Future<void> saveOvertime(String userId, Duration overtime,
      {String? profileId, bool keepLastUpdated = false}) async {
    _check();
    balance[_k(userId, profileId)] = overtime;
  }

  @override
  Future<void> saveLastOvertimeUpdate(String userId, DateTime date,
      {String? profileId}) async {
    _check();
    lastUpdate[_k(userId, profileId)] = date;
  }
}

void main() {
  final logs = <LogEvent>[];
  captureLogs(logs);

  late SharedPreferences prefs;
  late _ServerDs ds;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    ds = _ServerDs();
  });

  FirebaseOvertimeRepositoryImpl repo(String uid, {String? profileId}) =>
      FirebaseOvertimeRepositoryImpl(
          dataSource: ds, userId: uid, profileId: profileId, prefs: prefs);

  final lastUpdate = DateTime(2026, 3, 4, 17, 30);

  group('Zuletzt bekannter Saldo (#573)', () {
    test('Laden merkt den Saldo, ein neues Repository liefert ihn ohne Netz',
        () async {
      ds.balance['u1|default'] = const Duration(hours: 12, minutes: 30);
      ds.lastUpdate['u1|default'] = lastUpdate;
      final online = repo('u1');
      expect(await online.ensureOvertimeLoaded(),
          const Duration(hours: 12, minutes: 30));
      expect(await online.ensureLastUpdateLoaded(), lastUpdate);
      expect(online.overtimeFreshness, OvertimeFreshness.current);

      // Neustart ohne Netz: neue Instanz, gleicher Speicher.
      ds.offline = true;
      final restarted = repo('u1');
      expect(await restarted.ensureOvertimeLoaded(),
          const Duration(hours: 12, minutes: 30));
      expect(await restarted.ensureLastUpdateLoaded(), lastUpdate);
      expect(restarted.overtimeFreshness, OvertimeFreshness.cached);
      expect(restarted.getOvertime(), const Duration(hours: 12, minutes: 30));
      expect(reported(logs, 'Overtime'), isEmpty);
    });

    test('Speichern merkt den Saldo und das Datum', () async {
      final online = repo('u1');
      await online.saveOvertime(const Duration(minutes: -95));
      await online.saveLastUpdateDate(lastUpdate);

      ds.offline = true;
      final restarted = repo('u1');
      expect(await restarted.ensureOvertimeLoaded(),
          const Duration(minutes: -95));
      expect(await restarted.ensureLastUpdateLoaded(), lastUpdate);
      expect(restarted.overtimeFreshness, OvertimeFreshness.cached);
    });

    test('ohne gemerkten Saldo: Ladefehler wird weitergereicht, unbekannt',
        () async {
      ds.offline = true;
      final r = repo('u1');
      await expectLater(r.ensureOvertimeLoaded(), throwsA(isA<SocketException>()));
      expect(r.overtimeFreshness, OvertimeFreshness.unknown);
      expect(reported(logs, 'Overtime'), isEmpty);
    });

    test('kein angemeldeter Nutzer zählt wie ein erwartbarer Ladefehler',
        () async {
      ds.balance['u1|default'] = const Duration(hours: 2);
      await repo('u1').ensureOvertimeLoaded();
      ds.failWith = const NotSignedInException('getOvertime');
      final r = repo('u1');
      expect(await r.ensureOvertimeLoaded(), const Duration(hours: 2));
      expect(r.overtimeFreshness, OvertimeFreshness.cached);
    });

    test('unerwarteter Fehler: kein Ersatzwert, Fehler wird weitergereicht',
        () async {
      ds.balance['u1|default'] = const Duration(hours: 2);
      await repo('u1').ensureOvertimeLoaded();
      ds.failWith = const ApiException('getOvertime', 500);
      final r = repo('u1');
      await expectLater(
          r.ensureOvertimeLoaded(), throwsA(isA<ApiException>()));
      expect(r.overtimeFreshness, isNot(OvertimeFreshness.cached));
    });

    test('Nutzerwechsel: nie der Saldo eines anderen Nutzers', () async {
      ds.balance['u1|default'] = const Duration(hours: 7);
      await repo('u1').ensureOvertimeLoaded();

      ds.offline = true;
      final other = repo('u2');
      await expectLater(other.ensureOvertimeLoaded(), throwsA(anything));
      expect(other.overtimeFreshness, OvertimeFreshness.unknown);
      expect(other.getOvertime(), Duration.zero);
      expect(repo('u1').getOvertime(), const Duration(hours: 7));
    });

    test('Profilwechsel: Werte je Arbeitszeit-Profil getrennt', () async {
      ds.balance['u1|default'] = const Duration(hours: 7);
      ds.balance['u1|p2'] = const Duration(minutes: -30);
      await repo('u1').ensureOvertimeLoaded();
      await repo('u1', profileId: 'p2').ensureOvertimeLoaded();

      ds.offline = true;
      expect(await repo('u1').ensureOvertimeLoaded(), const Duration(hours: 7));
      expect(await repo('u1', profileId: 'p2').ensureOvertimeLoaded(),
          const Duration(minutes: -30));
      // 'default' ist das Standard-Profil.
      expect(await repo('u1', profileId: 'default').ensureOvertimeLoaded(),
          const Duration(hours: 7));
      final p3 = repo('u1', profileId: 'p3');
      await expectLater(p3.ensureOvertimeLoaded(), throwsA(anything));
      expect(p3.overtimeFreshness, OvertimeFreshness.unknown);
    });

    test('Hybrid reicht die Herkunft des aktiven Repositories durch', () async {
      ds.offline = true;
      final firebase = repo('u1');
      final hybrid = HybridOvertimeRepositoryImpl(
          firebaseRepository: firebase,
          localRepository: LocalOvertimeRepositoryImpl(prefs),
          userId: 'u1');
      await expectLater(hybrid.ensureOvertimeLoaded(), throwsA(anything));
      expect(hybrid.overtimeFreshness, OvertimeFreshness.unknown);

      final guest = HybridOvertimeRepositoryImpl(
          firebaseRepository: LocalOvertimeRepositoryImpl(prefs),
          localRepository: LocalOvertimeRepositoryImpl(prefs),
          userId: null);
      await guest.ensureOvertimeLoaded();
      expect(guest.overtimeFreshness, OvertimeFreshness.current);
    });
  });
}
