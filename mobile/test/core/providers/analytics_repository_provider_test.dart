import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';
import 'package:flutter_work_time/domain/repositories/settings_repository.dart';

import '../../support/analytics_fixture.dart';
import '../../support/fake_repositories.dart';

class _Settings extends Fake implements SettingsRepository {
  @override
  double getTargetWeeklyHours() => 40;

  @override
  List<int> getWorkdays() => const [1, 2, 3, 4, 5];
}

/// `analyticsRepositoryProvider` (#537): Umschaltung nach Auth-Status und
/// Bindung an das aktive Profil.
void main() {
  late FakeAnalyticsApi api;
  late FakeWorkRepository work;

  setUp(() {
    api = FakeAnalyticsApi();
    work = FakeWorkRepository();
  });

  ProviderContainer make(UserEntity? user) {
    final c = ProviderContainer(overrides: [
      authStateProvider.overrideWithValue(AsyncValue.data(user)),
      apiClientProvider.overrideWithValue(api),
      workRepositoryProvider.overrideWithValue(work),
      settingsRepositoryProvider.overrideWithValue(_Settings()),
      activeWorkProfileIdProvider.overrideWith(TestProfile.new),
      deviceTimeZoneProvider.overrideWithValue(const FixedTimeZone()),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('angemeldet: Backend, Profil des aktiven Profils', () async {
    final c = make(const UserEntity(id: 'u', email: 'a@b.c'));
    final repo = c.read(analyticsRepositoryProvider);
    expect(repo.usesBackend, isTrue);
    await repo.homeOfficeYear(2026);
    expect(api.homeOfficeCalls.single.profileId, isNull);
    expect(work.monthReads, isEmpty);

    (c.read(activeWorkProfileIdProvider.notifier) as TestProfile).select('p2');
    final switched = c.read(analyticsRepositoryProvider);
    expect(identical(switched, repo), isFalse);
    await switched.homeOfficeMonth(2026, 6);
    expect(api.homeOfficeCalls.last, (year: 2026, profileId: 'p2'));
  });

  test('Gast: lokal, kein API-Aufruf', () async {
    final c = make(null);
    final repo = c.read(analyticsRepositoryProvider);
    expect(repo.usesBackend, isFalse);
    await repo.homeOfficeYear(2026);
    expect(work.monthReads, hasLength(12));
    await repo.homeOfficeMonth(2026, 6);
    expect(work.monthReads.last, '2026-06');
    expect(work.monthReads, hasLength(13));
    await repo.insights(DateTime(2026, 1, 10));
    expect(work.monthReads.skip(13), ['2026-01', '2025-12', '2025-11']);
    expect(api.homeOfficeCalls, isEmpty);
    expect(api.insightsCalls, isEmpty);
  });
}
