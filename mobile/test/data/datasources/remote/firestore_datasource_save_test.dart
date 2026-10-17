// Minimal-Fake implementiert sealed-Klassen des Plugins bewusst (wie
// firestore_datasource_tz_test.dart; fake_cloud_firestore ist mit dem
// gepinnten cloud_firestore nicht kompilierbar).
// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/data/datasources/remote/firestore_datasource.dart';
import 'package:flutter_work_time/data/models/work_entry_model.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// #277: Der Firestore-Direktpfad (zusaetzliche Arbeitszeit-Profile) schreibt
/// `days.{d}.isHomeOffice` per Merge, ohne andere Tage zu ueberschreiben.
class _FakeAuth extends Fake implements firebase.FirebaseAuth {}

class _FakeGoogle extends Fake implements GoogleSignIn {}

Map<String, dynamic> _deepMerge(
    Map<String, dynamic> base, Map<String, dynamic> add) {
  final out = Map<String, dynamic>.from(base);
  add.forEach((k, v) {
    final old = out[k];
    out[k] = (old is Map<String, dynamic> && v is Map<String, dynamic>)
        ? _deepMerge(old, v)
        : v;
  });
  return out;
}

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

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    _store[_path] =
        options?.merge == true ? _deepMerge(_store[_path] ?? {}, data) : data;
  }
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
  final Map<String, Map<String, dynamic>> store = {};

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(store, path);
}

void main() {
  late _FakeFirestore firestore;
  late FirestoreDataSourceImpl ds;

  setUp(() {
    firestore = _FakeFirestore();
    ds = FirestoreDataSourceImpl(_FakeAuth(), firestore, _FakeGoogle());
  });

  WorkEntryModel entry(int day, {bool homeOffice = false}) => WorkEntryModel(
        id: WorkEntryModel.generateId(DateTime(2026, 6, day)),
        date: DateTime(2026, 6, day),
        isHomeOffice: homeOffice,
      );

  test('saveWorkEntry schreibt days.5.isHomeOffice', () async {
    await ds.saveWorkEntry('u', entry(5, homeOffice: true));
    final days = firestore.store['users/u/work_entries/2026-06']!['days']
        as Map<String, dynamic>;
    expect((days['5'] as Map)['isHomeOffice'], isTrue);
  });

  test('zweiter Tag im selben Monat laesst den ersten erhalten', () async {
    await ds.saveWorkEntry('u', entry(5, homeOffice: true));
    await ds.saveWorkEntry('u', entry(8));
    final days = firestore.store['users/u/work_entries/2026-06']!['days']
        as Map<String, dynamic>;
    expect((days['5'] as Map)['isHomeOffice'], isTrue);
    expect((days['8'] as Map)['isHomeOffice'], isFalse);
  });

  test('Zuruecksetzen auf false ueberschreibt true', () async {
    await ds.saveWorkEntry('u', entry(5, homeOffice: true));
    await ds.saveWorkEntry('u', entry(5));
    final loaded = await ds.getWorkEntry('u', DateTime(2026, 6, 5));
    expect(loaded!.isHomeOffice, isFalse);
  });

  test('Profilpfad profiles/{id}/work_entries, Roundtrip ueber Lesen',
      () async {
    await ds.saveWorkEntry('u', entry(5, homeOffice: true), profileId: 'p1');
    expect(
        firestore.store.containsKey('users/u/work_entries/2026-06'), isFalse);
    final days =
        firestore.store['users/u/profiles/p1/work_entries/2026-06']!['days']
            as Map<String, dynamic>;
    expect((days['5'] as Map)['isHomeOffice'], isTrue);
    final back =
        await ds.getWorkEntry('u', DateTime(2026, 6, 5), profileId: 'p1');
    expect(back!.isHomeOffice, isTrue);
    final list = await ds.getWorkEntriesForMonth('u', 2026, 6, profileId: 'p1');
    expect(list.single.isHomeOffice, isTrue);
  });
}
