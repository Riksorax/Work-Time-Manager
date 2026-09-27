import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/data/datasources/remote/firestore_datasource.dart';
import 'package:flutter_work_time/data/repositories/hybrid_overtime_repository_impl.dart';
import 'package:flutter_work_time/data/repositories/hybrid_work_repository_impl.dart';
import 'package:flutter_work_time/data/repositories/local_overtime_repository_impl.dart';
import 'package:flutter_work_time/data/repositories/local_work_repository_impl.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/repositories/overtime_repository.dart';
import 'package:flutter_work_time/domain/repositories/work_repository.dart';
import 'package:flutter_work_time/presentation/view_models/data_sync_view_model.dart';

import 'data_sync_view_model_test.mocks.dart';

class _FakeFirebaseAuth extends Fake implements FirebaseAuth {
  _FakeFirebaseAuth(this._uid);
  final String? _uid;

  @override
  User? get currentUser {
    final uid = _uid;
    return uid == null ? null : _FakeUser(uid);
  }
}

class _FakeUser extends Fake implements User {
  _FakeUser(this.uid);
  @override
  final String uid;
}

@GenerateMocks([WorkRepository, FirestoreDataSource])
void main() {
  setUp(() {
    // LocalWorkRepositoryImpl/LocalOvertimeRepositoryImpl brauchen eine
    // echte SharedPreferences-Instanz (kein Mock nötig, siehe
    // local_overtime_repository_test.dart für dasselbe Muster).
    SharedPreferences.setMockInitialValues({});
  });

  group('DataSyncViewModel — Sync nicht möglich', () {
    // `overtimeRepositoryProvider` wird von `syncAll()` immer gelesen (auch
    // wenn der Work-Repository-Check bereits fehlschlägt) - muss deshalb in
    // jedem Fall überschrieben werden, sonst würde der echte,
    // Firebase-abhängige Provider laufen.
    test('wirft SyncNotAvailableException, wenn kein Nutzer eingeloggt ist',
        () async {
      final container = ProviderContainer(
        overrides: [
          firebaseAuthProvider.overrideWithValue(_FakeFirebaseAuth(null)),
          workRepositoryProvider
              .overrideWithValue(MockWorkRepository()), // keine Hybrid-Instanz
          overtimeRepositoryProvider
              .overrideWithValue(_FakeOvertimeRepository()),
        ],
      );
      addTearDown(container.dispose);

      final viewModel = container.read(dataSyncViewModelProvider);
      expect(
          () => viewModel.syncAll(), throwsA(isA<SyncNotAvailableException>()));
    });

    test(
        'wirft SyncNotAvailableException, wenn die Repositories nicht Hybrid sind',
        () async {
      final container = ProviderContainer(
        overrides: [
          firebaseAuthProvider.overrideWithValue(_FakeFirebaseAuth('uid1')),
          workRepositoryProvider.overrideWithValue(MockWorkRepository()),
          overtimeRepositoryProvider
              .overrideWithValue(_FakeOvertimeRepository()),
        ],
      );
      addTearDown(container.dispose);

      final viewModel = container.read(dataSyncViewModelProvider);
      expect(
          () => viewModel.syncAll(), throwsA(isA<SyncNotAvailableException>()));
    });
  });

  group('DataSyncViewModel — erfolgreicher Sync', () {
    test(
        'synchronisiert lokale Arbeitseinträge und übernimmt die Firestore-Überstunden',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final localWork = LocalWorkRepositoryImpl(prefs);
      final localOvertime = LocalOvertimeRepositoryImpl(prefs);

      // Einen lokalen Eintrag anlegen, der synchronisiert werden soll.
      await localWork.saveWorkEntry(WorkEntryEntity(
        id: '2026-9-1',
        date: DateTime(2026, 9, 1),
        workStart: DateTime(2026, 9, 1, 8, 0),
        workEnd: DateTime(2026, 9, 1, 16, 0),
      ));
      await localOvertime.saveOvertime(const Duration(minutes: 30));
      await localOvertime.saveLastUpdateDate(DateTime(2026, 9, 1));

      final mockFirebaseWork = MockWorkRepository();
      when(mockFirebaseWork.saveWorkEntry(any)).thenAnswer((_) async {});

      final mockFirestoreDataSource = MockFirestoreDataSource();
      // Firestore ist leer -> lokale Überstunden gewinnen (siehe DataSyncService).
      when(mockFirestoreDataSource.getOvertime('uid1',
              profileId: anyNamed('profileId')))
          .thenAnswer((_) async => Duration.zero);
      when(mockFirestoreDataSource.getLastOvertimeUpdate('uid1',
              profileId: anyNamed('profileId')))
          .thenAnswer((_) async => null);
      when(mockFirestoreDataSource.saveOvertime(any, any,
              profileId: anyNamed('profileId')))
          .thenAnswer((_) async {});
      when(mockFirestoreDataSource.saveLastOvertimeUpdate(any, any,
              profileId: anyNamed('profileId')))
          .thenAnswer((_) async {});

      final container = ProviderContainer(
        overrides: [
          firebaseAuthProvider.overrideWithValue(_FakeFirebaseAuth('uid1')),
          firestoreDataSourceProvider
              .overrideWithValue(mockFirestoreDataSource),
          workRepositoryProvider.overrideWithValue(HybridWorkRepositoryImpl(
            firebaseRepository: mockFirebaseWork,
            localRepository: localWork,
            userId: 'uid1',
          )),
          overtimeRepositoryProvider
              .overrideWithValue(HybridOvertimeRepositoryImpl(
            // Wird von DataSyncViewModel nicht gelesen (nur .localRepository) -
            // DataSyncViewModel baut sein eigenes frisches Firebase-Repository.
            firebaseRepository: _FakeOvertimeRepository(),
            localRepository: localOvertime,
            userId: 'uid1',
          )),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(dataSyncViewModelProvider).syncAll();

      expect(result.workEntriesSynced, 1);
      expect(result.overtimeSynced, isTrue);
      expect(result.errors, isEmpty);
      verify(mockFirebaseWork.saveWorkEntry(any)).called(1);
      verify(mockFirestoreDataSource.saveOvertime(
              'uid1', const Duration(minutes: 30),
              profileId: anyNamed('profileId')))
          .called(1);
    });
  });
}

/// Nie aufgerufen (siehe Kommentare oben) - ein `Fake` ohne Stubs würde bei
/// jedem Aufruf mit `UnimplementedError` fehlschlagen, was genau die
/// gewünschte Absicherung ist, falls sich das doch einmal ändert.
class _FakeOvertimeRepository extends Fake implements OvertimeRepository {}
