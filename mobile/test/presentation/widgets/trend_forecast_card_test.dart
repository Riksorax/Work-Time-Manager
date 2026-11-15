import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

import '../../support/trend_fixture.dart';

/// Karte „Prognose zum Jahresende“ (#532) in der Trend-Ansicht: echtes
/// ViewModel, API gefälscht (Antwort im Format des Backends, gelesen über die
/// echte Lesegrenze). Roboto aus dem Flutter-SDK wie
/// `yearly_comparison_card_test`, damit die Overflow-Prüfung bei 320/360 px
/// die echte Schriftbreite misst. Bezugstag und Werte sind fest, nichts hängt
/// vom heutigen Datum ab.
const _user = UserEntity(id: 'u1', email: 'a@b.c');

Directory _materialFonts() {
  final candidates = [
    File(Platform.resolvedExecutable).parent.parent.parent.path,
    if (Platform.environment['FLUTTER_ROOT'] != null)
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts',
  ];
  for (final c in candidates) {
    final dir = Directory('$c/material_fonts');
    if (File('${dir.path}/Roboto-Regular.ttf').existsSync()) return dir;
  }
  throw StateError('material_fonts nicht gefunden (gesucht: $candidates)');
}

Future<void> _loadFonts() async {
  final dir = _materialFonts();
  final roboto = FontLoader('Roboto');
  for (final f in [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Italic.ttf',
  ]) {
    final file = File('${dir.path}/$f');
    if (!file.existsSync()) continue;
    final bytes = file.readAsBytesSync();
    roboto.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons');
  final bytes = File('${dir.path}/MaterialIcons-Regular.otf').readAsBytesSync();
  icons.addFont(Future.value(ByteData.view(bytes.buffer)));
  await icons.load();
}

class _Insights extends InsightsViewModel {
  @override
  InsightsState build() => const InsightsState(
        weekdayAverages: [],
        burnoutStatus:
            BurnoutStatus(currentStreak: 0, longestStreak: 0, isWarning: false),
        heatmap: [],
      );

  @override
  Future<void> loadInsights() async {}
}

const _forecastKey = ValueKey('trend-forecast');

Future<FakeTrendApi> _pump(
  WidgetTester tester, {
  Map<String, dynamic>? forecast,
  ForecastMock mock = ForecastMock.positive,
  bool emptyTrend = false,
  String locale = 'de',
  bool dark = false,
  double width = 412,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 2400);
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final api = FakeTrendApi((c) async => emptyTrend
      ? emptyTrendJson(c.date, c.granularity.apiValue)
      : trendJson(c.date, c.granularity.apiValue,
          forecast: mock, forecastOverride: forecast));
  await tester.pumpWidget(ProviderScope(
    overrides: [
      clockProvider.overrideWithValue(() => DateTime(2026, 11, 12, 9)),
      sharedPreferencesProvider.overrideWithValue(prefs),
      apiClientProvider.overrideWithValue(api),
      authStateProvider
          .overrideWithValue(const AsyncValue<UserEntity?>.data(_user)),
      isPremiumProvider.overrideWithValue(true),
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

Finder _inCard(String text) =>
    find.descendant(of: find.byKey(_forecastKey), matching: find.text(text));

Map<String, dynamic> _rest(double weeks) =>
    forecastJson(2026, remainingWeeks: weeks);

void main() {
  setUpAll(() async {
    await _loadFonts();
    await initializeDateFormatting('de', null);
    await initializeDateFormatting('en', null);
  });

  group('Prognose zum Jahresende (#532)', () {
    testWidgets('positiv (de): Wortlaut wie im Web, unter dem Wochen-Trend',
        (t) async {
      await _pump(t);
      expect(_inCard('Prognose zum Jahresende'), findsOneWidget);
      expect(
          _inCard('Voraussichtlich +27:30 h zum 31.12.2026'), findsOneWidget);
      expect(
          _inCard('Aktueller Saldo +18:45 h · im Schnitt +01:15 h pro Woche '
              '(letzte 6 Wochen) · noch rund 7 Wochen'),
          findsOneWidget);
      expect(
          _inCard('Hochrechnung aus deinen letzten Wochen. Geplanter Urlaub '
              'und Feiertage sind nicht berücksichtigt.'),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(_forecastKey),
              matching: find.byIcon(Icons.trending_up)),
          findsOneWidget);
      // Direkt unter dem Wochen-Trend, vor dem Balkendiagramm.
      final weekY = t.getTopLeft(find.text('Wochen-Trend')).dy;
      final cardY = t.getTopLeft(find.byKey(_forecastKey)).dy;
      final barsY = t.getTopLeft(find.text('Arbeitszeit je Woche')).dy;
      expect(cardY, greaterThan(weekY));
      expect(barsY, greaterThan(cardY));
      expect(t.takeException(), isNull);
    });

    testWidgets('neutral: keine Wertungsfarbe am Icon und an den Texten',
        (t) async {
      await _pump(t, mock: ForecastMock.negative);
      final cs = Theme.of(t.element(find.byKey(_forecastKey))).colorScheme;
      final icon = t.widget<Icon>(find.descendant(
          of: find.byKey(_forecastKey), matching: find.byType(Icon)));
      expect(icon.icon, Icons.trending_down);
      expect(icon.color, cs.onSurfaceVariant);
      for (final text in t.widgetList<Text>(find.descendant(
          of: find.byKey(_forecastKey), matching: find.byType(Text)))) {
        expect(text.style?.color, isNot(cs.error));
      }
    });

    testWidgets('negativ (de)', (t) async {
      await _pump(t, mock: ForecastMock.negative);
      expect(
          _inCard('Voraussichtlich -07:45 h zum 31.12.2026'), findsOneWidget);
      expect(
          _inCard('Aktueller Saldo -02:30 h · im Schnitt -00:45 h pro Woche '
              '(letzte 6 Wochen) · noch rund 7 Wochen'),
          findsOneWidget);
    });

    testWidgets('Prognose gleich Saldo: Icon flach', (t) async {
      await _pump(t,
          forecast: forecastJson(2026, currentHours: 4, projectedHours: 4));
      expect(
          _inCard('Voraussichtlich +04:00 h zum 31.12.2026'), findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(_forecastKey),
              matching: find.byIcon(Icons.trending_flat)),
          findsOneWidget);
    });

    testWidgets('Saldo 0 ohne Vorzeichenfehler', (t) async {
      await _pump(t,
          forecast: forecastJson(2026, currentHours: 0, projectedHours: 0));
      expect(
          _inCard('Voraussichtlich +00:00 h zum 31.12.2026'), findsOneWidget);
      expect(
          find.textContaining('Aktueller Saldo +00:00 h · '), findsOneWidget);
    });

    testWidgets('null: Hinweis auf fehlende Daten, ohne Hochrechnungs-Hinweis',
        (t) async {
      await _pump(t, mock: ForecastMock.none);
      expect(_inCard('Prognose zum Jahresende'), findsOneWidget);
      expect(
          _inCard('Für eine Prognose fehlen noch Daten (mindestens 4 der '
              'letzten 8 Wochen mit Einträgen).'),
          findsOneWidget);
      expect(find.textContaining('Hochrechnung'), findsNothing);
      expect(
          find.descendant(
              of: find.byKey(_forecastKey), matching: find.byType(Icon)),
          findsNothing);
      // Der Rest der Ansicht bleibt.
      expect(find.text('Arbeitszeit je Woche'), findsOneWidget);
    });

    testWidgets('leere Trend-Ansicht: keine Prognose-Karte', (t) async {
      await _pump(t, emptyTrend: true);
      expect(find.byKey(_forecastKey), findsNothing);
    });

    testWidgets('12 Monate: dieselbe Karte', (t) async {
      final api = await _pump(t);
      await t.tap(find.text('12 Monate'));
      await t.pump();
      await t.pump();
      expect(api.calls.last.granularity.apiValue, 'month');
      expect(
          _inCard('Voraussichtlich +27:30 h zum 31.12.2026'), findsOneWidget);
      final monthY = t.getTopLeft(find.byKey(_forecastKey)).dy;
      expect(t.getTopLeft(find.text('Arbeitszeit je Monat')).dy,
          greaterThan(monthY));
    });

    group('Restwochen', () {
      for (final (weeks, de, en) in [
        (7.142857, 'noch rund 7 Wochen', 'about 7 weeks left'),
        (1.2, 'noch rund 1 Woche', 'about 1 week left'),
        (1.6, 'noch rund 2 Wochen', 'about 2 weeks left'),
        (0.857143, 'weniger als eine Woche', 'less than a week left'),
      ]) {
        testWidgets('$weeks (de)', (t) async {
          await _pump(t, forecast: _rest(weeks));
          expect(find.textContaining(RegExp('\\(letzte 6 Wochen\\) · $de\$')),
              findsOneWidget);
          expect(_inCard('Voraussichtlich +27:30 h zum 31.12.2026'),
              findsOneWidget);
        });
        testWidgets('$weeks (en)', (t) async {
          await _pump(t, forecast: _rest(weeks), locale: 'en');
          expect(find.textContaining(RegExp('\\(last 6 weeks\\) · $en\$')),
              findsOneWidget);
        });
      }

      testWidgets('0 (de): Prognose entspricht dem Saldo', (t) async {
        await _pump(t,
            forecast: forecastJson(2026,
                remainingWeeks: 0, currentHours: 18.75, projectedHours: 18.75));
        expect(
            _inCard('Zum 31.12.2026 entspricht die Prognose dem aktuellen '
                'Saldo: +18:45 h'),
            findsOneWidget);
        expect(_inCard('Aktueller Saldo +18:45 h · das Jahr endet heute'),
            findsOneWidget);
        expect(find.textContaining('im Schnitt'), findsNothing);
      });

      testWidgets('0 (en)', (t) async {
        await _pump(t,
            locale: 'en',
            forecast: forecastJson(2026,
                remainingWeeks: 0, currentHours: 18.75, projectedHours: 18.75));
        expect(
            _inCard('By 12/31/2026 the forecast equals the current balance: '
                '+18:45 h'),
            findsOneWidget);
        expect(_inCard('Current balance +18:45 h · the year ends today'),
            findsOneWidget);
      });
    });

    testWidgets('englisch: Wortlaut wie im Web', (t) async {
      await _pump(t, locale: 'en');
      expect(_inCard('Year-end forecast'), findsOneWidget);
      expect(_inCard('Expected +27:30 h by 12/31/2026'), findsOneWidget);
      expect(
          _inCard('Current balance +18:45 h · on average +01:15 h per week '
              '(last 6 weeks) · about 7 weeks left'),
          findsOneWidget);
      expect(
          _inCard('Projection based on your recent weeks. Planned vacation '
              'and public holidays are not included.'),
          findsOneWidget);
    });

    testWidgets('englisch null', (t) async {
      await _pump(t, locale: 'en', mock: ForecastMock.none);
      expect(
          _inCard('Not enough data for a forecast yet (at least 4 of the '
              'last 8 weeks with entries).'),
          findsOneWidget);
    });

    testWidgets('Screenreader: ein zusammenhängender Text', (t) async {
      final handle = t.ensureSemantics();
      await _pump(t);
      expect(
          find.bySemanticsLabel('Prognose zum Jahresende. Voraussichtlich '
              '+27:30 h zum 31.12.2026. Aktueller Saldo +18:45 h · im Schnitt '
              '+01:15 h pro Woche (letzte 6 Wochen) · noch rund 7 Wochen. '
              'Hochrechnung aus deinen letzten Wochen. Geplanter Urlaub und '
              'Feiertage sind nicht berücksichtigt.'),
          findsOneWidget);
      handle.dispose();
    });

    testWidgets('Screenreader null', (t) async {
      final handle = t.ensureSemantics();
      await _pump(t, mock: ForecastMock.none);
      expect(
          find.bySemanticsLabel('Prognose zum Jahresende. Für eine Prognose '
              'fehlen noch Daten (mindestens 4 der letzten 8 Wochen mit '
              'Einträgen).'),
          findsOneWidget);
      handle.dispose();
    });

    for (final width in [320.0, 360.0]) {
      for (final locale in ['de', 'en']) {
        for (final mock in ForecastMock.values) {
          testWidgets('$width px ohne Overflow ($locale, ${mock.name}, Roboto)',
              (t) async {
            await _pump(t, width: width, locale: locale, mock: mock);
            expect(find.byKey(_forecastKey), findsOneWidget);
            expect(t.takeException(), isNull);
          });
        }
        testWidgets('$width px ohne Overflow ($locale, Restwochen 0)',
            (t) async {
          await _pump(t,
              width: width,
              locale: locale,
              forecast: forecastJson(2026,
                  remainingWeeks: 0,
                  currentHours: -123.25,
                  projectedHours: -123.25));
          expect(t.takeException(), isNull);
        });
      }
    }

    testWidgets('Dunkelmodus rendert ohne Fehler', (t) async {
      await _pump(t, dark: true);
      expect(_inCard('Prognose zum Jahresende'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });
}
