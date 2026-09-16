import 'package:flutter_work_time/data/datasources/remote/firestore_datasource.dart';
import 'package:flutter_work_time/domain/entities/work_profile_entity.dart';
import 'package:flutter_work_time/domain/repositories/work_profile_repository.dart';

/// Verwaltet zusätzliche Arbeitszeit-Profile über Firestore (siehe #138).
/// Wird nur für eingeloggte Nutzer instanziiert.
class WorkProfileRepositoryImpl implements WorkProfileRepository {
  final FirestoreDataSource _dataSource;
  final String _userId;

  WorkProfileRepositoryImpl({
    required FirestoreDataSource dataSource,
    required String userId,
  })  : _dataSource = dataSource,
        _userId = userId;

  @override
  Future<List<WorkProfileEntity>> getAdditionalProfiles() async {
    final docs = await _dataSource.getWorkProfiles(_userId);
    return docs
        .map((doc) => WorkProfileEntity(
              id: doc['id'] as String,
              name: doc['name'] as String? ?? 'Profil',
            ))
        .toList();
  }

  @override
  Future<WorkProfileEntity> addProfile(String name) async {
    final id = await _dataSource.addWorkProfile(_userId, name);
    return WorkProfileEntity(id: id, name: name);
  }

  @override
  Future<void> deleteProfile(String profileId) {
    return _dataSource.deleteWorkProfile(_userId, profileId);
  }
}
