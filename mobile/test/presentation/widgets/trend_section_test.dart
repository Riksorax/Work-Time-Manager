import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/clock_provider.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/providers/subscription_provider.dart';
import 'package:flutter_work_time/core/theme/app_theme.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';
import 'package:flutter_work_time/domain/utils/insights_utils.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/screens/reports_page.dart';
import 'package:flutter_work_time/presentation/state/insights_state.dart';
import 'package:flutter_work_time/presentation/view_models/insights_view_model.dart';
import 'package:flutter_work_time/presentation/widgets/premium_blur_gate.dart';
import 'package:flutter_work_time/presentation/widgets/trend_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/trend_fixture.dart';

const _user = UserEntity(id: 'u1', email: 'a@b.c');
final _today = DateTime(2026, 11, 12);

class _Insights extends InsightsViewModel {
  @override
  InsightsState build() => const InsightsState(
        weekdayAverages: [
          WeekdayAverage(
              weekday: 1,
              averageWorkDuration: Duration(hours: 8),
              deviationFromOverallAverage: Duration(minutes: 5),
              sampleCount: 4),
        ],
        burnoutStatus:
            BurnoutStatus(currentStreak: 0, longestStreak: 0, isWarning: false),
        heatmap: [],
      );

  @override
  Future<void> loadInsights() async {}
}

/// Ansicht (#531) im Insights-Tab, echtes ViewModel, API gefälscht.
Future<FakeTrendApi> _pump(
  WidgetTester tester, {
  Future<Map<String, dynamic>> Function(TrendCall c)? handler,
  String locale = 'de',
  bool dark = false,
  double width = 412,
  bool premium = true,
  UserEntity? user = _user,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 2400);
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final api = FakeTrendApi(
      handler ?? (c) async => trendJson(c.date, c.granularity.apiValue));
  await tester.pumpWidget(ProviderScope(
    overrides: [
      clockProvider.overrideWithValue(() => DateTime(2026, 11, 12, 9)),
      sharedPreferencesProvider.overrideWithValue(prefs),
      apiClientProvider.overrideWithValue(api),
      authStateProvider.overrideWithValue(AsyncValue<UserEntity?>.data(user)),
      isPremiumProvider.overrideWithValue(premium),
      insightsViewModelProvider.overrideWith(_Insights.new),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: InsightsView()),
    ),
  ));
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
  return api;
}

Future<Map<String, dynamic>> _never(TrendCall _) =>
    Completer<Map<String, dynamic>>().future;

