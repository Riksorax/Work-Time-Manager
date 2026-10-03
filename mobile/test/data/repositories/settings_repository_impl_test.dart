import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_work_time/data/datasources/remote/firestore_datasource.dart';
import 'package:flutter_work_time/data/repositories/settings_repository_impl.dart';

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
}
