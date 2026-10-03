import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_work_time/data/datasources/remote/firestore_datasource.dart';
import 'package:flutter_work_time/data/repositories/settings_repository_impl.dart';
import 'package:flutter_work_time/domain/entities/bundesland.dart';

import 'settings_repository_impl_test.mocks.dart';

@GenerateMocks([FirestoreDataSource])
void main() {
  late MockFirestoreDataSource mockDs;

  setUp(() {
    mockDs = MockFirestoreDataSource();
    when(mockDs.saveSettings(any, any, profileId: anyNamed('profileId')))
        .thenAnswer((_) async {});
  });

  Future<SettingsRepositoryImpl> repo(
      {String uid = 'u1',
      String? profile,
      Map<String, Object> initial = const {}}) async {
    SharedPreferences.setMockInitialValues(initial);
    final prefs = await SharedPreferences.getInstance();
    return SettingsRepositoryImpl(prefs, mockDs, uid, profile);
  }

  test('Getter ohne Key liefert 30', () async {
    expect((await repo()).getVacationDaysPerYear(), 30);
  });

  test('Setter schreibt profilspezifischen Key', () async {
    final r = await repo(uid: 'u1');
    await r.setVacationDaysPerYear(25);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('vacation_days_per_year_u1'), 25);
    expect(r.getVacationDaysPerYear(), 25);
  });

  test('Profile A und B sind getrennt', () async {
    final a = await repo(profile: 'A');
    await a.setVacationDaysPerYear(20);
    final prefs = await SharedPreferences.getInstance();
    final b = SettingsRepositoryImpl(prefs, mockDs, 'u1', 'B');
    expect(b.getVacationDaysPerYear(), 30);
    await b.setVacationDaysPerYear(10);
    expect(a.getVacationDaysPerYear(), 20);
    expect(prefs.getInt('vacation_days_per_year_u1_B'), 10);
  });

  test('anonym: kein API-Aufruf', () async {
    final r = await repo(uid: 'local');
    await r.setVacationDaysPerYear(12);
    expect(r.getVacationDaysPerYear(), 12);
    verifyNever(
        mockDs.saveSettings(any, any, profileId: anyNamed('profileId')));
  });

  test('eingeloggt: saveSettings mit vacationDaysPerYear', () async {
    final r = await repo(profile: 'A');
    await r.setVacationDaysPerYear(27);
    verify(mockDs.saveSettings('u1', {'vacationDaysPerYear': 27},
            profileId: 'A'))
        .called(1);
  });

  test('API-Fehler: lokaler Wert bleibt, kein Throw', () async {
    when(mockDs.saveSettings(any, any, profileId: anyNamed('profileId')))
        .thenAnswer((_) async => throw Exception('offline'));
    final r = await repo();
    await r.setVacationDaysPerYear(22);
    await Future<void>.delayed(Duration.zero);
    expect(r.getVacationDaysPerYear(), 22);
  });

  test('Getter defensiv bei Fremdtyp und ausserhalb 0-366', () async {
    expect(
        (await repo(initial: {'vacation_days_per_year_u1': 'abc'}))
            .getVacationDaysPerYear(),
        30);
    expect(
        (await repo(initial: {'vacation_days_per_year_u1': 400}))
            .getVacationDaysPerYear(),
        30);
    expect(
        (await repo(initial: {'vacation_days_per_year_u1': -1}))
            .getVacationDaysPerYear(),
        30);
    expect(
        (await repo(initial: {'vacation_days_per_year_u1': 0}))
            .getVacationDaysPerYear(),
        0);
    expect(
        (await repo(initial: {'vacation_days_per_year_u1': 366}))
            .getVacationDaysPerYear(),
        366);
  });

  group('syncFromFirestore', () {
    test('uebernimmt vacationDaysPerYear', () async {
      when(mockDs.getSettings('u1', profileId: anyNamed('profileId')))
          .thenAnswer((_) async => {'vacationDaysPerYear': 24});
      final r = await repo();
      await r.syncFromFirestore();
      expect(r.getVacationDaysPerYear(), 24);
    });

    test('ignoriert fehlendes oder ungueltiges Feld', () async {
      final r = await repo(initial: {'vacation_days_per_year_u1': 21});
      when(mockDs.getSettings('u1', profileId: anyNamed('profileId')))
          .thenAnswer((_) async => {'weeklyTargetHours': 30});
      await r.syncFromFirestore();
      expect(r.getVacationDaysPerYear(), 21);

      for (final bad in <Object>['x', 999, -3, 2.5]) {
        when(mockDs.getSettings('u1', profileId: anyNamed('profileId')))
            .thenAnswer((_) async => {'vacationDaysPerYear': bad});
        await r.syncFromFirestore();
        expect(r.getVacationDaysPerYear(), 21, reason: '$bad');
      }
    });
  });

  group('Bundesland', () {
    test('setBundesland schreibt Key mit uid und synchronisiert', () async {
      final r = await repo();
      await r.setBundesland(Bundesland.sachsen);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('bundesland_u1'), 'sachsen');
      expect(r.getBundesland(), Bundesland.sachsen);
      verify(mockDs.saveSettings('u1', {'bundesland': 'sachsen'},
              profileId: null))
          .called(1);
    });

    test('Profil-Suffix und Profile getrennt', () async {
      final a = await repo(profile: 'p1');
      await a.setBundesland(Bundesland.bayern);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('bundesland_u1_p1'), 'bayern');
      verify(mockDs.saveSettings('u1', {'bundesland': 'bayern'},
              profileId: 'p1'))
          .called(1);
      final b = SettingsRepositoryImpl(prefs, mockDs, 'u1', 'p2');
      expect(b.getBundesland(), isNull);
      await b.setBundesland(Bundesland.berlin);
      expect(a.getBundesland(), Bundesland.bayern);
      expect(b.getBundesland(), Bundesland.berlin);
    });

    test('setBundesland(null) schreibt leer, loescht globalen Key, sendet ""',
        () async {
      final r = await repo(initial: {'bundesland': 'bayern'});
      expect(r.getBundesland(), Bundesland.bayern);
      await r.setBundesland(null);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('bundesland_u1'), '');
      expect(prefs.containsKey('bundesland'), isFalse);
      expect(r.getBundesland(), isNull);
      verify(mockDs.saveSettings('u1', {'bundesland': ''}, profileId: null))
          .called(1);
    });

    test('leerer neuer Key liefert null ohne Fallback', () async {
      final r = await repo(initial: {
        'bundesland_u1': '',
        'bundesland_local': 'bayern',
        'bundesland': 'berlin',
      });
      expect(r.getBundesland(), isNull);
    });

    test('Fallback auf bundesland_local mit gleichem Suffix, dann global',
        () async {
      final r = await repo(profile: 'p1', initial: {
        'bundesland_local_p1': 'hessen',
        'bundesland': 'berlin',
      });
      expect(r.getBundesland(), Bundesland.hessen);
      final g = await repo(initial: {'bundesland': 'berlin'});
      expect(g.getBundesland(), Bundesland.berlin);
    });

    test('neuer Key hat Vorrang', () async {
      final r = await repo(initial: {
        'bundesland_u1': 'sachsen',
        'bundesland_local': 'hessen',
        'bundesland': 'berlin',
      });
      expect(r.getBundesland(), Bundesland.sachsen);
    });

    test('ungueltiger Name und Fremdtyp liefern null', () async {
      expect(
          (await repo(initial: {'bundesland_u1': 'atlantis'})).getBundesland(),
          isNull);
      expect(
          (await repo(initial: {'bundesland_u1': 5})).getBundesland(), isNull);
    });

    test('ausgeloggt: kein saveSettings', () async {
      final r = await repo(uid: 'local');
      await r.setBundesland(Bundesland.bayern);
      expect(r.getBundesland(), Bundesland.bayern);
      verifyNever(
          mockDs.saveSettings(any, any, profileId: anyNamed('profileId')));
    });

    test('API-Fehler: lokaler Wert bleibt, keine Exception', () async {
      when(mockDs.saveSettings(any, any, profileId: anyNamed('profileId')))
          .thenAnswer((_) async => throw Exception('boom'));
      final r = await repo();
      await r.setBundesland(Bundesland.bayern);
      await Future<void>.delayed(Duration.zero);
      expect(r.getBundesland(), Bundesland.bayern);
    });

    group('syncFromFirestore', () {
      void remote(Map<String, dynamic>? data) {
        when(mockDs.getSettings(any, profileId: anyNamed('profileId')))
            .thenAnswer((_) async => data);
      }

      test('remote gueltig -> schreibt neuen Key, true', () async {
        remote({'bundesland': 'sachsen'});
        final r = await repo();
        expect(await r.syncFromFirestore(), isTrue);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('bundesland_u1'), 'sachsen');
        expect(r.getBundesland(), Bundesland.sachsen);
      });

      test('gleicher Wert -> false', () async {
        remote({'bundesland': 'sachsen'});
        final r = await repo(initial: {'bundesland_u1': 'sachsen'});
        expect(await r.syncFromFirestore(), isFalse);
      });

      test('remote null + Legacy-Wert -> Upload und neuer Key', () async {
        remote({'weeklyTargetHours': 40});
        final r = await repo(initial: {'bundesland': 'bayern'});
        expect(await r.syncFromFirestore(), isFalse);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('bundesland_u1'), 'bayern');
        verify(mockDs.saveSettings('u1', {'bundesland': 'bayern'},
                profileId: null))
            .called(1);
      });

      test('remote leer + neuer Key vorhanden -> Key leer, kein Upload',
          () async {
        remote({'bundesland': ''});
        final r = await repo(initial: {'bundesland_u1': 'bayern'});
        expect(await r.syncFromFirestore(), isTrue);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('bundesland_u1'), '');
        expect(r.getBundesland(), isNull);
        verifyNever(
            mockDs.saveSettings(any, any, profileId: anyNamed('profileId')));
      });

      test('remote null + neuer Key vorhanden -> Key leer', () async {
        remote({'weeklyTargetHours': 40});
        final r = await repo(initial: {'bundesland_u1': 'bayern'});
        expect(await r.syncFromFirestore(), isTrue);
        expect(r.getBundesland(), isNull);
      });

      test('remote ungueltig -> ignoriert', () async {
        remote({'bundesland': 'atlantis'});
        final r = await repo(initial: {'bundesland_u1': 'bayern'});
        expect(await r.syncFromFirestore(), isFalse);
        expect(r.getBundesland(), Bundesland.bayern);
        remote({'bundesland': 7});
        expect(await r.syncFromFirestore(), isFalse);
        expect(r.getBundesland(), Bundesland.bayern);
        verifyNever(
            mockDs.saveSettings(any, any, profileId: anyNamed('profileId')));
      });

      test('Datasource-Fehler -> false', () async {
        when(mockDs.getSettings(any, profileId: anyNamed('profileId')))
            .thenAnswer((_) async => throw Exception('boom'));
        final r = await repo();
        expect(await r.syncFromFirestore(), isFalse);
      });

      test('ausgeloggt -> false, kein Aufruf', () async {
        final r = await repo(uid: 'local');
        expect(await r.syncFromFirestore(), isFalse);
        verifyNever(mockDs.getSettings(any, profileId: anyNamed('profileId')));
      });
    });
  });
}