void main() {
  group('Trend-Abschnitt im Insights-Tab (#531)', () {
    testWidgets('Daten (de): Wochen-Trend, beide Diagramme, vor den Insights',
        (t) async {
      final api = await _pump(t);
      expect(api.calls.single.date, _today);
      expect(find.text('Trend'), findsOneWidget);
      expect(find.text('Wochen-Trend'), findsOneWidget);
      expect(
          find.text('+02:30 h gegenüber dem Durchschnitt der letzten 4 Wochen'),
          findsOneWidget);
      expect(
          find.text('KW 45: 41:30 h · Durchschnitt 39:00 h'), findsOneWidget);
      expect(find.text('Arbeitszeit je Woche'), findsOneWidget);
      expect(find.text('Überstunden im Zeitraum'), findsOneWidget);
      expect(
          find.text(
              'Aufsummiert ab 24. Aug. 2026, nicht dein Gleitzeit-Saldo.'),
          findsOneWidget);
      expect(find.byIcon(Icons.trending_up), findsOneWidget);
      // Die vorhandenen Insights folgen darunter.
      final trendY = t.getTopLeft(find.byType(TrendSection)).dy;
      final insightsY = t.getTopLeft(find.text('Wochentags-Analyse')).dy;
      expect(insightsY, greaterThan(trendY));
      expect(t.takeException(), isNull);
    });

    testWidgets('Daten (en): gleiche Wörter wie im Web, CW', (t) async {
      await _pump(t, locale: 'en');
      expect(find.text('Weekly trend'), findsOneWidget);
      expect(
          find.text(
              '+02:30 h compared with the average of the previous 4 weeks'),
          findsOneWidget);
      expect(find.text('CW 45: 41:30 h · average 39:00 h'), findsOneWidget);
      expect(find.text('Working time per week'), findsOneWidget);
      expect(find.text('Overtime in this period'), findsOneWidget);
      expect(find.text('CW 46'), findsWidgets);
      expect(t.takeException(), isNull);
    });

    testWidgets('Umschalten auf 12 Monate lädt Monate', (t) async {
      final api = await _pump(t);
      await t.tap(find.text('12 Monate'));
      await t.pump();
      await t.pump();
      expect(api.calls.last.granularity.apiValue, 'month');
      expect(find.text('Arbeitszeit je Monat'), findsOneWidget);
      expect(
          find.text(
              'Aufsummiert ab Dezember 2025, nicht dein Gleitzeit-Saldo.'),
          findsOneWidget);
      // Der Wochen-Trend steht auch bei Monaten.
      expect(find.text('Wochen-Trend'), findsOneWidget);
    });

    testWidgets('weeklyTrend null: Hinweis auf zu wenig Daten', (t) async {
      await _pump(t,
          handler: (c) async =>
              trendJson(c.date, c.granularity.apiValue, weeklyTrend: false));
      expect(find.text('Für den Wochen-Trend liegen noch zu wenig Daten vor.'),
          findsOneWidget);
      expect(find.text('Arbeitszeit je Woche'), findsOneWidget);
    });

    testWidgets('Laden: Ladeindikator mit Screenreader-Text', (t) async {
      final handle = t.ensureSemantics();
      await _pump(t, handler: _never);
      expect(find.bySemanticsLabel('Trend wird geladen'), findsOneWidget);
      expect(find.text('Wochen-Trend'), findsNothing);
      // Die Insights darunter sind trotzdem sichtbar.
      expect(find.text('Wochentags-Analyse'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('Fehler: Hinweis und „Erneut versuchen“ lädt neu', (t) async {
      var fail = true;
      final api = await _pump(t, handler: (c) async {
        if (fail) throw Exception('boom');
        return trendJson(c.date, c.granularity.apiValue);
      });
      expect(
          find.text('Der Trend konnte nicht geladen werden.'), findsOneWidget);
      fail = false;
      await t.tap(find.text('Erneut versuchen'));
      await t.pump();
      await t.pump();
      expect(api.calls, hasLength(2));
      expect(find.text('Wochen-Trend'), findsOneWidget);
    });

    testWidgets('leer: Hinweis statt Diagramm', (t) async {
      await _pump(t,
          handler: (c) async => emptyTrendJson(c.date, c.granularity.apiValue));
      expect(find.text('In den letzten 12 Wochen gibt es noch keine Einträge.'),
          findsOneWidget);
      expect(find.text('Arbeitszeit je Woche'), findsNothing);
    });

    testWidgets('Free: Premium-Sperre, kein Trend, kein Aufruf', (t) async {
      final api = await _pump(t, premium: false);
      expect(find.byType(PremiumBlurGate), findsOneWidget);
      expect(find.byType(TrendSection), findsNothing);
      expect(api.calls, isEmpty);
    });

    testWidgets('nicht angemeldet: Anmelde-Hinweis, kein Aufruf', (t) async {
      final api = await _pump(t, user: null);
      expect(find.text('Anmeldung erforderlich für Insights'), findsOneWidget);
      expect(find.byType(TrendSection), findsNothing);
      expect(api.calls, isEmpty);
    });

    for (final locale in ['de', 'en']) {
      for (final month in [false, true]) {
        testWidgets(
            '360 px ohne Overflow ($locale, ${month ? 'Monate' : 'Wochen'})',
            (t) async {
          await _pump(t, width: 360, locale: locale);
          if (month) {
            await t.tap(find.text(locale == 'de' ? '12 Monate' : '12 months'));
            await t.pump();
            await t.pump();
          }
          expect(t.takeException(), isNull);
        });
      }
    }

    testWidgets('Dunkelmodus mit Lücken rendert ohne Fehler', (t) async {
      await _pump(t,
          dark: true,
          handler: (c) async =>
              trendJson(c.date, c.granularity.apiValue, gaps: {2, 6}));
      expect(find.text('keine Einträge'), findsNWidgets(2));
      expect(t.takeException(), isNull);
    });
  });
}
