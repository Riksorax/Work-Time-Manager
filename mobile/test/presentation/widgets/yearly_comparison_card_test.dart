import 'dart:async';
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
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/screens/reports_page.dart';
import 'package:flutter_work_time/presentation/widgets/premium_blur_gate.dart';
import 'package:flutter_work_time/presentation/widgets/yearly_comparison_card.dart';

import '../../support/fake_repositories.dart';
import '../../support/yearly_comparison_fixture.dart';

/// Vergleichskarte im Jahres-Tab (#530): echte ViewModels, API gefälscht
/// (Antworten im Format des Backends, gelesen über die echte Lesegrenze).
/// Roboto aus dem Flutter-SDK wie `reports_page_overflow_320_test`, damit die
/// Overflow-Prüfung bei 320/360 px die echte Schriftbreite misst.
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

/// Nur die Anfrage der Karte (laufendes Jahr, mit Stichtag) über [fn]; die
/// Jahreswerte des Tabs (ohne Stichtag) wie die Fixture.
Future<Map<String, dynamic>> Function(YearlyComparisonCall c) _card(
        FutureOr<Map<String, dynamic>> Function(YearlyComparisonCall c) fn) =>
    (c) async => c.until == null ? yearlyComparisonJsonFor(c) : await fn(c);

/// Nur die Jahreswerte des Tabs (ohne Stichtag) über [fn].
Future<Map<String, dynamic>> Function(YearlyComparisonCall c) _totals(
        FutureOr<Map<String, dynamic>> Function(YearlyComparisonCall c) fn) =>
    (c) async => c.until != null ? yearlyComparisonJsonFor(c) : await fn(c);

