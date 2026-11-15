import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import 'package:flutter_work_time/core/providers/clock_provider.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/providers/subscription_provider.dart';
import 'package:flutter_work_time/core/utils/api_errors.dart';
import 'package:flutter_work_time/domain/entities/trend_report.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';
import 'package:flutter_work_time/presentation/view_models/assistant_weekly_trend_provider.dart';

import '../../support/reported_logs.dart';
import '../../support/trend_fixture.dart';

class _Profile extends ActiveWorkProfileIdNotifier {
  _Profile(this.id);
  final String? id;

  @override
  String? build() => id;
}

const _user = UserEntity(id: 'u1', email: 'a@b.c');

/// Sprachabfrage „Wochen-Trend“ (#287, Teil B): Quelle und Gate. Fester
/// Bezugstag (Do 12.11.2026), nichts hängt vom heutigen Datum ab.
void main() {
  // todayProvider registriert einen WidgetsBindingObserver.
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  late FakeTrendApi api;

  setUp(() {
    api = FakeTrendApi((c) async => trendJson(c.date, c.granularity.apiValue));
  });

  ProviderContainer make({
    bool signedIn = true,
    bool premium = true,
    String? profileId,
  }) {
    final container = ProviderContainer(overrides: [
      clockProvider.overrideWithValue(() => DateTime(2026, 11, 12, 10)),
      apiClientProvider.overrideWithValue(api),
      activeWorkProfileIdProvider.overrideWith(() => _Profile(profileId)),
      isPremiumProvider.overrideWithValue(premium),
      authStateProvider.overrideWithValue(
          AsyncValue<UserEntity?>.data(signedIn ? _user : null)),
    ]);
    addTearDown(container.dispose);
    container.listen(assistantWeeklyTrendProvider, (_, __) {});
    return container;
  }

  Future<AsyncValue<WeeklyTrend?>> load(ProviderContainer c) async {
    try {
      await c.read(assistantWeeklyTrendProvider.future);
    } catch (_) {}
    return c.read(assistantWeeklyTrendProvider);
  }

  test('angemeldet mit Premium: weeklyTrend aus 12 Wochen bis heute', () async {
    final wt = (await load(make())).value!;
    expect(wt.lastWeekKey, '2026-W45');
    expect(wt.delta, const Duration(hours: 2, minutes: 30));
    expect(wt.comparedWeeks, 4);
    final call = api.calls.single;
    expect(call.date, DateTime(2026, 11, 12));
    expect(call.granularity, TrendGranularity.week);
    expect(call.profileId, isNull);
  });

  test('Zusatzprofil: profileId geht mit', () async {
    await load(make(profileId: 'p2'));
    expect(api.calls.single.profileId, 'p2');
  });

  test('weeklyTrend null: Wert null (zu wenig Daten)', () async {
    api.handler = (c) async =>
        trendJson(c.date, c.granularity.apiValue, weeklyTrend: false);
    final v = await load(make());
    expect(v.hasValue, isTrue);
    expect(v.value, isNull);
  });

  test('ohne Premium: kein Backend-Aufruf', () async {
    final v = await load(make(premium: false));
    expect(v.value, isNull);
    expect(api.calls, isEmpty);
  });

  test('nicht angemeldet: kein Backend-Aufruf', () async {
    final v = await load(make(signedIn: false, premium: false));
    expect(v.value, isNull);
    expect(api.calls, isEmpty);
  });

  group('Fehler', () {
    final events = <LogEvent>[];
    captureLogs(events);

    test('API-Fehler: Fehlerzustand, gemeldet, kein automatisches Wiederholen',
        () async {
      api.handler =
          (_) async => throw const ApiException('getTrendReport', 500);
      final c = make();
      final v = await load(c);
      expect(v.hasError, isTrue);
      expect(reported(events, 'AssistantWeeklyTrend').map((e) => e.level),
          [Level.error]);
      expect(reported(events, 'AssistantWeeklyTrend').single.message.toString(),
          contains('500'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(api.calls, hasLength(1));

      api.handler = (c) async => trendJson(c.date, c.granularity.apiValue);
      c.invalidate(assistantWeeklyTrendProvider);
      expect((await load(c)).value, isNotNull);
      expect(api.calls, hasLength(2));
    });

    for (final e in transientNetworkErrors.entries) {
      test('erwartbarer Netzwerkfehler (${e.key}): Fehler, nicht gemeldet',
          () async {
        api.handler = (_) async => throw e.value;
        final v = await load(make());
        expect(v.hasError, isTrue);
        expect(reported(events, 'AssistantWeeklyTrend'), isEmpty);
      });
    }

    test('NotSignedInException: nicht gemeldet', () async {
      api.handler = (_) async => throw const NotSignedInException('x');
      await load(make());
      expect(reported(events, 'AssistantWeeklyTrend'), isEmpty);
    });
  });
}
