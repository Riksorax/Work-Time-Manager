import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import 'package:flutter_work_time/core/providers/clock_provider.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/providers/subscription_provider.dart';
import 'package:flutter_work_time/core/providers/today_provider.dart';
import 'package:flutter_work_time/core/utils/api_errors.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';
import 'package:flutter_work_time/presentation/state/yearly_comparison_state.dart';
import 'package:flutter_work_time/presentation/view_models/yearly_comparison_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/yearly_report_view_model.dart';

import '../../support/fake_repositories.dart';
import '../../support/reported_logs.dart';
import '../../support/yearly_comparison_fixture.dart';

class _SwitchableProfile extends ActiveWorkProfileIdNotifier {
  @override
  String? build() => null;

  void set(String? id) => state = id;
}

class _Flag extends Notifier<bool> {
  _Flag(this._initial);
  final bool _initial;
  @override
  bool build() => _initial;
  void set(bool v) => state = v;
}

final _premium = NotifierProvider<_Flag, bool>(() => _Flag(true));
final _signedIn = NotifierProvider<_Flag, bool>(() => _Flag(true));

const _user = UserEntity(id: 'u1', email: 'a@b.c');

void main() {
  // todayProvider registriert einen WidgetsBindingObserver.
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  late ProviderContainer container;
  late FakeYearlyComparisonApi api;
  late DateTime now;
  late List<Completer<Map<String, dynamic>>> pending;
  late bool hold;

  setUp(() {
    now = DateTime(2026, 11, 15, 10);
    pending = [];
    hold = false;
    api = FakeYearlyComparisonApi((c) {
      if (!hold) return Future.value(yearlyComparisonJsonFor(c));
      final completer = Completer<Map<String, dynamic>>();
      pending.add(completer);
      return completer.future;
    });
    container = ProviderContainer(overrides: [
      clockProvider.overrideWithValue(() => now),
      apiClientProvider.overrideWithValue(api),
      workRepositoryProvider.overrideWith((ref) {
        ref.watch(activeWorkProfileIdProvider);
        ref.watch(_signedIn);
        return FakeWorkRepository();
      }),
      settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
      activeWorkProfileIdProvider.overrideWith(_SwitchableProfile.new),
      isPremiumProvider.overrideWith((ref) => ref.watch(_premium)),
      authStateProvider.overrideWith(
          (ref) => Stream.value(ref.watch(_signedIn) ? _user : null)),
    ]);
  });

  tearDown(() => container.dispose());

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  YearlyComparisonState state() =>
      container.read(yearlyComparisonViewModelProvider);
  YearlyComparisonViewModel vm() =>
      container.read(yearlyComparisonViewModelProvider.notifier);

  /// Nur die Aufrufe der Karte (die Jahreswerte des Tabs fragen ohne
  /// Stichtag an und laufen hier nicht, solange `loadYear` nicht gerufen wird).
  Future<void> ready() async {
    container.listen(authStateProvider, (_, __) {});
    container.listen(yearlyComparisonViewModelProvider, (_, __) {});
    await settle();
  }

  /// Wählt im Jahres-Tab ein Jahr (wie die Pfeile), ohne die Aufrufe des Tabs
  /// mitzuzählen.
  Future<void> selectYear(int year) async {
    final before = api.calls.length;
    await container.read(yearlyReportViewModelProvider.notifier).loadYear(year);
    await settle();
    api.calls.removeRange(before, api.calls.length);
  }

  test('lädt nicht von selbst (erst, wenn die Karte sichtbar ist)', () async {
    await ready();
    expect(state().status, YearlyComparisonStatus.idle);
    expect(state().year, 2026);
    expect(api.calls, isEmpty);
  });

  test('laufendes Jahr: Stichtag = heute (lokaler Kalendertag)', () async {
    await ready();
    hold = true;
    vm().ensureLoaded();
    expect(state().status, YearlyComparisonStatus.loading);
    pending.single.complete(yearlyComparisonJson(2026, until: '11-15'));
    await settle();
    expect(state().status, YearlyComparisonStatus.data);
    expect(state().report!.until, '11-15');
    expect(api.calls.single.year, 2026);
    expect(api.calls.single.until, DateTime(2026, 11, 15));
    expect(api.calls.single.profileId, isNull);

    // Ein zweites ensureLoaded lädt nicht erneut.
    vm().ensureLoaded();
    await settle();
    expect(api.calls, hasLength(1));
  });

  test('abgeschlossenes Jahr: ohne Stichtag (ganzes Jahr)', () async {
    await ready();
    await selectYear(2024);
    expect(state().year, 2024);
    expect(state().status, YearlyComparisonStatus.idle);
    vm().ensureLoaded();
    await settle();
    expect(api.calls.single.year, 2024);
    expect(api.calls.single.until, isNull);
    expect(state().report!.current.year, 2024);
    expect(state().report!.previous.year, 2023);
  });

  test('Jahreswechsel im Tab: neu aufgebaut, alte Antwort verworfen', () async {
    await ready();
    hold = true;
    vm().ensureLoaded();
    await settle();
    hold = false;
    await selectYear(2025);
    vm().ensureLoaded();
    await settle();
    expect(state().year, 2025);
    expect(state().status, YearlyComparisonStatus.data);
    pending.single.complete(yearlyComparisonJson(2026, until: '11-15'));
    await settle();
    expect(state().report!.current.year, 2025);
  });

  test('Free: kein Laden, Zustand bleibt idle', () async {
    container.read(_premium.notifier).set(false);
    await ready();
    vm().ensureLoaded();
    await settle();
    expect(state().status, YearlyComparisonStatus.idle);
    expect(api.calls, isEmpty);
  });

  test('nicht angemeldet: kein Laden, Zustand bleibt idle', () async {
    container.read(_signedIn.notifier).set(false);
    await ready();
    vm().ensureLoaded();
    await settle();
    expect(state().status, YearlyComparisonStatus.idle);
    expect(api.calls, isEmpty);
  });

  test('Premium endet: neu gebaut, lädt nicht', () async {
    await ready();
    vm().ensureLoaded();
    await settle();
    expect(state().status, YearlyComparisonStatus.data);
    container.read(_premium.notifier).set(false);
    await settle();
    expect(state().status, YearlyComparisonStatus.idle);
    vm().ensureLoaded();
    await settle();
    expect(api.calls, hasLength(1));
  });

  test('Abmelden: neu gebaut, lädt nicht', () async {
    await ready();
    vm().ensureLoaded();
    await settle();
    container.read(_signedIn.notifier).set(false);
    await settle();
    expect(state().status, YearlyComparisonStatus.idle);
    vm().ensureLoaded();
    await settle();
    expect(api.calls, hasLength(1));
  });

  for (final year in [2000, 1999, 2101]) {
    test('Jahr $year: nur Hinweis, keine Anfrage', () async {
      await ready();
      await selectYear(year);
      vm().ensureLoaded();
      await settle();
      expect(state().status, YearlyComparisonStatus.unsupported);
      expect(api.calls, isEmpty);
    });
  }

  test('Grenzjahre 2001 und 2100 werden angefragt', () async {
    await ready();
    for (final year in [2001, 2100]) {
      await selectYear(year);
      vm().ensureLoaded();
      await settle();
      expect(state().status, YearlyComparisonStatus.data);
    }
    expect(api.calls.map((c) => c.year), [2001, 2100]);
  });

  test('Profilwechsel: verspätete Antwort des alten Profils wird verworfen',
      () async {
    await ready();
    hold = true;
    vm().ensureLoaded();
    (container.read(activeWorkProfileIdProvider.notifier) as _SwitchableProfile)
        .set('p2');
    await settle();
    expect(state().status, YearlyComparisonStatus.idle);
    vm().ensureLoaded();
    await settle();
    expect(api.calls.map((c) => c.profileId), [null, 'p2']);

    pending[1].complete(
        yearlyComparisonJson(2026, until: '11-15', currentEmpty: true));
    await settle();
    pending[0].complete(yearlyComparisonJson(2026, until: '11-15'));
    await settle();
    expect(state().status, YearlyComparisonStatus.data);
    expect(state().report!.current.hasData, isFalse);
  });

  test('Tageswechsel lädt mit dem neuen Stichtag neu', () async {
    await ready();
    vm().ensureLoaded();
    await settle();
    now = DateTime(2026, 11, 16, 0, 0, 5);
    container.read(todayProvider.notifier).refresh();
    await settle();
    expect(api.calls.map((c) => c.until),
        [DateTime(2026, 11, 15), DateTime(2026, 11, 16)]);
    expect(state().status, YearlyComparisonStatus.data);
  });

  test('Tageswechsel ins neue Jahr: gewähltes Jahr ist abgeschlossen',
      () async {
    now = DateTime(2026, 12, 31, 23, 59);
    await ready();
    vm().ensureLoaded();
    await settle();
    now = DateTime(2027, 1, 1, 0, 0, 5);
    container.read(todayProvider.notifier).refresh();
    await settle();
    expect(api.calls.map((c) => (c.year, c.until)),
        [(2026, DateTime(2026, 12, 31)), (2026, null)]);
  });

  test('Tageswechsel ohne sichtbare Karte lädt nicht', () async {
    await ready();
    now = DateTime(2026, 11, 16, 0, 0, 5);
    container.read(todayProvider.notifier).refresh();
    await settle();
    expect(api.calls, isEmpty);
    expect(state().status, YearlyComparisonStatus.idle);
  });

  group('Fehler', () {
    final events = <LogEvent>[];
    captureLogs(events);

    test('API-Fehler: Fehlerzustand, gemeldet; reload lädt erneut', () async {
      await ready();
      api.handler =
          (_) async => throw const ApiException('getYearlyComparison', 500);
      vm().ensureLoaded();
      await settle();
      expect(state().status, YearlyComparisonStatus.error);
      expect(state().report, isNull);
      expect(reported(events, 'YearlyComparisonViewModel').map((e) => e.level),
          [Level.error]);
      expect(reported(events, 'YearlyComparisonViewModel').single.message,
          contains('500'));

      api.handler = (c) async => yearlyComparisonJsonFor(c);
      await vm().reload();
      await settle();
      expect(state().status, YearlyComparisonStatus.data);
    });

    for (final e in transientNetworkErrors.entries) {
      test('erwartbarer Netzwerkfehler (${e.key}): Fehler, nicht gemeldet',
          () async {
        await ready();
        api.handler = (_) async => throw e.value;
        vm().ensureLoaded();
        await settle();
        expect(state().status, YearlyComparisonStatus.error);
        expect(reported(events, 'YearlyComparisonViewModel'), isEmpty);
      });
    }

    test('NotSignedInException: kein Fehlerzustand, nicht gemeldet', () async {
      await ready();
      api.handler = (_) async => throw const NotSignedInException('x');
      vm().ensureLoaded();
      await settle();
      expect(state().status, isNot(YearlyComparisonStatus.error));
      expect(reported(events, 'YearlyComparisonViewModel'), isEmpty);
    });
  });
}
