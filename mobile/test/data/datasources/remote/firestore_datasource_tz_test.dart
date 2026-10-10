// DocumentSnapshot/DocumentReference/Query sind im Plugin "sealed"; der
// handgeschriebene Minimal-Fake unten implementiert sie bewusst (Fake statt
// fake_cloud_firestore, siehe Kommentar an _FakeAuth).
// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/data/datasources/remote/firestore_datasource.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../support/timezone_guard.dart';

/// Regression #418 fuer die Verdrahtung der Firestore-Datasource: Lese-
/// Aufrufer (`getWorkEntry`, `getWorkEntriesForMonth`) muessen `fromDayMap`
/// nutzen, damit der Tages-Key des Monatsdokuments den Tag bestimmt.
///
/// `fake_cloud_firestore` ist mit dem gepinnten `cloud_firestore` nicht
/// kompilierbar (Spike #418: `MockWriteBatch.update` passt nicht zur
/// Plattform-Schnittstelle), daher ein handgeschriebener Minimal-Fake, der nur
/// `collection().doc().collection().doc().get()` kann.
class _FakeAuth extends Fake implements firebase.FirebaseAuth {}

class _FakeGoogle extends Fake implements GoogleSignIn {}

class _Snapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this._data);
  final Map<String, dynamic>? _data;

  @override
  bool get exists => _data != null;

  @override
  Map<String, dynamic>? data() => _data;
}

class _Doc extends Fake implements DocumentReference<Map<String, dynamic>> {
  _Doc(this._store, this._path);
  final Map<String, Map<String, dynamic>> _store;
  final String _path;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      _Collection(_store, '$_path/$collectionPath');

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get(
          [GetOptions? options]) async =>
      _Snapshot(_store[_path]);
}

class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(this._store, this._path);
  final Map<String, Map<String, dynamic>> _store;
  final String _path;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Doc(_store, '$_path/$path');
}

class _FakeFirestore extends Fake implements FirebaseFirestore {
  /// Dokumentpfad (`users/u/work_entries/2026-10`) -> Daten.
  final Map<String, Map<String, dynamic>> store = {};

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(store, path);
}

void main() {
  registerTimezoneCanary();

  late _FakeFirestore firestore;
  late FirestoreDataSourceImpl ds;

  setUp(() {
    firestore = _FakeFirestore();
    ds = FirestoreDataSourceImpl(_FakeAuth(), firestore, _FakeGoogle());
  });

  Map<String, dynamic> day(DateTime utc) =>
      {'date': Timestamp.fromDate(utc), 'type': 'work'};

  test('getWorkEntry: id und date kommen aus dem Tages-Key', () async {
    firestore.store['users/u/work_entries/2026-10'] = {
      'days': {'5': day(DateTime.utc(2026, 10, 5))},
    };
    final e = (await ds.getWorkEntry('u', DateTime(2026, 10, 5)))!;
    expect(e.id, '2026-10-05');
    expect(e.date, DateTime(2026, 10, 5));
    expect(e.date.weekday, DateTime.monday);
  });

  test('getWorkEntriesForMonth: id und date kommen aus dem Tages-Key',
      () async {
    firestore.store['users/u/work_entries/2026-11'] = {
      'days': {
        '1': day(DateTime.utc(2026, 11, 1)),
        '2': day(DateTime.utc(2026, 11, 2)),
      },
    };
    final list = await ds.getWorkEntriesForMonth('u', 2026, 11);
    expect(list.map((e) => e.id), ['2026-11-01', '2026-11-02']);
    expect(list.map((e) => e.date),
        [DateTime(2026, 11, 1), DateTime(2026, 11, 2)]);
  });

  test('Profil: zusaetzliches Profil liest ueber denselben Mapper', () async {
    firestore.store['users/u/profiles/p1/work_entries/2026-10'] = {
      'days': {'5': day(DateTime.utc(2026, 10, 5))},
    };
    final e =
        (await ds.getWorkEntry('u', DateTime(2026, 10, 5), profileId: 'p1'))!;
    expect(e.date, DateTime(2026, 10, 5));
  });

  group('Altdaten: der Tages-Key gewinnt gegen das gespeicherte date', () {
    test('getWorkEntry', () async {
      firestore.store['users/u/work_entries/2026-10'] = {
        'days': {'5': day(DateTime.utc(2026, 10, 4, 22))},
      };
      final e = (await ds.getWorkEntry('u', DateTime(2026, 10, 5)))!;
      expect(e.id, '2026-10-05');
      expect(e.date, DateTime(2026, 10, 5));
    });

    test('getWorkEntriesForMonth', () async {
      firestore.store['users/u/work_entries/2026-10'] = {
        'days': {'5': day(DateTime.utc(2026, 10, 4, 22))},
      };
      final list = await ds.getWorkEntriesForMonth('u', 2026, 10);
      expect(list.single.id, '2026-10-05');
      expect(list.single.date, DateTime(2026, 10, 5));
    });
  });
}
