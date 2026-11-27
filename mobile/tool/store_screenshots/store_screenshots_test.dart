// Play-Store-Screenshots aus den echten Seiten der App (#559).
//
// Aufruf (aus `mobile/`, ohne Android-SDK):
//
//   flutter test tool/store_screenshots
//
// Schreibt Variante A („schlicht“, nur der App-Bildschirm, formatfüllend) nach
// `../fastlane/metadata/android/{de-DE,en-US}/images/phoneScreenshots/1.png … 8.png`.
// Mit `--dart-define=STORE_HEADLINE_OUT=<ordner>` zusätzlich Variante B
// („mit Überschrift“) nach `<ordner>/{de-DE,en-US}/`, nie nach fastlane.
// Liegt außerhalb von `test/` und läuft deshalb nicht im normalen
// `flutter test` mit. Rendern und Hilfen: `tool/shared/screen_renderer.dart`
// (gemeinsam mit `tool/shorts_frames`). Details: `mobile/CLAUDE.md`, „Store-Screenshots (#559)“.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/theme/app_theme.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/screens/reports_page.dart';
import 'package:flutter_work_time/presentation/widgets/dashboard_work_locations.dart';
import 'package:flutter_work_time/presentation/widgets/yearly_comparison_card.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../shared/screen_renderer.dart';
import 'headlines.dart';

const _width = screenWidth;
const _height = screenHeight;

/// Ordner für Variante B (mit Überschrift); leer = B wird nicht erzeugt.
const _headlineOut = String.fromEnvironment('STORE_HEADLINE_OUT');

const _storeFolders = {'de': 'de-DE', 'en': 'en-US'};

final _motifs = <ScreenMotif>[
  // 1 Dashboard mit laufendem Timer.
  const ScreenMotif(),
  // 2 Tagesbericht mit Kalender.
  ScreenMotif(
    tab: 0,
    act: (t, c) async {
      await selectReportDay(t, c);
      await scrollTo(t, find.textContaining(l10nOf(t).dailyReportTitle('')),
          alignment: 0.5);
    },
  ),
  // 3 Wochenbericht.
  ScreenMotif(tab: 1, act: selectReportDay),
  // 4 Trend mit Wochen-Trend und Prognose.
  ScreenMotif(
    tab: 4,
    act: (t, c) =>
        scrollTo(t, find.text(l10nOf(t).trendWeekTitle), alignment: 0.02),
  ),
  // 5 Jahreswerte und Vergleich mit dem Vorjahr.
  ScreenMotif(
    tab: 3,
    act: (t, c) async {
      await Scrollable.ensureVisible(
          t.element(find.byType(YearlyComparisonCard)),
          alignment: 0.02);
      await settle(t, 4);
    },
  ),
  // 6 Jahres-Tab mit geöffnetem PDF-Export-Menü.
  ScreenMotif(
    tab: 3,
    act: (t, c) async {
      final l10n = AppLocalizations.of(t.element(find.byType(ReportsPage)));
      await t.tap(find.text(l10n.exportPdfShortButton).first);
      await settle(t, 4);
    },
  ),
  // 7 Blatt „Arbeitsorte“ über dem Dashboard; dahinter bleiben Orte und der
  // eingeschaltete Home-Office-Schalter sichtbar. Ohne geöffnete Vorschläge:
  // die Liste öffnet nach oben und verdeckt sonst die eingetragenen Orte.
  ScreenMotif(
    act: (t, c) async {
      await scrollTo(t, find.text(l10nOf(t).overtimeTodayLabel), alignment: 0);
      await t.tap(find.byType(DashboardWorkLocations));
      await settle(t, 6);
    },
  ),
  // 8 wie 1 im Dunkelmodus.
  const ScreenMotif(dark: true),
];

/// Variante B: Primärfarbe, Überschrift oben, darunter der App-Bildschirm
/// mit abgerundeten Ecken und Schatten.
Widget _framed(ui.Image screen, String headline, ColorScheme scheme) {
  const top = 330.0;
  const bottom = 90.0;
  const screenHeight = _height - top - bottom;
  const screenWidth = screenHeight * _width / _height;
  return Directionality(
    textDirection: TextDirection.ltr,
    child: ColoredBox(
      color: scheme.primary,
      child: Stack(
        children: [
          Positioned(
            left: 70,
            right: 70,
            top: 0,
            height: top,
            child: Center(
              // Eine Zeile, zu lange Überschriften werden verkleinert statt
              // umgebrochen (kein „Home-/Office“).
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  headline,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w700,
                    fontSize: 74,
                    color: scheme.onPrimary,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: top,
            left: (_width - screenWidth) / 2,
            width: screenWidth,
            height: screenHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 40,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: RawImage(
                  image: screen,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    await loadScreenFonts();
    await initializeDateFormatting('de', null);
    await initializeDateFormatting('en', null);
  });

  for (final locale in storeHeadlines.keys) {
    for (var i = 0; i < _motifs.length; i++) {
      final number = i + 1;
      testWidgets('$locale $number', (t) async {
        final motif = _motifs[i];
        final screen = await renderAppScreen(t, motif, locale);
        final folder = _storeFolders[locale]!;
        await writePng(t, screen,
            '../fastlane/metadata/android/$folder/images/phoneScreenshots/$number.png');
        if (_headlineOut.isEmpty) return;

        // Variante B als eigenes Bild in Pixeln (dpr 1).
        debugDisableShadows = false;
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = const Size(_width * 1.0, _height * 1.0);
        final key = GlobalKey();
        await t.pumpWidget(RepaintBoundary(
          key: key,
          child: _framed(screen, storeHeadlines[locale]![i],
              AppTheme.lightTheme.colorScheme),
        ));
        await t.pump();
        final framed = exactScreenSize(await captureBoundary(t, key, 1));
        await writePng(t, framed, '$_headlineOut/$folder/$number.png');
        debugDisableShadows = true;
      });
    }
  }
}
