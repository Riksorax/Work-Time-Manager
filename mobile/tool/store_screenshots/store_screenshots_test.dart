// Play-Store-Screenshots aus den echten Seiten der App (#559).
//
// Aufruf (aus `mobile/`, ohne Android-SDK):
//
//   flutter test tool/store_screenshots
//
// Schreibt Variante B („mit Überschrift“) nach
// `../fastlane/metadata/android/{de-DE,en-US}/images/phoneScreenshots/1.png … 8.png`.
// Mit `--dart-define=STORE_PLAIN_OUT=<ordner>` zusätzlich Variante A
// („schlicht“, nur der App-Bildschirm) nach `<ordner>/{de-DE,en-US}/`.
// Liegt außerhalb von `test/` und läuft deshalb nicht im normalen
// `flutter test` mit. Details: `mobile/CLAUDE.md`, „Store-Screenshots (#559)“.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/clock_provider.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/providers/subscription_provider.dart';
import 'package:flutter_work_time/core/services/version_service.dart';
import 'package:flutter_work_time/core/theme/app_theme.dart';
import 'package:flutter_work_time/domain/entities/settings_entity.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';
import 'package:flutter_work_time/domain/entities/work_profile_entity.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/screens/home_screen.dart';
import 'package:flutter_work_time/presentation/screens/reports_page.dart';
import 'package:flutter_work_time/presentation/state/settings_state.dart';
import 'package:flutter_work_time/presentation/view_models/open_entry_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/reports_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/settings_view_model.dart';
import 'package:flutter_work_time/presentation/widgets/yearly_comparison_card.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test/support/fake_repositories.dart';
import 'headlines.dart';
import 'store_data.dart';

/// Bildgröße im Play Store: Hochformat 9:16.
const _width = 1080;
const _height = 1920;

/// Logische Breite des App-Bildschirms (übliches Android-Handy).
const _logicalWidth = 412.0;
const _dpr = _width / _logicalWidth;

const _plainOut = String.fromEnvironment('STORE_PLAIN_OUT');

const _storeFolders = {'de': 'de-DE', 'en': 'en-US'};

/// Roboto und Material-Icons aus dem Flutter-SDK, damit Text und Icons wie
/// auf dem Gerät erscheinen (Widget-Tests nutzen sonst die Ahem-Testschrift).
Directory _fontsDir() {
  final root = Platform.environment['FLUTTER_ROOT'];
  final candidates = [
    if (root != null) '$root/bin/cache/artifacts/material_fonts',
    // flutter_tester liegt unter bin/cache/artifacts/engine/<plattform>/.
    '${File(Platform.resolvedExecutable).parent.parent.parent.path}'
        '/material_fonts',
  ];
  for (final c in candidates) {
    if (File('$c/Roboto-Regular.ttf').existsSync()) return Directory(c);
  }
  throw StateError('Roboto nicht gefunden (gesucht: $candidates)');
}

Future<void> _loadFonts() async {
  final dir = _fontsDir().path;
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      final bytes = File('$dir/$f').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  await family('Roboto', [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Light.ttf',
    'Roboto-Italic.ttf',
    'Roboto-MediumItalic.ttf',
  ]);
  await family('MaterialIcons', ['MaterialIcons-Regular.otf']);
}

const _user = UserEntity(id: 'store-demo', email: 'demo@example.com');

class _Settings extends SettingsViewModel {
  _Settings(this._state);
  final SettingsState _state;

  @override
  AsyncValue<SettingsState> build() => AsyncValue.data(_state);
}

class _Open extends OpenEntryViewModel {
  @override
  OpenEntryState build() => const OpenEntryState();
}

class _NoUpdate extends Fake implements VersionService {
  @override
  Future<UpdateInfo?> checkForRequiredUpdate() async => null;
}

class _StoreSettingsRepository extends FakeSettingsRepository {
  _StoreSettingsRepository(this.locale) {
    showWorkLocationOnDashboard = true;
  }

