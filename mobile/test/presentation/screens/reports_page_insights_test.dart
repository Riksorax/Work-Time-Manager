import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:flutter_work_time/core/providers/clock_provider.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/providers/subscription_provider.dart';
import 'package:flutter_work_time/core/utils/api_errors.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/screens/reports_page.dart';

import '../../support/analytics_fixture.dart';
import '../../support/fake_repositories.dart';
import '../../support/offline_fixture.dart' show hostLookupError;

const _user = UserEntity(id: 'u1', email: 'a@b.c');

/// Insights-Tab (#537): angemeldet mit Backend-Werten, Warnung, Offline-,
/// Fehler- und Leerzustand, de/en, hell/dunkel, schmale Breite. Uhr und Zone
/// fest.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('de', null);
    await initializeDateFormatting('en', null);
  });

  late FakeAnalyticsApi api;
  late FakeWorkRepository work;

  setUp(() {
    api = FakeAnalyticsApi();
    work = FakeWorkRepository();
  });

  Future<void> pump(
    WidgetTester tester, {
    String locale = 'de',
    bool premium = true,
    ThemeMode themeMode = ThemeMode.light,
    Size size = const Size(412, 915),
    String? profileId,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(() => DateTime(2026, 11, 15, 9)),
        authStateProvider.overrideWithValue(const AsyncValue.data(_user)),
        isPremiumProvider.overrideWithValue(premium),
        apiClientProvider.overrideWithValue(api),
        workRepositoryProvider.overrideWithValue(work),
        activeWorkProfileIdProvider.overrideWith(() => TestProfile(profileId)),
        deviceTimeZoneProvider
            .overrideWithValue(const FixedTimeZone('Europe/Berlin')),
      ],
      child: MaterialApp(
        locale: Locale(locale),
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: themeMode,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: InsightsView()),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) =>
      tester.scrollUntilVisible(finder, 200,
          scrollable: find.byType(Scrollable).first);

  testWidgets('de: Werte vom Backend, ein Aufruf mit Bezugstag und Zone',
      (tester) async {
    await pump(tester);

    expect(api.insightsCalls, [
      (date: DateTime(2026, 11, 15), timeZone: 'Europe/Berlin', profileId: null)
    ]);
    expect(work.monthReads, isEmpty);
    await scrollTo(tester, find.text('Wochentags-Analyse'));
    expect(find.text('Ø 8:12:00 h (11x)'), findsOneWidget);
    expect(find.text('-00:18'), findsOneWidget);
    expect(find.text('+00:35'), findsOneWidget);
    expect(find.text('+00:00'), findsOneWidget);
    await scrollTo(tester, find.text('Start 09:00 Uhr'));
    expect(find.text('Start 07:00 Uhr'), findsOneWidget);
    expect(find.text('+00:34'), findsOneWidget);
    expect(find.text('-00:21'), findsOneWidget);
    expect(find.text('27x'), findsOneWidget);
    expect(find.textContaining('aufeinanderfolgenden'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('en: Werte vom Backend', (tester) async {
    await pump(tester, locale: 'en');
    await scrollTo(tester, find.text('Weekday analysis'));
    expect(find.text('Avg 9:05:00 h (12x)'), findsOneWidget);
    await scrollTo(tester, find.text('Start 08:00'));
    expect(find.text('+00:09'), findsOneWidget);
  });

  for (final (locale, text) in [
    ('de', 'Du liegst seit 7 aufeinanderfolgenden Arbeitstagen'),
    ('en', 'You have been over your target for 7 consecutive workdays'),
  ]) {
    testWidgets('Warnung aus der Antwort ($locale)', (tester) async {
      api.onInsights = (c) async => insightsJson(c.date, warning: true);
      await pump(tester, locale: locale);
      await scrollTo(tester, find.textContaining(text));
      expect(find.textContaining(text), findsOneWidget);
    });
  }

  for (final locale in ['de', 'en']) {
    testWidgets('offline: Hinweis, „Erneut versuchen“ lädt neu ($locale)',
        (tester) async {
      var fail = true;
      api.onInsights = (c) async {
        if (fail) throw hostLookupError;
        return insightsJson(c.date);
      };
      await pump(tester, locale: locale);
      final notice = find.byKey(const ValueKey('insightsLoadFailure'));
      await scrollTo(tester, notice);
      expect(find.text(locale == 'de' ? 'Keine Verbindung' : 'No connection'),
          findsOneWidget);
      expect(find.textContaining('SocketException'), findsNothing);
      expect(
          find.textContaining(
              locale == 'de' ? 'Noch nicht genug Daten' : 'Not enough data'),
          findsNothing);

      fail = false;
      await tester
          .tap(find.text(locale == 'de' ? 'Erneut versuchen' : 'Retry').last);
      await tester.pumpAndSettle();
      expect(notice, findsNothing);
      expect(api.insightsCalls, hasLength(2));
      await scrollTo(
          tester,
          find.text(
              locale == 'de' ? 'Wochentags-Analyse' : 'Weekday analysis'));
    });
  }

  testWidgets('anderer Fehler: allgemeine Meldung ohne Ausnahmetext',
      (tester) async {
    api.onInsights = (_) async => throw const ApiException('x', 500);
    await pump(tester);
    await scrollTo(
        tester, find.text('Die Berichte konnten nicht geladen werden.'));
    expect(find.text('Keine Verbindung'), findsNothing);
    expect(find.textContaining('ApiException'), findsNothing);
  });

  testWidgets('leere Antwort: Hinweis „nicht genug Daten“', (tester) async {
    api.onInsights = (c) async => insightsJson(c.date, empty: true);
    await pump(tester);
    await scrollTo(tester, find.textContaining('Noch nicht genug Daten'));
  });

  testWidgets('Zusatzprofil: profileId in der Anfrage', (tester) async {
    await pump(tester, profileId: 'p1');
    expect(api.insightsCalls.single.profileId, 'p1');
  });

  testWidgets('Free: Gate, kein Insights-Aufruf', (tester) async {
    await pump(tester, premium: false);
    expect(find.text('Premium freischalten'), findsOneWidget);
    expect(api.insightsCalls, isEmpty);
  });

  for (final locale in ['de', 'en']) {
    for (final width in [320.0, 360.0]) {
      testWidgets('ohne Overflow: $locale, ${width.toInt()} px, dunkel',
          (tester) async {
        api.onInsights = (c) async => insightsJson(c.date, warning: true);
        await pump(tester,
            locale: locale, themeMode: ThemeMode.dark, size: Size(width, 800));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
