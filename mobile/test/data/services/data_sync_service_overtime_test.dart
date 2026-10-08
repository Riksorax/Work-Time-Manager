import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_work_time/data/repositories/local_overtime_repository_impl.dart';
import 'package:flutter_work_time/data/services/data_sync_service.dart';

import '../../support/fake_repositories.dart';

void main() {
  test(
      'syncOvertime schreibt den lokalen Saldo mit dem Default (keepLastUpdated: false, #406)',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final local = LocalOvertimeRepositoryImpl(prefs);
    await local.saveOvertime(const Duration(minutes: 90));
    await local.saveLastUpdateDate(DateTime(2026, 10, 2, 12));
    final firebase = FakeOvertimeRepository();

    final ok = await DataSyncService.syncOvertime(
        localRepository: local, firebaseRepository: firebase);

    expect(ok, isTrue);
    expect(firebase.savedOvertimes, [const Duration(minutes: 90)]);
    expect(firebase.savedKeepLastUpdated, [false]);
  });
}
