import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_work_time/data/datasources/remote/api_client.dart';
import 'package:flutter_work_time/data/datasources/remote/api_data_source.dart';
import 'package:flutter_work_time/data/datasources/remote/firestore_datasource.dart';
import 'package:flutter_work_time/data/models/work_entry_model.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';

import 'api_data_source_test.mocks.dart';

@GenerateMocks([FirestoreDataSource, ApiClient])
void main() {
  late MockFirestoreDataSource mockAuth;
  late MockApiClient mockApi;
  late ApiDataSource dataSource;

  const userId = 'uid1';

  setUp(() {
    mockAuth = MockFirestoreDataSource();
    mockApi = MockApiClient();
    dataSource = ApiDataSource(mockAuth, mockApi);
  });

  group(
      'ApiDataSource — Work Entries laufen für alle Profile über die API (siehe #292)',
      () {
    test('getWorkEntry: Standard-Profil (profileId null) geht an die API',
        () async {
      when(mockApi.getWorkEntry(2026, 9, 26, profileId: null))
          .thenAnswer((_) async => null);

      await dataSource.getWorkEntry(userId, DateTime(2026, 9, 26));

      verify(mockApi.getWorkEntry(2026, 9, 26, profileId: null)).called(1);
      verifyZeroInteractions(mockAuth);
    });

    test(
        'getWorkEntry: zusätzliches Profil geht ebenfalls an die API, nicht an Firestore',
        () async {
      when(mockApi.getWorkEntry(2026, 9, 26, profileId: 'p1'))
          .thenAnswer((_) async => null);

      await dataSource.getWorkEntry(userId, DateTime(2026, 9, 26),
          profileId: 'p1');

      verify(mockApi.getWorkEntry(2026, 9, 26, profileId: 'p1')).called(1);
      verifyNever(
          mockAuth.getWorkEntry(any, any, profileId: anyNamed('profileId')));
    });

    test('saveWorkEntry gibt profileId an die API weiter', () async {
      final entry = WorkEntryModel(
          id: '2026-9-26',
          date: DateTime(2026, 9, 26),
          type: WorkEntryType.work);
      when(mockApi.saveWorkEntry(entry, profileId: 'p1'))
          .thenAnswer((_) async {});

      await dataSource.saveWorkEntry(userId, entry, profileId: 'p1');

      verify(mockApi.saveWorkEntry(entry, profileId: 'p1')).called(1);
      verifyZeroInteractions(mockAuth);
    });

    test('getWorkEntriesForMonth gibt profileId an die API weiter', () async {
      when(mockApi.getWorkEntriesForMonth(2026, 9, profileId: 'p1'))
          .thenAnswer((_) async => []);

      await dataSource.getWorkEntriesForMonth(userId, 2026, 9, profileId: 'p1');

      verify(mockApi.getWorkEntriesForMonth(2026, 9, profileId: 'p1'))
          .called(1);
      verifyZeroInteractions(mockAuth);
    });

    test('deleteWorkEntry zerlegt die ID und gibt profileId an die API weiter',
        () async {
      when(mockApi.deleteWorkEntry(2026, 9, 26, profileId: 'p1'))
          .thenAnswer((_) async {});

      await dataSource.deleteWorkEntry(userId, '2026-9-26', profileId: 'p1');

      verify(mockApi.deleteWorkEntry(2026, 9, 26, profileId: 'p1')).called(1);
      verifyZeroInteractions(mockAuth);
    });
  });

  group(
      'ApiDataSource — Overtime laufen für alle Profile über die API (siehe #292)',
      () {
    test('getOvertime gibt profileId an die API weiter', () async {
      when(mockApi.getOvertime(profileId: 'p1'))
          .thenAnswer((_) async => (minutes: 30, lastUpdated: null));

      final result = await dataSource.getOvertime(userId, profileId: 'p1');

      expect(result, const Duration(minutes: 30));
      verify(mockApi.getOvertime(profileId: 'p1')).called(1);
      verifyZeroInteractions(mockAuth);
    });

    test('saveOvertime gibt profileId an die API weiter', () async {
      when(mockApi.saveOvertime(any, profileId: 'p1')).thenAnswer((_) async {});

      await dataSource.saveOvertime(userId, const Duration(minutes: 45),
          profileId: 'p1');

      verify(mockApi.saveOvertime(45, profileId: 'p1')).called(1);
      verifyZeroInteractions(mockAuth);
    });
  });

  group(
      'ApiDataSource — Settings laufen für alle Profile über die API (siehe #292)',
      () {
    test('getSettings gibt profileId an die API weiter', () async {
      when(mockApi.getSettings(profileId: 'p1'))
          .thenAnswer((_) async => {'weeklyTargetHours': 40});

      await dataSource.getSettings(userId, profileId: 'p1');

      verify(mockApi.getSettings(profileId: 'p1')).called(1);
      verifyZeroInteractions(mockAuth);
    });

    test(
        'saveSettings liest und schreibt mit derselben profileId (Read-Modify-Write)',
        () async {
      when(mockApi.getSettings(profileId: 'p1'))
          .thenAnswer((_) async => {'weeklyTargetHours': 40});
      when(mockApi.putSettings(any, profileId: 'p1')).thenAnswer((_) async {});

      await dataSource.saveSettings(
          userId,
          {
            'workdays': [1, 2, 3, 4, 5]
          },
          profileId: 'p1');

      final captured = verify(mockApi.putSettings(captureAny, profileId: 'p1'))
          .captured
          .single as Map;
      expect(captured, {
        'weeklyTargetHours': 40,
        'workdays': [1, 2, 3, 4, 5]
      });
      verifyZeroInteractions(mockAuth);
    });

    test('saveSettings reicht vacationDaysPerYear durch und erhält es (#278)',
        () async {
      when(mockApi.getSettings(profileId: 'p1')).thenAnswer(
          (_) async => {'weeklyTargetHours': 40, 'vacationDaysPerYear': 28});
      when(mockApi.putSettings(any, profileId: 'p1')).thenAnswer((_) async {});

      await dataSource.saveSettings(userId, {'weeklyTargetHours': 35},
          profileId: 'p1');
      await dataSource.saveSettings(userId, {'vacationDaysPerYear': 25},
          profileId: 'p1');

      final captured = verify(mockApi.putSettings(captureAny, profileId: 'p1'))
          .captured
          .cast<Map>();
      expect(captured[0], {'weeklyTargetHours': 35, 'vacationDaysPerYear': 28});
      expect(captured[1], {'weeklyTargetHours': 40, 'vacationDaysPerYear': 25});
    });
  });

  group(
      'ApiDataSource — Weekly Reflection und Arbeitszeit-Profile bleiben bei Firestore',
      () {
    test(
        'getWeeklyReflection delegiert weiterhin an Firestore (kein Backend-Endpoint, #137)',
        () async {
      when(mockAuth.getWeeklyReflection(userId, 2026, 39))
          .thenAnswer((_) async => null);

      await dataSource.getWeeklyReflection(userId, 2026, 39);

      verify(mockAuth.getWeeklyReflection(userId, 2026, 39)).called(1);
      verifyZeroInteractions(mockApi);
    });

    test(
        'getWorkProfiles delegiert weiterhin an Firestore (kein Backend-Endpoint, #138)',
        () async {
      when(mockAuth.getWorkProfiles(userId)).thenAnswer((_) async => []);

      await dataSource.getWorkProfiles(userId);

      verify(mockAuth.getWorkProfiles(userId)).called(1);
      verifyZeroInteractions(mockApi);
    });
  });

  test('reauthenticate delegiert an das Auth-DataSource', () async {
    when(mockAuth.reauthenticate()).thenAnswer((_) async => true);
    expect(await dataSource.reauthenticate(), isTrue);
    verify(mockAuth.reauthenticate()).called(1);
  });
}
