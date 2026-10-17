import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/data/datasources/remote/firestore_datasource.dart';
import 'package:flutter_work_time/data/models/work_entry_model.dart';
import 'package:flutter_work_time/data/repositories/local_work_repository_impl.dart';
import 'package:flutter_work_time/data/repositories/work_repository_impl.dart';
import 'package:flutter_work_time/data/services/data_sync_service.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_repositories.dart';

class _CapturingDataSource extends Fake implements FirestoreDataSource {
  final List<WorkEntryModel> saved = [];
  final List<String?> profiles = [];

  @override
  Future<void> saveWorkEntry(String userId, WorkEntryModel model,
      {String? profileId}) async {
    saved.add(model);
    profiles.add(profileId);
  }
}

void main() {
  test('Home-Office-Flag ueberlebt die lokal-zu-Cloud-Migration', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final local = LocalWorkRepositoryImpl(prefs);
    await local.saveWorkEntry(WorkEntryEntity(
        id: '2026-06-05',
        date: DateTime(2026, 6, 5),
        workStart: DateTime(2026, 6, 5, 8),
        isHomeOffice: true));
    final cloud = FakeWorkRepository();

    final count = await DataSyncService.syncWorkEntries(
        localRepository: local, firebaseRepository: cloud);

    expect(count, 1);
    expect(cloud.saved.single.isHomeOffice, isTrue);
  });

  test('WorkRepositoryImpl reicht das Flag samt Profil an die Datasource',
      () async {
    final ds = _CapturingDataSource();
    final repo =
        WorkRepositoryImpl(dataSource: ds, userId: 'u', profileId: 'p1');

    await repo.saveWorkEntry(WorkEntryEntity(
        id: '2026-06-05', date: DateTime(2026, 6, 5), isHomeOffice: true));

    expect(ds.saved.single.isHomeOffice, isTrue);
    expect(ds.profiles.single, 'p1');
  });
}