  final String locale;

  @override
  String getLocale() => locale;

  @override
  int getVacationDaysPerYear() => storeVacationDaysPerYear;
}

/// Ein Motiv: Startseite der App ([tab] null = Dashboard, sonst Berichte mit
/// diesem Tab) und eine optionale Aktion vor der Aufnahme.
class _Motif {
  const _Motif({this.tab, this.dark = false, this.act});

  final int? tab;
  final bool dark;
  final Future<void> Function(WidgetTester t, ProviderContainer c)? act;
}

Future<void> _settle(WidgetTester t, [int frames = 8]) async {
  for (var i = 0; i < frames; i++) {
    await t.pump(const Duration(milliseconds: 150));
  }
}

Future<void> _selectReportDay(WidgetTester t, ProviderContainer c) async {
  c.read(reportsViewModelProvider.notifier).selectDate(storeReportDay);
  await _settle(t);
}

AppLocalizations _l10n(WidgetTester t) =>
    AppLocalizations.of(t.element(find.byType(HomeScreen)));

Future<void> _scrollTo(WidgetTester t, Finder target,
    {required double alignment}) async {
  await Scrollable.ensureVisible(t.element(target.first), alignment: alignment);
  await _settle(t, 4);
}

final _motifs = <_Motif>[
  // 1 Dashboard mit laufendem Timer.
  const _Motif(),
  // 2 Tagesbericht mit Kalender.
  _Motif(
    tab: 0,
    act: (t, c) async {
      await _selectReportDay(t, c);
      await _scrollTo(t, find.textContaining(_l10n(t).dailyReportTitle('')),
          alignment: 0.5);
    },
  ),
  // 3 Wochenbericht.
  _Motif(tab: 1, act: _selectReportDay),
  // 4 Trend mit Wochen-Trend und Prognose.
  _Motif(
    tab: 4,
    act: (t, c) =>
        _scrollTo(t, find.text(_l10n(t).trendWeekTitle), alignment: 0.02),
  ),
  // 5 Jahreswerte und Vergleich mit dem Vorjahr.
  _Motif(
    tab: 3,
    act: (t, c) async {
      await Scrollable.ensureVisible(
          t.element(find.byType(YearlyComparisonCard)),
          alignment: 0.02);
      await _settle(t, 4);
    },
  ),
  // 6 Jahres-Tab mit geöffnetem PDF-Export-Menü.
  _Motif(
    tab: 3,
    act: (t, c) async {
      final l10n = AppLocalizations.of(t.element(find.byType(ReportsPage)));
      await t.tap(find.text(l10n.exportPdfShortButton).first);
      await _settle(t, 4);
    },
  ),
  // 7 Dashboard: Arbeitsorte und Home-Office.
  _Motif(
    act: (t, c) async {
      await _scrollTo(t, find.text(_l10n(t).startTimeLabel), alignment: 0.02);
    },
  ),
  // 8 wie 1 im Dunkelmodus.
  const _Motif(dark: true),
];

Future<ui.Image> _capture(WidgetTester t, GlobalKey key, double ratio) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  late ui.Image image;
  await t.runAsync(() async {
    image = await boundary.toImage(pixelRatio: ratio);
  });
  return image;
}

/// Zeichnet [src] auf genau [_width] × [_height] Pixel (gleicht Rundungen
/// der Aufnahme aus).
ui.Image _exact(ui.Image src) {
  if (src.width == _width && src.height == _height) return src;
  final rec = ui.PictureRecorder();
  Canvas(rec).drawImageRect(
    src,
    Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
    const Rect.fromLTWH(0, 0, _width * 1.0, _height * 1.0),
    Paint()..filterQuality = FilterQuality.high,
  );
  return rec.endRecording().toImageSync(_width, _height);
}

