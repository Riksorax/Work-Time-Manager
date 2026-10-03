import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/data/datasources/remote/firestore_datasource.dart';
import 'package:flutter_work_time/data/repositories/auth_repository_impl.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'auth_repository_impl_test.mocks.dart';

@GenerateMocks([FirestoreDataSource])
void main() {
  test('reauthenticate delegiert an die DataSource', () async {
    final ds = MockFirestoreDataSource();
    final repo = AuthRepositoryImpl(ds);
    when(ds.reauthenticate()).thenAnswer((_) async => true);
    expect(await repo.reauthenticate(), isTrue);
    when(ds.reauthenticate()).thenAnswer((_) async => false);
    expect(await repo.reauthenticate(), isFalse);
  });
}
