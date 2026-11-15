import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import 'package:flutter_work_time/core/providers/clock_provider.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/providers/subscription_provider.dart';
import 'package:flutter_work_time/core/providers/today_provider.dart';
import 'package:flutter_work_time/core/utils/api_errors.dart';
import 'package:flutter_work_time/domain/entities/trend_report.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';
import 'package:flutter_work_time/presentation/state/trend_state.dart';
import 'package:flutter_work_time/presentation/view_models/trend_view_model.dart';

import '../../support/reported_logs.dart';
import '../../support/trend_fixture.dart';

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
  late FakeTrendApi api;
  late DateTime now;

  /// Offene Antworten je Aufruf (Index wie `api.calls`).
  late List<Completer<Map<String, dynamic>>> pending;
  late bool hold;

  setUp(() {
    now = DateTime(2026, 11, 12, 10);
    pending = [];
    hold = false;
    api = FakeTrendApi((c) {
      if (!hold) {
        return Future.value(trendJson(c.date, c.granularity.apiValue));
      }
      final completer = Completer<Map<String, dynamic>>();
      pending.add(completer);
      return completer.future;
    });
    container = ProviderContainer(overrides: [
      clockProvider.overrideWithValue(() => now),
      apiClientProvider.overrideWithValue(api),
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

  TrendState state() => container.read(trendViewModelProvider);
  TrendViewModel vm() => container.read(trendViewModelProvider.notifier);

  /// Auth-Stream ist asynchron: erst den Wert abwarten.
  Future<void> ready() async {
    container.listen(authStateProvider, (_, __) {});
    container.listen(trendViewModelProvider, (_, __) {});
    await settle();
  }

  test('lädt nicht von selbst (erst, wenn die Ansicht sichtbar ist)', () async {
    await ready();
    expect(state().status, TrendStatus.idle);
    expect(state().granularity, TrendGranularity.week);
    expect(api.calls, isEmpty);
  });

  test('ensureLoaded: Laden → Daten, Bezugstag = heute, 12 Wochen', () async {
    await ready();
    hold = true;
    vm().ensureLoaded();
    expect(state().status, TrendStatus.loading);
    pending.single.complete(trendJson(DateTime(2026, 11, 12), 'week'));
    await settle();
    expect(state().status, TrendStatus.data);
    expect(state().report!.buckets, hasLength(12));
    expect(api.calls.single.date, DateTime(2026, 11, 12));
    expect(api.calls.single.granularity, TrendGranularity.week);
    expect(api.calls.single.profileId, isNull);

    // Ein zweites ensureLoaded lädt nicht erneut.
    vm().ensureLoaded();
    await settle();
    expect(api.calls, hasLength(1));
  });

  test('Free: kein Laden, Zustand bleibt idle', () async {
    container.read(_premium.notifier).set(false);
    await ready();
    vm().ensureLoaded();
    await settle();
    expect(state().status, TrendStatus.idle);
    expect(api.calls, isEmpty);
  });

  test('nicht angemeldet: kein Laden, Zustand bleibt idle', () async {
    container.read(_signedIn.notifier).set(false);
    await ready();
    vm().ensureLoaded();
    await settle();
    expect(state().status, TrendStatus.idle);
    expect(api.calls, isEmpty);
  });

  test('Premium endet: ViewModel wird neu gebaut und lädt nicht', () async {
    await ready();
    vm().ensureLoaded();
    await settle();
    expect(state().status, TrendStatus.data);
    container.read(_premium.notifier).set(false);
    await settle();
    expect(state().status, TrendStatus.idle);
    vm().ensureLoaded();
    await settle();
    expect(api.calls, hasLength(1));
  });

  test('Umschalten auf 12 Monate lädt neu, die Wahl bleibt über Rebuilds',
      () async {
    await ready();
    vm().ensureLoaded();
    await settle();
    await vm().setGranularity(TrendGranularity.month);
    await settle();
    expect(state().granularity, TrendGranularity.month);
    expect(state().status, TrendStatus.data);
    expect(state().report!.granularity, TrendGranularity.month);
    expect(api.calls.last.granularity, TrendGranularity.month);

    // Profilwechsel baut neu: Wahl bleibt, die sichtbare Ansicht lädt neu.
    (container.read(activeWorkProfileIdProvider.notifier) as _SwitchableProfile)
        .set('p2');
    await settle();
    expect(state().status, TrendStatus.idle);
    expect(state().granularity, TrendGranularity.month);
    vm().ensureLoaded();
    await settle();
    expect(api.calls.last.granularity, TrendGranularity.month);
    expect(api.calls.last.profileId, 'p2');
  });

  test('gleiche Granularität erneut gewählt: kein Laden', () async {
    await ready();
    vm().ensureLoaded();
    await settle();
    await vm().setGranularity(TrendGranularity.week);
    expect(api.calls, hasLength(1));
  });

  test('Profilwechsel: verspätete Antwort des alten Profils wird verworfen',
      () async {
    await ready();
    hold = true;
    vm().ensureLoaded();
    (container.read(activeWorkProfileIdProvider.notifier) as _SwitchableProfile)
        .set('p2');
    await settle();
    vm().ensureLoaded();
    await settle();
    expect(api.calls.map((c) => c.profileId), [null, 'p2']);

    // Erst die neue, dann die alte Antwort: die alte darf nichts überschreiben.
    pending[1].complete(trendJson(DateTime(2026, 11, 12), 'week', gaps: {0}));
    await settle();
    pending[0].complete(trendJson(DateTime(2026, 11, 12), 'week'));
    await settle();
    expect(state().status, TrendStatus.data);
    expect(state().report!.buckets.first.hasData, isFalse);
  });

  test('Umschalten während des Ladens: alte Antwort wird verworfen', () async {
    await ready();
    hold = true;
    vm().ensureLoaded();
    unawaited(vm().setGranularity(TrendGranularity.month));
    await settle();
    pending[1].complete(trendJson(DateTime(2026, 11, 12), 'month'));
    await settle();
    pending[0].complete(trendJson(DateTime(2026, 11, 12), 'week'));
    await settle();
    expect(state().report!.granularity, TrendGranularity.month);
    expect(state().granularity, TrendGranularity.month);
  });

  test('Tageswechsel lädt mit dem neuen Bezugstag neu', () async {
    await ready();
    vm().ensureLoaded();
    await settle();
    now = DateTime(2026, 11, 13, 0, 0, 5);
    container.read(todayProvider.notifier).refresh();
    await settle();
    expect(api.calls, hasLength(2));
    expect(api.calls.last.date, DateTime(2026, 11, 13));
    expect(state().status, TrendStatus.data);
  });

  test('Tageswechsel ohne sichtbare Ansicht lädt nicht', () async {
    await ready();
    now = DateTime(2026, 11, 13, 0, 0, 5);
    container.read(todayProvider.notifier).refresh();
    await settle();
    expect(api.calls, isEmpty);
    expect(state().status, TrendStatus.idle);
  });

  group('Fehler', () {
    final events = <LogEvent>[];
    captureLogs(events);

    test('API-Fehler: Fehlerzustand, gemeldet; reload lädt erneut', () async {
      await ready();
      api.handler =
          (_) async => throw const ApiException('getTrendReport', 500);
      vm().ensureLoaded();
      await settle();
      expect(state().status, TrendStatus.error);
      expect(state().report, isNull);
      expect(reported(events, 'TrendViewModel').map((e) => e.level),
          [Level.error]);
      expect(reported(events, 'TrendViewModel').single.message.toString(),
          contains('500'));

      api.handler = (c) async => trendJson(c.date, c.granularity.apiValue);
      await vm().reload();
      await settle();
      expect(state().status, TrendStatus.data);
    });

    for (final e in transientNetworkErrors.entries) {
      test(
          'erwartbarer Netzwerkfehler (${e.key}): Fehlerzustand, nicht gemeldet',
          () async {
        await ready();
        api.handler = (_) async => throw e.value;
        vm().ensureLoaded();
        await settle();
        expect(state().status, TrendStatus.error);
        expect(reported(events, 'TrendViewModel'), isEmpty);
      });
    }

    test('NotSignedInException: kein Fehlerzustand, nicht gemeldet', () async {
      await ready();
      api.handler = (_) async => throw const NotSignedInException('x');
      vm().ensureLoaded();
      await settle();
      expect(state().status, isNot(TrendStatus.error));
      expect(reported(events, 'TrendViewModel'), isEmpty);
    });
  });
}
