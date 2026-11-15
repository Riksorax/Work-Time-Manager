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
import 'package:flutter_work_time/core/utils/api_errors.dart';
import 'package:flutter_work_time/data/datasources/remote/api_client.dart';
import 'package:flutter_work_time/domain/entities/break_entity.dart';
import 'package:flutter_work_time/domain/entities/settings_entity.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/entities/work_profile_entity.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/screens/reports_page.dart';
import 'package:flutter_work_time/presentation/state/settings_state.dart';
import 'package:flutter_work_time/presentation/view_models/settings_view_model.dart';

import '../../support/fake_repositories.dart';

/// #551: Die Zeilen von Wochen- und Monatsbericht zeigen netto (ohne Pausen),
/// die Überschriften tragen keinen Zusatz „(inkl. Pausen)“ mehr. Echtes
/// ViewModel über In-Memory-Repositories, API offline (lokale kanonische
/// Rechnung, dieselbe Regel wie das Backend). Feste Daten im Oktober 2026,
/// keine Abhängigkeit von heutigem Datum oder Zeitzone. Echte Roboto-Schrift
/// aus dem Flutter-SDK wie `reports_page_overflow_320_test`, damit ein
/// Überlauf bei 320/360 px sichtbar würde.
///
/// 40 h an Mo–Fr (Tagessoll 8:00):
/// - Do 01.10. (KW 40) 08:00–17:00, Pausen 45 + 15 min: netto 8:00
/// - Mo 05.10. (KW 41) 08:00–16:45, Pause 45 min: netto 8:00
/// - Di 06.10. Urlaub: 8:00
/// - Fr 09.10. läuft noch (kein Ende), Pause 10:00–10:30 abgeschlossen:
///   brutto 0, netto −0:30 (nicht gekappt, Zeile „—“)
///
/// Woche KW 41: netto 16:00 − 0:30 = 15:30. Monat: 8:00 + 15:30 = 23:30.
class _Settings extends SettingsViewModel {
  @override
  AsyncValue<SettingsState> build() => const AsyncValue.data(SettingsState(
      settings: SettingsEntity(), overtimeBalance: Duration.zero));
}

class _NoProfile extends ActiveWorkProfileIdNotifier {
  @override
  String? build() => null;
}

class _OfflineApi extends Fake implements ApiClient {
  @override
  Future<Map<String, dynamic>> getDailyReport(int y, int m, int d,
          {String? profileId}) =>
      throw const ApiException('getDailyReport', 503);
  @override
  Future<Map<String, dynamic>> getWeeklyReport(int y, int m, int d,
          {String? profileId}) =>
      throw const ApiException('getWeeklyReport', 503);
  @override
  Future<Map<String, dynamic>> getMonthlyReport(int y, int m,
          {String? profileId}) =>
      throw const ApiException('getMonthlyReport', 503);
}

BreakEntity _break(int day, int h, int m, int minutes) => BreakEntity(
      id: 'b$day-$h',
      name: 'Pause',
      start: DateTime(2026, 10, day, h, m),
      end: DateTime(2026, 10, day, h, m + minutes),
    );

List<WorkEntryEntity> _entries() => [
      WorkEntryEntity(
        id: '2026-10-01',
        date: DateTime(2026, 10, 1),
        workStart: DateTime(2026, 10, 1, 8),
        workEnd: DateTime(2026, 10, 1, 17),
        breaks: [_break(1, 12, 0, 45), _break(1, 15, 0, 15)],
      ),
      WorkEntryEntity(
        id: '2026-10-05',
        date: DateTime(2026, 10, 5),
        workStart: DateTime(2026, 10, 5, 8),
        workEnd: DateTime(2026, 10, 5, 16, 45),
        breaks: [_break(5, 12, 0, 45)],
      ),
      WorkEntryEntity(
          id: '2026-10-06',
          date: DateTime(2026, 10, 6),
          type: WorkEntryType.vacation),
      WorkEntryEntity(
        id: '2026-10-09',
        date: DateTime(2026, 10, 9),
        workStart: DateTime(2026, 10, 9, 8),
        breaks: [_break(9, 10, 0, 30)],
      ),
    ];

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
  ]) {
    final bytes = File('${dir.path}/$f').readAsBytesSync();
    roboto.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons');
  final bytes = File('${dir.path}/MaterialIcons-Regular.otf').readAsBytesSync();
  icons.addFont(Future.value(ByteData.view(bytes.buffer)));
  await icons.load();
}

const _user = UserEntity(id: 'u1', email: 'a@b.c');

