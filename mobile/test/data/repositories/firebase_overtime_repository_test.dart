import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_work_time/data/datasources/remote/firestore_datasource.dart';
import 'package:flutter_work_time/data/repositories/firebase_overtime_repository_impl.dart';

import 'firebase_overtime_repository_test.mocks.dart';

@GenerateMocks([FirestoreDataSource])
void main() {
  late MockFirestoreDataSource mockDataSource;
  late FirebaseOvertimeRepositoryImpl repository;
  const testUserId = 'test-user-123';

  setUp(() {
    mockDataSource = MockFirestoreDataSource();
    repository = FirebaseOvertimeRepositoryImpl(
      dataSource: mockDataSource,
      userId: testUserId,
    );
  });

  group('FirebaseOvertimeRepositoryImpl', () {
    group('saveOvertime', () {
      test('should save overtime to Firestore', () async {
        const overtime = Duration(hours: 5, minutes: 30);

        when(mockDataSource.saveOvertime(any, any)).thenAnswer((_) async {});

        await repository.saveOvertime(overtime);

        verify(mockDataSource.saveOvertime(testUserId, overtime)).called(1);
      });

      test('should update local cache after saving', () async {
        const overtime = Duration(hours: 3);

        when(mockDataSource.saveOvertime(any, any)).thenAnswer((_) async {});

        await repository.saveOvertime(overtime);

        // Nach dem Speichern sollte getOvertime den gecachten Wert zurückgeben
        final result = repository.getOvertime();
        expect(result, overtime);
      });

      test('reicht keepLastUpdated: true an die Datenquelle weiter (#406)',
          () async {
        const overtime = Duration(hours: 5, minutes: 30);
        when(mockDataSource.saveOvertime(any, any,
                profileId: anyNamed('profileId'),
                keepLastUpdated: anyNamed('keepLastUpdated')))
            .thenAnswer((_) async {});

        await repository.saveOvertime(overtime, keepLastUpdated: true);

        verify(mockDataSource.saveOvertime(testUserId, overtime,
                profileId: null, keepLastUpdated: true))
            .called(1);
        expect(repository.getOvertime(), overtime);
      });

      test('Default sendet keepLastUpdated: false (#406)', () async {
        const overtime = Duration(hours: 2);
        when(mockDataSource.saveOvertime(any, any,
                profileId: anyNamed('profileId'),
                keepLastUpdated: anyNamed('keepLastUpdated')))
            .thenAnswer((_) async {});

        await repository.saveOvertime(overtime);

        verify(mockDataSource.saveOvertime(testUserId, overtime,
                profileId: null, keepLastUpdated: false))
            .called(1);
        expect(repository.getOvertime(), overtime);
      });
    });

    group('Fehler beim Schreiben (#427)', () {
      test(
          'saveOvertime: Cache bleibt beim alten Wert, wenn der Write scheitert',
          () async {
        const alt = Duration(hours: 2);
        const neu = Duration(hours: 7);
        when(mockDataSource.saveOvertime(any, any,
                profileId: anyNamed('profileId'),
                keepLastUpdated: anyNamed('keepLastUpdated')))
            .thenAnswer((_) async {});
        await repository.saveOvertime(alt);

        when(mockDataSource.saveOvertime(any, any,
                profileId: anyNamed('profileId'),
                keepLastUpdated: anyNamed('keepLastUpdated')))
            .thenThrow(Exception('write failed'));

        await expectLater(repository.saveOvertime(neu), throwsException);

        expect(repository.getOvertime(), alt);
      });

      test('saveOvertime: Cache wird erst nach Abschluss des Writes gesetzt',
          () async {
        const alt = Duration(hours: 2);
        const neu = Duration(hours: 7);
        when(mockDataSource.saveOvertime(any, any,
                profileId: anyNamed('profileId'),
                keepLastUpdated: anyNamed('keepLastUpdated')))
            .thenAnswer((_) async {});
        await repository.saveOvertime(alt);

        final hold = Completer<void>();
        when(mockDataSource.saveOvertime(any, any,
                profileId: anyNamed('profileId'),
                keepLastUpdated: anyNamed('keepLastUpdated')))
            .thenAnswer((_) => hold.future);

        final pending = repository.saveOvertime(neu);
        expect(repository.getOvertime(), alt);

        hold.complete();
        await pending;
        expect(repository.getOvertime(), neu);
      });

      test('saveLastUpdateDate: Cache bleibt beim alten Wert bei Fehler',
          () async {
        final alt = DateTime.utc(2026, 1, 10);
        final neu = DateTime.utc(2026, 1, 11);
        when(mockDataSource.saveLastOvertimeUpdate(any, any,
                profileId: anyNamed('profileId')))
            .thenAnswer((_) async {});
        await repository.saveLastUpdateDate(alt);

        when(mockDataSource.saveLastOvertimeUpdate(any, any,
                profileId: anyNamed('profileId')))
            .thenThrow(Exception('write failed'));

        await expectLater(repository.saveLastUpdateDate(neu), throwsException);

        expect(repository.getLastUpdateDate(), alt);
      });
    });

    group('getOvertime', () {
      test('should return Duration.zero when cache is empty', () {
        // Vor dem ersten Laden sollte Duration.zero zurückgegeben werden
        final result = repository.getOvertime();
        expect(result, Duration.zero);
      });

      test('should return cached value after loadOvertimeAsync', () async {
        const expectedOvertime = Duration(hours: 10);

        when(mockDataSource.getOvertime(any))
            .thenAnswer((_) async => expectedOvertime);

        // Explizit laden
        final loadedOvertime = await repository.loadOvertimeAsync();
        expect(loadedOvertime, expectedOvertime);

        // Jetzt sollte getOvertime den gecachten Wert zurückgeben
        final cachedOvertime = repository.getOvertime();
        expect(cachedOvertime, expectedOvertime);

        verify(mockDataSource.getOvertime(testUserId)).called(1);
      });
    });

    group('saveLastUpdateDate', () {
      test('should save last update date to Firestore', () async {
        final testDate = DateTime(2026, 1, 29, 14, 30);

        when(mockDataSource.saveLastOvertimeUpdate(any, any))
            .thenAnswer((_) async {});

        await repository.saveLastUpdateDate(testDate);

        verify(mockDataSource.saveLastOvertimeUpdate(testUserId, testDate))
            .called(1);
      });

      test('should update local cache after saving', () async {
        final testDate = DateTime(2026, 1, 29);

        when(mockDataSource.saveLastOvertimeUpdate(any, any))
            .thenAnswer((_) async {});

        await repository.saveLastUpdateDate(testDate);

        final result = repository.getLastUpdateDate();
        expect(result, testDate);
      });
    });

    group('getLastUpdateDate', () {
      test('should return null when cache is empty', () {
        final result = repository.getLastUpdateDate();
        expect(result, isNull);
      });

      test('should return cached value after loadLastUpdateAsync', () async {
        final expectedDate = DateTime(2026, 1, 28, 10, 0);

        when(mockDataSource.getLastOvertimeUpdate(any))
            .thenAnswer((_) async => expectedDate);

        final loadedDate = await repository.loadLastUpdateAsync();
        expect(loadedDate, expectedDate);

        final cachedDate = repository.getLastUpdateDate();
        expect(cachedDate, expectedDate);

        verify(mockDataSource.getLastOvertimeUpdate(testUserId)).called(1);
      });

      test('should return null from Firestore when no date exists', () async {
        when(mockDataSource.getLastOvertimeUpdate(any))
            .thenAnswer((_) async => null);

        final loadedDate = await repository.loadLastUpdateAsync();
        expect(loadedDate, isNull);
      });
    });

    group('loadOvertimeAsync', () {
      test('should load overtime from Firestore and cache it', () async {
        const expectedOvertime = Duration(hours: 7, minutes: 45);

        when(mockDataSource.getOvertime(any))
            .thenAnswer((_) async => expectedOvertime);

        final result = await repository.loadOvertimeAsync();

        expect(result, expectedOvertime);
        verify(mockDataSource.getOvertime(testUserId)).called(1);
      });
    });
  });
}
