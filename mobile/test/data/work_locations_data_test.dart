import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/data/models/work_entry_model.dart';
import 'package:flutter_work_time/data/repositories/hybrid_work_repository_impl.dart';
import 'package:flutter_work_time/data/repositories/local_work_repository_impl.dart';
import 'package:flutter_work_time/data/repositories/work_location_history.dart';
import 'package:flutter_work_time/data/services/data_sync_service.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_repositories.dart';

// Arbeitsorte (#526) in Entity, Model, lokalem Repository, Migration und
// Vorschlags-Verlauf. `null` = unangetastet, `[]` = entfernen.
void main() {
  final day = DateTime(2026, 10, 5);
  const two = ['Büro Köln', 'Kunde A'];

  WorkEntryEntity entry({List<String>? locs, String id = '2026-10-05'}) =>
      WorkEntryEntity(
        id: id,
        date: localDay(id),
        workStart: DateTime(2026, 10, 5, 8),
        workLocations: locs,
      );

  group('Entity', () {
    test('Standard null; locations zeigt leer', () {
      final e = WorkEntryEntity(id: '2026-10-05', date: day);
      expect(e.workLocations, isNull);
      expect(e.locations, isEmpty);
    });

    test('copyWith: null behält, [] leert, Liste ersetzt', () {
      final e = entry(locs: two);
      expect(e.copyWith(isHomeOffice: true).workLocations, two);
      expect(e.copyWith(workLocations: const []).workLocations, isEmpty);
      expect(e.copyWith(workLocations: const ['X']).workLocations, ['X']);
    });

    test('props: Orte zählen für die Gleichheit', () {
      expect(entry(locs: two), entry(locs: const ['Büro Köln', 'Kunde A']));
      expect(entry(locs: two), isNot(entry(locs: const ['Kunde A'])));
      expect(entry(), isNot(entry(locs: const [])));
    });
  });

  group('WorkEntryModel', () {
    test('Round-Trip über toMap/fromMap', () {
      final m = WorkEntryModel.fromEntity(entry(locs: two));
      final map = m.toMap();
      expect(map['workLocations'], two);
      final back = WorkEntryModel.fromMap(map);
      expect(back.workLocations, two);
    });

    test('fehlendes Feld liest als leer (nie null)', () {
      final map = WorkEntryModel.fromEntity(entry()).toMap();
      expect(map.containsKey('workLocations'), isFalse,
          reason: 'null schreibt kein Feld (Altpfad merge behält Orte)');
      expect(WorkEntryModel.fromMap(map).workLocations, isNotNull);
      expect(WorkEntryModel.fromMap(map).workLocations, isEmpty);
    });

    test('[] schreibt eine leere Liste, Werte werden bereinigt', () {
      expect(WorkEntryModel.fromEntity(entry(locs: const [])).toMap(),
          containsPair('workLocations', isEmpty));
      expect(
          WorkEntryModel.fromEntity(entry(locs: const [' A ', 'a', 'B']))
              .toMap()['workLocations'],
          ['A', 'B']);
    });

    test('fromDayMap behält die Orte', () {
      final map = {
        'date': Timestamp.fromDate(DateTime.utc(2026, 10, 5)),
        'workLocations': two,
      };
      final m = WorkEntryModel.fromDayMap(map, day);
      expect(m.id, '2026-10-05');
      expect(m.workLocations, two);
    });

    test('copyWith des Models', () {
      final m = WorkEntryModel.fromEntity(entry(locs: two));
      expect(m.copyWith(id: 'x').workLocations, two);
      expect(m.copyWith(workLocations: const []).workLocations, isEmpty);
    });
  });

  group('LocalWorkRepositoryImpl (Gast)', () {
    late SharedPreferences prefs;
    late LocalWorkRepositoryImpl repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      repo = LocalWorkRepositoryImpl(prefs);
    });

    test('speichert und liest die Orte', () async {
      await repo.saveWorkEntry(entry(locs: two));
      expect((await repo.getWorkEntry(day)).workLocations, two);
      expect((await repo.getWorkEntriesForMonth(2026, 10)).single.workLocations,
          two);
    });

    test('null beim Speichern behält die vorhandenen Orte', () async {
      await repo.saveWorkEntry(entry(locs: two));
      await repo.saveWorkEntry(entry().copyWith(isHomeOffice: true));
      final loaded = await repo.getWorkEntry(day);
      expect(loaded.workLocations, two);
      expect(loaded.isHomeOffice, isTrue);
    });

    test('[] entfernt die Orte (Feld fällt weg)', () async {
      await repo.saveWorkEntry(entry(locs: two));
      await repo.saveWorkEntry(entry(locs: const []));
      expect((await repo.getWorkEntry(day)).workLocations, isEmpty);
      final raw = jsonDecode(prefs.getString('local_work_entries_2026_10')!)
          as Map<String, dynamic>;
      expect((raw['days'] as Map)['5'], isNot(contains('workLocations')));
    });

    test('Altbestand ohne Feld liest als leer', () async {
      await repo.saveWorkEntry(entry());
      expect((await repo.getWorkEntry(day)).workLocations, isEmpty);
    });

    test('bereinigt vor dem Speichern', () async {
      await repo.saveWorkEntry(entry(locs: const [' A ', 'a', '', 'B']));
      expect((await repo.getWorkEntry(day)).workLocations, ['A', 'B']);
    });
  });

  test('DataSyncService übernimmt die Orte in die Cloud', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final local = LocalWorkRepositoryImpl(prefs);
    await local.saveWorkEntry(entry(locs: two));
    final cloud = FakeWorkRepository();

    final count = await DataSyncService.syncWorkEntries(
        localRepository: local, firebaseRepository: cloud);

    expect(count, 1);
    expect(cloud.saved.single.workLocations, two);
  });

  group('WorkLocationHistory (Vorschläge)', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('merkt Orte, zuletzt verwendete zuerst, ohne gewählte', () {
      final h = WorkLocationHistory(prefs, userId: 'u1');
      h.record([
        entry(id: '2026-10-01', locs: const ['Alt']),
        entry(id: '2026-10-05', locs: two),
      ]);
      expect(h.suggestions(const []), ['Büro Köln', 'Kunde A', 'Alt']);
      expect(h.suggestions(const ['kunde a']), ['Büro Köln', 'Alt']);
      expect(h.suggestions(const [], filter: 'kö'), ['Büro Köln']);
      // Bleibt über eine neue Instanz erhalten (SharedPreferences).
      expect(WorkLocationHistory(prefs, userId: 'u1').suggestions(const []),
          ['Büro Köln', 'Kunde A', 'Alt']);
    });

    test('null ändert nichts, [] und andere Typen entfernen den Tag', () {
      final h = WorkLocationHistory(prefs, userId: 'u1');
      h.record([entry(locs: two)]);
      h.record([entry()]);
      expect(h.suggestions(const []), two);
      h.record([entry(locs: const [])]);
      expect(h.suggestions(const []), isEmpty);
      h.record([entry(locs: two)]);
      h.record([entry(locs: two).copyWith(type: WorkEntryType.vacation)]);
      expect(h.suggestions(const []), isEmpty);
    });

    test('getrennt je Nutzer und Profil, Gast mit eigenem Schlüssel', () {
      WorkLocationHistory(prefs, userId: 'u1').record([entry(locs: two)]);
      expect(WorkLocationHistory(prefs, userId: 'u2').suggestions(const []),
          isEmpty);
      expect(
          WorkLocationHistory(prefs, userId: 'u1', profileId: 'p')
              .suggestions(const []),
          isEmpty);
      expect(
          WorkLocationHistory(prefs, userId: 'u1', profileId: 'default')
              .suggestions(const []),
          two);
      expect(WorkLocationHistory.keyFor(userId: 'local'),
          'work_location_history_local');
      expect(WorkLocationHistory.keyFor(userId: 'u1', profileId: 'p'),
          'work_location_history_u1_p');
    });

    test('höchstens 40 Tage, die jüngsten bleiben', () {
      final h = WorkLocationHistory(prefs, userId: 'u1');
      String idOf(int i) {
        final d = DateTime(2026, 1, 1 + i);
        return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
            '${d.day.toString().padLeft(2, '0')}';
      }

      h.record([
        for (var i = 0; i < 45; i++) entry(id: idOf(i), locs: ['Ort $i'])
      ]);
      final stored = jsonDecode(prefs.getString(h.storageKey)!) as List;
      expect(stored, hasLength(WorkLocationHistory.maxDays));
      expect((stored.first as Map)['d'], idOf(44));
      expect((stored.last as Map)['d'], idOf(5));
      expect(h.suggestions(const []).first, 'Ort 44');
    });

    test('kaputter Speicher: leer, kein Fehler', () async {
      SharedPreferences.setMockInitialValues(
          {'work_location_history_u1': '{kaputt'});
      final p = await SharedPreferences.getInstance();
      expect(
          WorkLocationHistory(p, userId: 'u1').suggestions(const []), isEmpty);
    });
  });

  group('HybridWorkRepositoryImpl speist den Verlauf', () {
    test('Lesen und Speichern melden die Einträge', () async {
      final inner = FakeWorkRepository();
      inner.store['2026-10-05'] = entry(locs: two);
      final seen = <WorkEntryEntity>[];
      final repo = HybridWorkRepositoryImpl(
        firebaseRepository: inner,
        localRepository: inner,
        userId: 'u1',
        onEntriesSeen: seen.addAll,
      );
      await repo.getWorkEntry(day);
      await repo.getWorkEntriesForMonth(2026, 10);
      await repo.saveWorkEntry(entry(locs: const ['X']));
      expect(seen.map((e) => e.workLocations), [
        two,
        two,
        ['X']
      ]);
    });

    test('Fehler im Verlauf brechen das Lesen nicht ab', () async {
      final inner = FakeWorkRepository();
      final repo = HybridWorkRepositoryImpl(
        firebaseRepository: inner,
        localRepository: inner,
        userId: null,
        onEntriesSeen: (_) => throw StateError('kaputt'),
      );
      await repo.saveWorkEntry(entry(locs: two));
      expect((await repo.getWorkEntry(day)).workLocations, two);
    });
  });
}

DateTime localDay(String id) {
  final p = id.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}
