import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/data/repositories/hybrid_overtime_repository_impl.dart';

import '../../support/fake_repositories.dart';

void main() {
  late FakeOvertimeRepository firebase;
  late FakeOvertimeRepository local;

  setUp(() {
    firebase = FakeOvertimeRepository();
    local = FakeOvertimeRepository();
  });

  HybridOvertimeRepositoryImpl build(String? userId) =>
      HybridOvertimeRepositoryImpl(
        firebaseRepository: firebase,
        localRepository: local,
        userId: userId,
      );

  group('HybridOvertimeRepositoryImpl.saveOvertime (#406)', () {
    test('eingeloggt: Firebase bekommt keepLastUpdated, Local nichts',
        () async {
      await build('u1')
          .saveOvertime(const Duration(minutes: 30), keepLastUpdated: true);

      expect(firebase.savedOvertimes, [const Duration(minutes: 30)]);
      expect(firebase.savedKeepLastUpdated, [true]);
      expect(local.savedOvertimes, isEmpty);
    });

    test('eingeloggt: Default reicht false durch', () async {
      await build('u1').saveOvertime(const Duration(minutes: 30));

      expect(firebase.savedKeepLastUpdated, [false]);
      expect(local.savedOvertimes, isEmpty);
    });

    test('ausgeloggt: Local bekommt den Aufruf, Firebase nichts', () async {
      await build(null)
          .saveOvertime(const Duration(minutes: 30), keepLastUpdated: true);

      expect(local.savedOvertimes, [const Duration(minutes: 30)]);
      expect(local.savedKeepLastUpdated, [true]);
      expect(firebase.savedOvertimes, isEmpty);
    });
  });
}
