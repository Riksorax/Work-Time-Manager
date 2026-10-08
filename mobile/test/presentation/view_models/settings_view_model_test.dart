import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_work_time/core/providers/clock_provider.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/providers/settings_sync_provider.dart';
import 'package:flutter_work_time/domain/entities/bundesland.dart';
import 'package:flutter_work_time/domain/repositories/overtime_repository.dart';
import 'package:flutter_work_time/domain/repositories/settings_repository.dart';
import 'package:flutter_work_time/presentation/state/leave_balance_state.dart';
import 'package:flutter_work_time/presentation/view_models/leave_balance_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/settings_view_model.dart';

import 'settings_view_model_test.mocks.dart';

class _CountingLeaveViewModel extends LeaveBalanceViewModel {
  static int builds = 0;
  @override
  LeaveBalanceState build() {
    builds++;
    return const LeaveBalanceState();
  }
}

@GenerateMocks([SettingsRepository, OvertimeRepository])
void main() {
  late MockSettingsRepository settings;
  late MockOvertimeRepository overtime;
  late ProviderContainer container;

  setUp(() {
    _CountingLeaveViewModel.builds = 0;
    settings = MockSettingsRepository();
    overtime = MockOvertimeRepository();
    when(overtime.ensureOvertimeLoaded())
        .thenAnswer((_) async => Duration.zero);
    when(overtime.ensureLastUpdateLoaded()).thenAnswer((_) async => null);
    when(settings.getTargetWeeklyHours()).thenReturn(40);
    when(settings.getWorkdays()).thenReturn([1, 2, 3, 4, 5]);
    when(settings.getNotificationsEnabled()).thenReturn(false);
    when(settings.getNotificationTime()).thenReturn('18:00');
    when(settings.getNotificationDays()).thenReturn([1, 2, 3, 4, 5]);
    when(settings.getNotifyWorkStart()).thenReturn(true);
    when(settings.getNotifyWorkEnd()).thenReturn(true);
    when(settings.getNotifyBreaks()).thenReturn(true);
    when(settings.getBundesland()).thenReturn(null);
    when(settings.getWarnOnOvertimeThreshold()).thenReturn(false);
    when(settings.getOvertimeThresholdHours()).thenReturn(10);
    when(settings.getWarnOnUndertimeThreshold()).thenReturn(false);
    when(settings.getUndertimeThresholdHours()).thenReturn(10);
    when(settings.getUse24HourFormat()).thenReturn(true);
    when(settings.getTimezoneOverride()).thenReturn(null);
    when(settings.getLocale()).thenReturn('de');
    when(settings.getVacationDaysPerYear()).thenReturn(28);
    when(settings.setVacationDaysPerYear(any)).thenAnswer((_) async {});
    when(settings.setBundesland(any)).thenAnswer((_) async {});

    container = ProviderContainer(overrides: [
      settingsRepositoryProvider.overrideWithValue(settings),
      overtimeRepositoryProvider.overrideWithValue(overtime),
      leaveBalanceViewModelProvider.overrideWith(_CountingLeaveViewModel.new),
    ]);
  });

  tearDown(() => container.dispose());

  Future<void> init() async {
    container.read(settingsViewModelProvider);
    await Future<void>.delayed(Duration.zero);
  }

  test('_init liest den Anspruch in die SettingsEntity', () async {
    await init();
    expect(
        container
            .read(settingsViewModelProvider)
            .value!
            .settings
            .vacationDaysPerYear,
        28);
  });

  test('updateVacationDaysPerYear speichert, aktualisiert State, invalidiert',
      () async {
    await init();
    container.listen(leaveBalanceViewModelProvider, (_, __) {});
    final before = _CountingLeaveViewModel.builds;

    await container
        .read(settingsViewModelProvider.notifier)
        .updateVacationDaysPerYear(25);

    verify(settings.setVacationDaysPerYear(25)).called(1);
    expect(
        container
            .read(settingsViewModelProvider)
            .value!
            .settings
            .vacationDaysPerYear,
        25);
    container.read(leaveBalanceViewModelProvider);
    expect(_CountingLeaveViewModel.builds, before + 1);
  });

  test('Bundesland-Wechsel behält Anspruch', () async {
    await init();
    final notifier = container.read(settingsViewModelProvider.notifier);
    await notifier.updateVacationDaysPerYear(25);
    await notifier.updateBundesland(Bundesland.values.first);
    expect(
        container
            .read(settingsViewModelProvider)
            .value!
            .settings
            .vacationDaysPerYear,
        25);
  });

  test('Wert ausserhalb 0-366 wird nicht gespeichert', () async {
    await init();
    final notifier = container.read(settingsViewModelProvider.notifier);
    await notifier.updateVacationDaysPerYear(367);
    await notifier.updateVacationDaysPerYear(-1);
    verifyNever(settings.setVacationDaysPerYear(any));
    expect(
        container
            .read(settingsViewModelProvider)
            .value!
            .settings
            .vacationDaysPerYear,
        28);
  });

  test('Sync-Tick laedt das Bundesland neu, ohne das Repo neu zu bauen',
      () async {
    var repoBuilds = 0;
    when(settings.getBundesland()).thenReturn(Bundesland.bayern);
    final c = ProviderContainer(overrides: [
      settingsRepositoryProvider.overrideWith((ref) {
        repoBuilds++;
        return settings;
      }),
      overtimeRepositoryProvider.overrideWithValue(overtime),
    ]);
    addTearDown(c.dispose);
    c.listen(settingsViewModelProvider, (_, __) {});
    await Future<void>.delayed(Duration.zero);
    expect(c.read(settingsViewModelProvider).value!.settings.bundesland,
        Bundesland.bayern);

    when(settings.getBundesland()).thenReturn(Bundesland.sachsen);
    c.read(settingsSyncTickProvider.notifier).bump();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(c.read(settingsViewModelProvider).value!.settings.bundesland,
        Bundesland.sachsen);
    expect(repoBuilds, 1);
  });

  test('Sync-Tick laedt still nach: State wird nie wieder loading', () async {
    when(settings.getBundesland()).thenReturn(Bundesland.bayern);
    final c = ProviderContainer(overrides: [
      settingsRepositoryProvider.overrideWithValue(settings),
      overtimeRepositoryProvider.overrideWithValue(overtime),
    ]);
    addTearDown(c.dispose);
    final states = <bool>[];
    c.listen(settingsViewModelProvider, (_, next) => states.add(next.isLoading),
        fireImmediately: true);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    states.clear();

    when(settings.getBundesland()).thenReturn(Bundesland.sachsen);
    c.read(settingsSyncTickProvider.notifier).bump();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    // Kein Spinner-Zwischenzustand: sonst verwirft der Settings-Screen
    // fluechtigen UI-State.
    expect(states, isNotEmpty);
    expect(states.every((loading) => !loading), isTrue);
    expect(c.read(settingsViewModelProvider).value!.settings.bundesland,
        Bundesland.sachsen);
  });

  test('clockProvider: Default liefert DateTime, Override greift', () {
    final now = container.read(clockProvider)();
    expect(now, isA<DateTime>());
    final c = ProviderContainer(overrides: [
      clockProvider.overrideWithValue(() => DateTime(2026, 10, 3, 12)),
    ]);
    addTearDown(c.dispose);
    expect(c.read(clockProvider)(), DateTime(2026, 10, 3, 12));
  });
}