void main() {
  setUpAll(() async {
    await _loadFonts();
    await initializeDateFormatting('de', null);
    await initializeDateFormatting('en', null);
  });

  /// Jahres-Tab (`YearlyReportView`) wie in der App. [handler] beantwortet
  /// alle Aufrufe; im laufenden Jahr fragt der Tab ohne Stichtag an (ganzes
  /// Jahr), die Karte mit Stichtag ([card]).
  Future<FakeYearlyComparisonApi> pump(
    WidgetTester tester, {
    Future<Map<String, dynamic>> Function(YearlyComparisonCall c)? handler,
    String locale = 'de',
    bool dark = false,
    double width = 412,
    bool premium = true,
    UserEntity? user = _user,
    int? year,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 3200);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = FakeYearlyComparisonApi(
        handler ?? (c) async => yearlyComparisonJsonFor(c));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(() => DateTime(2026, 11, 15, 9)),
        sharedPreferencesProvider.overrideWithValue(prefs),
        apiClientProvider.overrideWithValue(api),
        authStateProvider.overrideWithValue(AsyncValue<UserEntity?>.data(user)),
        isPremiumProvider.overrideWithValue(premium),
        activeEntitlementProvider.overrideWithValue(null),
        workRepositoryProvider.overrideWithValue(FakeWorkRepository()),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        overtimeRepositoryProvider.overrideWithValue(FakeOvertimeRepository()),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: YearlyReportView()),
      ),
    ));
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
    if (year != null) {
      // Wie die Pfeile der Jahresnavigation.
      for (var y = 2026; y > year; y--) {
        await tester.tap(find.byTooltip('Vorheriges Jahr'));
        for (var i = 0; i < 6; i++) {
          await tester.pump();
        }
      }
    }
    return api;
  }

  Finder card() => find.byType(YearlyComparisonCard);
  Finder inCard(Finder f) => find.descendant(of: card(), matching: f);

  group('Vergleichskarte (#530)', () {
    testWidgets('laufendes Jahr (de): Stichtag, Werte, Differenzen, Hinweis',
        (t) async {
      final api = await pump(t);
      // Jahreswerte ohne Stichtag, Karte bis heute.
      expect(api.calls.map((c) => (c.year, c.until)),
          containsAll([(2026, null), (2026, DateTime(2026, 11, 15))]));

      expect(inCard(find.text('Vergleich 2026 mit 2025')), findsOneWidget);
      expect(
          inCard(find.text('Laufendes Jahr: beide Jahre jeweils bis 15.11.')),
          findsOneWidget);
      for (final label in [
        'Arbeitszeit (netto)',
        'Überstunden',
        'Arbeitstage',
        'Urlaubstage',
        'Krankheitstage',
        'Feiertage',
      ]) {
        expect(inCard(find.text(label)), findsOneWidget, reason: label);
      }
      // Arbeitszeit: Jahr, Vorjahr, Differenz und Prozent.
      expect(inCard(find.text('1498:30')), findsOneWidget);
      expect(inCard(find.text('1421:00')), findsOneWidget);
      expect(inCard(find.text('+77:30')), findsOneWidget);
      expect(inCard(find.text('(+5,5 %)')), findsOneWidget);
      // Überstunden mit Vorzeichen.
      expect(inCard(find.text('+18:45')), findsOneWidget);
      expect(inCard(find.text('-04:15')), findsOneWidget);
      expect(inCard(find.text('+23:00')), findsOneWidget);
      // Tage; Differenz 0 ohne Vorzeichen.
      expect(inCard(find.text('+6')), findsOneWidget);
      expect(inCard(find.text('-3')), findsOneWidget);
      expect(inCard(find.text('-4')), findsOneWidget);
      expect(inCard(find.text('0')), findsOneWidget);
      expect(
          inCard(find.text('Überstunden des Jahres, nicht dein '
              'Gleitzeit-Saldo. Für beide Jahre gelten deine heutigen '
              'Einstellungen.')),
          findsOneWidget);
      expect(inCard(find.text('keine Daten')), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('Differenzen neutral: keine Wertungsfarbe', (t) async {
      await pump(t);
      final base = Theme.of(t.element(card())).textTheme.bodyMedium!.color;
      for (final text in ['+77:30', '+23:00', '-3', '0']) {
        final w = t.widget<Text>(inCard(find.text(text)));
        expect(w.style?.color, base, reason: text);
      }
    });

    testWidgets('Screenreader: eine Zeile je Kennzahl mit allen Werten',
        (t) async {
      final handle = t.ensureSemantics();
      await pump(t);
      expect(
          find.bySemanticsLabel('Arbeitszeit (netto): 2026 1498:30, '
              '2025 1421:00, Differenz +77:30 (+5,5 %)'),
          findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Jahresvergleich wird geladen')),
          findsNothing);
      handle.dispose();
    });

    testWidgets('abgeschlossenes Jahr: ohne Stichtag-Hinweis', (t) async {
      final api = await pump(t, year: 2025);
      expect(inCard(find.text('Vergleich 2025 mit 2024')), findsOneWidget);
      expect(inCard(find.textContaining('Laufendes Jahr')), findsNothing);
      expect(inCard(find.text('1712:15')), findsOneWidget);
      expect(api.calls.where((c) => c.year == 2025).map((c) => c.until),
          everyElement(isNull));
    });

    testWidgets('Vorjahr ohne Daten: „keine Daten“, Differenz „–“', (t) async {
      final handle = t.ensureSemantics();
      await pump(t,
          handler: _card((c) => yearlyComparisonJson(c.year,
              until: '11-15', previousEmpty: true)));
      expect(inCard(find.text('keine Daten')), findsNWidgets(6));
      expect(inCard(find.text('–')), findsNWidgets(6));
      expect(
          inCard(find.text('Für 2025 gibt es keine Einträge, deshalb gibt es '
              'keine Differenz.')),
          findsOneWidget);
      expect(
          find.bySemanticsLabel('Urlaubstage: 2026 24, 2025 keine Daten, '
              'Differenz keine Differenz'),
          findsOneWidget);
      handle.dispose();
      expect(t.takeException(), isNull);
    });

    testWidgets('ohne Prozentwert', (t) async {
      await pump(t,
          handler: _card((c) =>
              yearlyComparisonJson(c.year, until: '11-15', noPercent: true)));
      expect(inCard(find.text('+77:30')), findsOneWidget);
      expect(inCard(find.textContaining('%')), findsNothing);
    });

    testWidgets('Leerzustand: keine Einträge im Jahr', (t) async {
      await pump(t,
          handler: _card((c) => yearlyComparisonJson(c.year,
              until: '11-15', currentEmpty: true)));
      expect(
          inCard(find.text('Für 2026 gibt es noch keine Einträge, deshalb ist '
              'kein Vergleich möglich.')),
          findsOneWidget);
      expect(inCard(find.text('Arbeitszeit (netto)')), findsNothing);
      expect(inCard(find.textContaining('Gleitzeit-Saldo')), findsNothing);
    });

    testWidgets('Laden', (t) async {
      final handle = t.ensureSemantics();
      await pump(t,
          handler: _card((_) => Completer<Map<String, dynamic>>().future));
      expect(inCard(find.byType(CircularProgressIndicator)), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Jahresvergleich wird geladen')),
          findsOneWidget);
      handle.dispose();
    });

    testWidgets('Fehler mit „Erneut versuchen“', (t) async {
      var fail = true;
      final api = await pump(t, handler: _card((c) {
        if (fail) throw Exception('boom');
        return yearlyComparisonJsonFor(c);
      }));
      expect(
          inCard(find.text('Der Jahresvergleich konnte nicht geladen '
              'werden.')),
          findsOneWidget);
      final before = api.calls.length;
      fail = false;
      await t.tap(inCard(find.text('Erneut versuchen')));
      for (var i = 0; i < 4; i++) {
        await t.pump();
      }
      expect(api.calls.length, before + 1);
      expect(inCard(find.text('+77:30')), findsOneWidget);
    });

    testWidgets('Jahr vor 2001: nur Hinweis, keine Anfrage', (t) async {
      final api = await pump(t, year: 2000);
      expect(
          inCard(find
              .text('Für 2000 ist kein Vergleich mit dem Vorjahr möglich.')),
          findsOneWidget);
      expect(api.calls.where((c) => c.year == 2000), isEmpty);
    });

    testWidgets('Englisch: gleiche Wörter wie im Web', (t) async {
      await pump(t, locale: 'en');
      expect(inCard(find.text('2026 compared with 2025')), findsOneWidget);
      expect(inCard(find.text('Current year: both years up to 11/15')),
          findsOneWidget);
      expect(inCard(find.text('Working time (net)')), findsOneWidget);
      expect(inCard(find.text('Public holidays')), findsOneWidget);
      expect(inCard(find.text('Difference')), findsOneWidget);
      expect(inCard(find.text('(+5.5 %)')), findsOneWidget);
      expect(
          inCard(find.text('Overtime of the year, not your flexitime '
              'balance. Your current settings apply to both years.')),
          findsOneWidget);
    });

    testWidgets('liegt zwischen Statistikkarte und Monatsübersicht', (t) async {
      await pump(t);
      final statsY = t.getTopLeft(find.text('Gesamte Arbeitszeit:')).dy;
      final cardY = t.getTopLeft(card()).dy;
      final monthsY = t.getTopLeft(find.text('Monatsübersicht:')).dy;
      expect(cardY, greaterThan(statsY));
      expect(monthsY, greaterThan(cardY));
    });

    for (final width in [320.0, 360.0]) {
      for (final locale in ['de', 'en']) {
        for (final previousEmpty in [false, true]) {
          testWidgets(
              'kein Overflow (${width.toInt()} px, $locale, '
              '${previousEmpty ? 'Vorjahr leer' : 'Daten'})', (t) async {
            await pump(t,
                width: width,
                locale: locale,
                handler: _card((c) => yearlyComparisonJson(c.year,
                    until: '11-15', previousEmpty: previousEmpty)));
            expect(card(), findsOneWidget);
            expect(t.takeException(), isNull);
          });
        }
      }
    }

    testWidgets('Dunkelmodus ohne Fehler', (t) async {
      await pump(t, dark: true);
      expect(inCard(find.text('+77:30')), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('Gate (#530)', () {
    testWidgets('Free: gesperrter Tab, keine Anfrage', (t) async {
      final api = await pump(t, premium: false);
      expect(find.byType(PremiumBlurGate), findsOneWidget);
      expect(card(), findsNothing);
      expect(
          find.textContaining('Vergleich mit dem Vorjahr', skipOffstage: false),
          findsOneWidget);
      expect(api.calls, isEmpty);
    });

    testWidgets('nicht angemeldet: Anmelde-Hinweis, keine Anfrage', (t) async {
      final api = await pump(t, user: null);
      expect(find.text('Anmeldung erforderlich für Jahresberichte'),
          findsOneWidget);
      expect(card(), findsNothing);
      expect(api.calls, isEmpty);
    });
  });

  group('Jahreswerte vom Backend (#530)', () {
    testWidgets('Statistikkarte und Monatsliste zeigen current (ganzes Jahr)',
        (t) async {
      await pump(t);
      // Fixture ganzes Jahr: 1712:15 netto, 214 Arbeitstage, 30/6/10.
      expect(find.text('1712:15:00'), findsOneWidget);
      expect(find.text('214'), findsOneWidget);
      expect(find.text('+22:30'), findsOneWidget);
      expect(find.text('Monatsübersicht:'), findsOneWidget);
      expect(find.text('Januar'), findsOneWidget);
      expect(find.text('Dezember'), findsOneWidget);
    });

    testWidgets('Fehler der Jahreswerte: Hinweis mit „Erneut versuchen“',
        (t) async {
      var fail = true;
      final api = await pump(t, handler: _totals((c) {
        if (fail) throw Exception('boom');
        return yearlyComparisonJsonFor(c);
      }));
      expect(find.text('Der Jahresbericht konnte nicht geladen werden.'),
          findsOneWidget);
      expect(find.text('Monatsübersicht:'), findsNothing);
      expect(find.text('Als PDF exportieren'), findsNothing);
      // Die Vergleichskarte lädt unabhängig davon.
      expect(card(), findsOneWidget);

      fail = false;
      final before = api.totalsCalls.length;
      await t.tap(find.text('Erneut versuchen').first);
      for (var i = 0; i < 6; i++) {
        await t.pump();
      }
      expect(api.totalsCalls.length, before + 1);
      expect(find.text('214'), findsOneWidget);
    });
  });
}