Future<void> _writePng(WidgetTester t, ui.Image image, String path) async {
  await t.runAsync(() async {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
  });
}

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
    await _loadFonts();
    await initializeDateFormatting('de', null);
    await initializeDateFormatting('en', null);
  });

  for (final locale in storeHeadlines.keys) {
    for (var i = 0; i < _motifs.length; i++) {
      final number = i + 1;
      testWidgets('$locale $number', (t) async {
        final motif = _motifs[i];
        final screen = await _renderScreen(t, motif, locale);
        final folder = _storeFolders[locale]!;
        if (_plainOut.isNotEmpty) {
          await _writePng(t, screen, '$_plainOut/$folder/$number.png');
        }

        // Variante B als eigenes Bild in Pixeln (dpr 1).
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = const Size(_width * 1.0, _height * 1.0);
        final key = GlobalKey();
        await t.pumpWidget(RepaintBoundary(
          key: key,
          child: _framed(screen, storeHeadlines[locale]![i],
              AppTheme.lightTheme.colorScheme),
        ));
        await t.pump();
        final framed = _exact(await _capture(t, key, 1));
        await _writePng(t, framed,
            '../fastlane/metadata/android/$folder/images/phoneScreenshots/$number.png');
        debugDisableShadows = true;
      });
    }
  }
}

Future<ui.Image> _renderScreen(
    WidgetTester t, _Motif motif, String locale) async {
  final texts = storeTextsFor(locale);
  final entries = buildStoreEntries(texts);
  final api = StoreApi(entries);
  final balance = api.balance;

  t.view.devicePixelRatio = _dpr;
  t.view.physicalSize = const Size(_width * 1.0, _height * 1.0);
  t.view.padding = FakeViewPadding.zero;
  t.view.viewPadding = FakeViewPadding.zero;
  addTearDown(t.view.reset);

  // Das Werkzeug liegt bewusst außerhalb von test/ (läuft nicht in der CI mit).
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final work = FakeWorkRepository()..store.addAll(entries);
  final overtime = FakeOvertimeRepository()
    ..stored = balance
    ..lastUpdate = storeToday;
  final settings = SettingsEntity(
    bundesland: storeBundesland,
    use24HourFormat: locale != 'en',
    locale: locale,
    vacationDaysPerYear: storeVacationDaysPerYear,
    showWorkLocationOnDashboard: true,
  );

  final container = ProviderContainer(overrides: [
    clockProvider.overrideWithValue(() => storeNow),
    sharedPreferencesProvider.overrideWithValue(prefs),
    workRepositoryProvider.overrideWithValue(work),
    overtimeRepositoryProvider.overrideWithValue(overtime),
    settingsRepositoryProvider
        .overrideWithValue(_StoreSettingsRepository(locale)),
    settingsViewModelProvider.overrideWith(() =>
        _Settings(SettingsState(settings: settings, overtimeBalance: balance))),
    openEntryViewModelProvider.overrideWith(_Open.new),
    authStateProvider.overrideWithValue(const AsyncValue.data(_user)),
    isPremiumProvider.overrideWithValue(true),
    activeEntitlementProvider.overrideWithValue(null),
    apiClientProvider.overrideWithValue(api),
    workProfilesProvider
        .overrideWith((ref) async => const <WorkProfileEntity>[]),
    versionServiceProvider.overrideWithValue(_NoUpdate()),
  ]);
  if (motif.tab != null) {
    container.read(pendingReportTabIndexProvider.notifier).state = motif.tab;
  }

  debugDisableShadows = false;
  final key = GlobalKey();
  await t.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: motif.dark ? ThemeMode.dark : ThemeMode.light,
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomeScreen(initialIndex: motif.tab == null ? 0 : 1),
      ),
    ),
  ));
  await _settle(t);
  if (motif.act != null) await motif.act!(t, container);
  await _settle(t, 2);

  final screen = _exact(await _capture(t, key, _dpr));

  await t.pumpWidget(const SizedBox.shrink());
  container.dispose();
  await t.pump(const Duration(seconds: 2));
  return screen;
}