void main() {
  setUpAll(() async {
    await _loadFonts();
    await initializeDateFormatting('de', null);
    await initializeDateFormatting('en', null);
  });

  late ProviderContainer container;

  Future<void> pump(
    WidgetTester tester, {
    required int tab,
    String locale = 'de',
    double width = 412,
  }) async {
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final work = FakeWorkRepository();
    for (final e in _entries()) {
      work.store[e.id] = e;
    }
    container = ProviderContainer(overrides: [
      clockProvider.overrideWithValue(() => DateTime(2026, 10, 9, 18)),
      sharedPreferencesProvider.overrideWithValue(prefs),
      workRepositoryProvider.overrideWithValue(work),
      overtimeRepositoryProvider.overrideWithValue(FakeOvertimeRepository()),
      settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
      settingsViewModelProvider.overrideWith(_Settings.new),
      activeWorkProfileIdProvider.overrideWith(_NoProfile.new),
      workProfilesProvider
          .overrideWith((ref) async => [WorkProfileEntity.defaultProfile()]),
      authStateProvider.overrideWithValue(const AsyncValue.data(_user)),
      isPremiumProvider.overrideWithValue(true),
      apiClientProvider.overrideWithValue(_OfflineApi()),
    ]);
    container.read(pendingReportTabIndexProvider.notifier).state = tab;
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ReportsPage(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Baut den Baum ab und lässt die Timer der Berichtsseite auslaufen.
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump(const Duration(seconds: 6));
  }

  /// Text der `trailing`-Spalte aller Zeilen (ListTile) in Reihenfolge.
  List<String> rowValues(WidgetTester tester) => [
        for (final tile in tester.widgetList<ListTile>(find.byType(ListTile)))
          if (tile.trailing case final Text t) t.data!,
      ];

  group('Wochen-Tab', () {
    testWidgets('Tageszeilen netto, offener Tag mit Pause als „—“',
        (tester) async {
      await pump(tester, tab: 1);

      expect(find.text('Arbeitszeit pro Tag:'), findsOneWidget);
      expect(find.textContaining('inkl. Pausen'), findsNothing);
      // Gesamte Arbeitszeit netto (Backend-Regel, offener Tag zählt −0:30).
      // Die sichtbaren Zeilen ergeben 16:00, weil „—“ die −0:30 verbirgt.
      expect(find.text('15:30:00'), findsOneWidget);
      expect(rowValues(tester), ['8:00:00', '8:00:00', '—']);
      expect(find.text('8:45:00'), findsNothing); // brutto Montag
      await finish(tester);
    });

    testWidgets('Englisch: Überschrift ohne Zusatz', (tester) async {
      await pump(tester, tab: 1, locale: 'en');
      expect(find.text('Work time per day:'), findsOneWidget);
      expect(find.textContaining('incl. breaks'), findsNothing);
      expect(rowValues(tester), ['8:00:00', '8:00:00', '—']);
      await finish(tester);
    });
  });

  group('Monats-Tab', () {
    testWidgets(
        'Wochen- und Tageszeilen netto, Wochen summieren zur Gesamtzeit',
        (tester) async {
      await pump(tester, tab: 2);

      expect(find.text('Wochenübersicht:'), findsOneWidget);
      expect(find.text('Tagesübersicht:'), findsOneWidget);
      expect(find.textContaining('inkl. Pausen'), findsNothing);
      expect(find.text('23:30:00'), findsOneWidget); // Gesamte Arbeitszeit
      // KW 40: 8:00, KW 41: 15:30 → Summe 23:30 = Gesamte Arbeitszeit.
      // Tage: 01.10., 05.10., 06.10. (Urlaub), 09.10. (offen, −0:30 → „—“).
      expect(rowValues(tester), [
        '8:00:00',
        '15:30:00',
        '8:00:00',
        '8:00:00',
        '8:00:00',
        '—',
      ]);
      await finish(tester);
    });

    testWidgets('Englisch: Überschriften ohne Zusatz', (tester) async {
      await pump(tester, tab: 2, locale: 'en');
      expect(find.text('Week overview:'), findsOneWidget);
      expect(find.text('Day overview:'), findsOneWidget);
      expect(find.textContaining('incl. breaks'), findsNothing);
      await finish(tester);
    });
  });

  for (final width in [320.0, 360.0]) {
    for (final locale in ['de', 'en']) {
      for (final tab in [1, 2]) {
        testWidgets(
            '${tab == 1 ? 'Wochen' : 'Monats'}-Tab ohne Overflow '
            '(${width.toInt()} px, $locale)', (tester) async {
          await pump(tester, tab: tab, locale: locale, width: width);
          expect(rowValues(tester), isNotEmpty);
          expect(tester.takeException(), isNull);
          await finish(tester);
        });
      }
    }
  }
}
