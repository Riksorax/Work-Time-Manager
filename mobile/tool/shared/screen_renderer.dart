// Gemeinsame Hilfen der Bild-Werkzeuge `tool/store_screenshots` (#559) und
// `tool/shorts_frames` (#575): rendert die echten Seiten der App mit dem
// Datensatz aus `store_data.dart` als Bild 1080 × 1920, ohne Android-SDK.
// Die Voreinstellungen von [renderAppScreen] sind die der Store-Screenshots;
// eine Änderung hier ändert deren Bilder (vorher/nachher vergleichen).

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
import 'package:flutter_work_time/data/repositories/work_location_history.dart';
import 'package:flutter_work_time/domain/entities/settings_entity.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/entities/work_profile_entity.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/screens/home_screen.dart';
import 'package:flutter_work_time/presentation/screens/reports_page.dart';
import 'package:flutter_work_time/presentation/state/settings_state.dart';
import 'package:flutter_work_time/presentation/view_models/open_entry_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/reports_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/settings_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test/support/fake_repositories.dart';
import '../store_screenshots/store_data.dart';

/// Bildgröße: Hochformat 9:16 (Play Store und Kurzvideos).
const screenWidth = 1080;
const screenHeight = 1920;

/// Logische Breite des App-Bildschirms (übliches Android-Handy).
const screenLogicalWidth = 412.0;
const screenDpr = screenWidth / screenLogicalWidth;

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

Future<void> loadScreenFonts() async {
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
/// diesem Tab; [page] wählt abweichend davon die Seite der unteren Leiste,
/// 2 = Einstellungen) und eine optionale Aktion vor der Aufnahme.
class ScreenMotif {
  const ScreenMotif({this.tab, this.page, this.dark = false, this.act});

  final int? tab;
  final int? page;
  final bool dark;
  final Future<void> Function(WidgetTester t, ProviderContainer c)? act;
}

Future<void> settle(WidgetTester t, [int frames = 8]) async {
  for (var i = 0; i < frames; i++) {
    await t.pump(const Duration(milliseconds: 150));
  }
}

Future<void> selectReportDay(WidgetTester t, ProviderContainer c) async {
  c.read(reportsViewModelProvider.notifier).selectDate(storeReportDay);
  await settle(t);
}

AppLocalizations l10nOf(WidgetTester t) =>
    AppLocalizations.of(t.element(find.byType(HomeScreen)));

Future<void> scrollTo(WidgetTester t, Finder target,
    {required double alignment}) async {
  await Scrollable.ensureVisible(t.element(target.first), alignment: alignment);
  await settle(t, 4);
}

Future<ui.Image> captureBoundary(
    WidgetTester t, GlobalKey key, double ratio) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  late ui.Image image;
  await t.runAsync(() async {
    image = await boundary.toImage(pixelRatio: ratio);
  });
  return image;
}

/// Zeichnet [src] auf genau [screenWidth] × [screenHeight] Pixel (gleicht
/// Rundungen der Aufnahme aus).
ui.Image exactScreenSize(ui.Image src) {
  if (src.width == screenWidth && src.height == screenHeight) return src;
  final rec = ui.PictureRecorder();
  Canvas(rec).drawImageRect(
    src,
    Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
    const Rect.fromLTWH(0, 0, screenWidth * 1.0, screenHeight * 1.0),
    Paint()..filterQuality = FilterQuality.high,
  );
  return rec.endRecording().toImageSync(screenWidth, screenHeight);
}

Future<void> writePng(WidgetTester t, ui.Image image, String path) async {
  await t.runAsync(() async {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
  });
}

/// Rendert die App (angemeldet, Premium) mit dem Datensatz aus
/// `store_data.dart` und gibt den Bildschirm als Bild zurück.
///
/// Ohne weitere Angaben gilt der Zustand der Store-Screenshots: Uhr
/// [storeNow], laufender Tag aus `storeTodayEntry`, nur das Standard-Profil.
/// [now] stellt die feste Uhr um (gleicher Kalendertag wie [storeNow], der
/// Saldo gilt für dessen Morgen), [entries] ersetzt die Einträge (Saldo und
/// Backend-Antworten rechnen weiter nur mit den Tagen vor [storeToday]),
/// [profiles] die Liste der Arbeitszeit-Profile.
Future<ui.Image> renderAppScreen(
  WidgetTester t,
  ScreenMotif motif,
  String locale, {
  DateTime? now,
  Map<String, WorkEntryEntity>? entries,
  List<WorkProfileEntity> profiles = const [],
}) async {
  final clock = now ?? storeNow;
  final texts = storeTextsFor(locale);
  entries ??= buildStoreEntries(texts);
  final api = StoreApi(entries);
  final balance = api.balance;

  t.view.devicePixelRatio = screenDpr;
  t.view.physicalSize = const Size(screenWidth * 1.0, screenHeight * 1.0);
  t.view.padding = FakeViewPadding.zero;
  t.view.viewPadding = FakeViewPadding.zero;
  addTearDown(t.view.reset);

  // Die Werkzeuge liegen bewusst außerhalb von test/ (laufen nicht in der CI).
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final work = FakeWorkRepository()..store.addAll(entries);
  // Ortsverlauf (Vorschläge im Blatt „Arbeitsorte“) wie in der App aus den
  // gelesenen Einträgen.
  final history = WorkLocationHistory(prefs, userId: _user.id)
    ..record(entries.values);
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
    clockProvider.overrideWithValue(() => clock),
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
    workProfilesProvider.overrideWith((ref) async => profiles),
    versionServiceProvider.overrideWithValue(_NoUpdate()),
    workLocationHistoryProvider.overrideWithValue(history),
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
        home:
            HomeScreen(initialIndex: motif.page ?? (motif.tab == null ? 0 : 1)),
      ),
    ),
  ));
  await settle(t);
  if (motif.act != null) await motif.act!(t, container);
  await settle(t, 2);

  final screen = exactScreenSize(await captureBoundary(t, key, screenDpr));
  debugDisableShadows = true;

  await t.pumpWidget(const SizedBox.shrink());
  container.dispose();
  await t.pump(const Duration(seconds: 2));
  return screen;
}
