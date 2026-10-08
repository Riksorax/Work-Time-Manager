import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/clock_provider.dart';
import 'package:flutter_work_time/domain/entities/bundesland.dart';
import 'package:flutter_work_time/domain/entities/settings_entity.dart';
import 'package:flutter_work_time/domain/utils/german_holidays.dart';
import 'package:flutter_work_time/presentation/state/settings_state.dart';
import 'package:flutter_work_time/presentation/view_models/holiday_today_provider.dart';
import 'package:flutter_work_time/presentation/view_models/settings_view_model.dart';

import '../../support/fake_clock.dart';

class _FakeSettings extends SettingsViewModel {
  _FakeSettings(this.initial);
  final AsyncValue<SettingsState> initial;

  @override
  AsyncValue<SettingsState> build() => initial;

  void set(AsyncValue<SettingsState> value) => state = value;
}

AsyncValue<SettingsState> _data(Bundesland? land) =>
    AsyncValue.data(SettingsState(
      settings: SettingsEntity(bundesland: land),
      overtimeBalance: Duration.zero,
    ));

void main() {
  // todayProvider (#379) registriert einen WidgetsBindingObserver.
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  ProviderContainer make(
      AsyncValue<SettingsState> settings, DateTime Function() clock,
      {_FakeSettings? fake}) {
    final c = ProviderContainer(overrides: [
      settingsViewModelProvider
          .overrideWith(() => fake ?? _FakeSettings(settings)),
      clockProvider.overrideWithValue(clock),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('kein Bundesland -> null', () {
    final c = make(_data(null), () => DateTime(2026, 10, 3, 12));
    expect(c.read(holidayTodayProvider), isNull);
  });

  test('3.10. -> germanUnityDay, 2.10. 23:59 und 4.10. -> null', () {
    expect(
        make(_data(Bundesland.bayern), () => DateTime(2026, 10, 3, 12))
            .read(holidayTodayProvider),
        GermanHoliday.germanUnityDay);
    expect(
        make(_data(Bundesland.bayern), () => DateTime(2026, 10, 2, 23, 59))
            .read(holidayTodayProvider),
        isNull);
    expect(
        make(_data(Bundesland.bayern), () => DateTime(2026, 10, 4))
            .read(holidayTodayProvider),
        isNull);
  });

  test('Reformationstag nur in Laendern mit Reformationstag', () {
    final now = DateTime(2026, 10, 31, 8);
    expect(
        make(_data(Bundesland.sachsen), () => now).read(holidayTodayProvider),
        GermanHoliday.reformationDay);
    expect(make(_data(Bundesland.bayern), () => now).read(holidayTodayProvider),
        isNull);
  });

  test('Fronleichnam NRW ja, Berlin nein', () {
    final now = DateTime(2026, 6, 4, 9);
    expect(
        make(_data(Bundesland.nordrheinWestfalen), () => now)
            .read(holidayTodayProvider),
        GermanHoliday.corpusChristi);
    expect(make(_data(Bundesland.berlin), () => now).read(holidayTodayProvider),
        isNull);
  });

  test('Settings laden noch -> null', () {
    final c = make(const AsyncValue.loading(), () => DateTime(2026, 10, 3));
    expect(c.read(holidayTodayProvider), isNull);
  });

  test('Wechsel des Bundeslands aktualisiert den Wert', () {
    final fake = _FakeSettings(_data(Bundesland.bayern));
    final c = make(_data(null), () => DateTime(2026, 10, 31, 8), fake: fake);
    expect(c.read(holidayTodayProvider), isNull);
    fake.set(_data(Bundesland.sachsen));
    expect(c.read(holidayTodayProvider), GermanHoliday.reformationDay);
  });

  test('gecachter Wert zieht ueber Mitternacht nach (Tabwechsel ueber Nacht)',
      () {
    fakeAsync((async) {
      final clock = FakeClock(DateTime(2026, 10, 2, 23, 59, 30))..bind(async);
      final c = ProviderContainer(overrides: [
        settingsViewModelProvider
            .overrideWith(() => _FakeSettings(_data(Bundesland.bayern))),
        clockProvider.overrideWithValue(clock.call),
      ]);
      expect(c.read(holidayTodayProvider), isNull);
      // Kein Listener, Provider bleibt gecacht; nur die Zeit vergeht.
      async.elapse(const Duration(seconds: 31));
      async.flushMicrotasks();
      expect(c.read(holidayTodayProvider), GermanHoliday.germanUnityDay);
      c.dispose();
      expect(async.pendingTimers, isEmpty);
    });
  });
}
