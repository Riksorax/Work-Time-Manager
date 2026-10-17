import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/providers/subscription_provider.dart';
import 'package:flutter_work_time/domain/entities/bundesland.dart';
import 'package:flutter_work_time/domain/entities/settings_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/screens/reports_page.dart';
import 'package:flutter_work_time/presentation/state/reports_state.dart';
import 'package:flutter_work_time/presentation/state/settings_state.dart';
import 'package:flutter_work_time/presentation/view_models/reports_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/settings_view_model.dart';

// Gibt Duration.zero für jeden Tag zurück → alle Tage sind "Zusatztage"
class FakeReportsViewModel extends ReportsViewModel {
  final ReportsState initialState;

  FakeReportsViewModel(this.initialState);

  @override
  ReportsState build() => initialState;

  @override
  Duration getEffectiveDailyTargetForDate(DateTime date) => Duration.zero;

  @override
  WorkEntryEntity applyBreakCalculation(WorkEntryEntity entry) => entry;

  @override
  void loadCurrentMonthData() {}
}

class FakeSettingsViewModel extends SettingsViewModel {
  final Bundesland? bundesland;

  FakeSettingsViewModel({this.bundesland});

  @override
  AsyncValue<SettingsState> build() => AsyncValue.data(
        SettingsState(
            settings: SettingsEntity(bundesland: bundesland),
            overtimeBalance: Duration.zero),
      );
}

@GenerateMocks([])
void main() {
  setUpAll(() async {
    await initializeDateFormatting('de_DE', null);
    await initializeDateFormatting('en', null);
  });

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets(
      'DailyReportView shows Zusatztag with no daily target and positive overtime',
      (WidgetTester tester) async {
    final saturdayEntry = WorkEntryEntity(
      id: '6',
      date: DateTime(2023, 10, 28),
      workStart: DateTime(2023, 10, 28, 8, 0),
      workEnd: DateTime(2023, 10, 28, 14, 0),
    );

    // State mit Samstag (Zusatztag) vorgebaut — kein async Loading nötig
    final fakeState = ReportsState(
      isLoading: false,
      focusedDay: DateTime(2023, 10, 28),
      selectedDay: DateTime(2023, 10, 28),
      selectedMonth: DateTime(2023, 10),
      workEntries: const {},
      dailyReportState: DailyReportState(
        entries: [saturdayEntry],
        workTime: const Duration(hours: 6),
        breakTime: Duration.zero,
        totalTime: const Duration(hours: 6),
        overtime: const Duration(hours: 6),
      ),
    );

    // Großes Fenster damit ListView alles auf einmal rendert
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          isPremiumProvider.overrideWithValue(false),
          settingsViewModelProvider.overrideWith(() => FakeSettingsViewModel()),
          reportsViewModelProvider
              .overrideWith(() => FakeReportsViewModel(fakeState)),
        ],
        child: MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ReportsPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Zusatztag-Label sichtbar (getEffectiveDailyTargetForDate gibt Duration.zero zurück)
    expect(find.text('Soll (Zusatztag):'), findsOneWidget);
    // Soll-Wert ist '-' (kein Sollwert für Zusatztag)
    expect(find.text('-'), findsWidgets);
    // Überstunden: 6h Arbeit, kein Soll → +06:00
    expect(find.text('+06:00'), findsOneWidget);
  });

  Future<void> pumpHolidayCalendar(
    WidgetTester tester, {
    required Locale locale,
    Bundesland? bundesland,
  }) async {
    final fakeState = ReportsState(
      isLoading: false,
      focusedDay: DateTime(2026, 10, 3),
      selectedDay: DateTime(2026, 10, 3),
      selectedMonth: DateTime(2026, 10),
      workEntries: const {},
    );

    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          isPremiumProvider.overrideWithValue(false),
          settingsViewModelProvider.overrideWith(
              () => FakeSettingsViewModel(bundesland: bundesland)),
          reportsViewModelProvider
              .overrideWith(() => FakeReportsViewModel(fakeState)),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ReportsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Calendar holiday tooltip and semantics are English in en (#369)',
      (tester) async {
    final handle = tester.ensureSemantics();
    await pumpHolidayCalendar(tester,
        locale: const Locale('en'), bundesland: Bundesland.bayern);

    expect(find.byTooltip('German Unity Day'), findsOneWidget);
    expect(find.byTooltip('Tag der Deutschen Einheit'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('German Unity Day')), findsWidgets);
    expect(find.bySemanticsLabel(RegExp('Tag der Deutschen Einheit')),
        findsNothing);
    handle.dispose();
  });

  testWidgets('Calendar holiday tooltip and semantics are German in de (#369)',
      (tester) async {
    final handle = tester.ensureSemantics();
    await pumpHolidayCalendar(tester,
        locale: const Locale('de'), bundesland: Bundesland.bayern);

    expect(find.byTooltip('Tag der Deutschen Einheit'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Tag der Deutschen Einheit')),
        findsWidgets);
    handle.dispose();
  });

  testWidgets('Calendar shows no holiday tooltip without Bundesland (#369)',
      (tester) async {
    await pumpHolidayCalendar(tester, locale: const Locale('en'));

    expect(find.byTooltip('German Unity Day'), findsNothing);
    expect(find.byTooltip('Tag der Deutschen Einheit'), findsNothing);
  });

  // Home-Office-Markierung (#277): Haus-Icon im Kalender plus Semantics-Suffix,
  // Chip in der Tagesliste. Feste Daten (Sa 2026-10-03, Mo 2026-10-05).
  Future<void> pumpHomeOffice(
    WidgetTester tester, {
    required Locale locale,
    Set<DateTime> homeOfficeDays = const {},
    List<WorkEntryEntity> entries = const [],
  }) async {
    final fakeState = ReportsState(
      isLoading: false,
      focusedDay: DateTime(2026, 10, 5),
      selectedDay: DateTime(2026, 10, 5),
      selectedMonth: DateTime(2026, 10),
      workEntries: const {},
      homeOfficeDays: homeOfficeDays,
      dailyReportState: DailyReportState(
        entries: entries,
        workTime: Duration.zero,
        breakTime: Duration.zero,
        totalTime: Duration.zero,
        overtime: Duration.zero,
      ),
    );

    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          isPremiumProvider.overrideWithValue(false),
          settingsViewModelProvider.overrideWith(() => FakeSettingsViewModel()),
          reportsViewModelProvider
              .overrideWith(() => FakeReportsViewModel(fakeState)),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ReportsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  WorkEntryEntity homeEntry({
    bool homeOffice = true,
    WorkEntryType type = WorkEntryType.work,
  }) =>
      WorkEntryEntity(
        id: '2026-10-05',
        date: DateTime(2026, 10, 5),
        workStart: DateTime(2026, 10, 5, 8),
        workEnd: DateTime(2026, 10, 5, 16),
        type: type,
        isHomeOffice: homeOffice,
      );

  for (final (locale, suffix) in [
    ('de', ', Home-Office-Tag'),
    ('en', ', home office day'),
  ]) {
    testWidgets('Kalender: Home-Office-Tag zeigt Icon und Semantics ($locale)',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHomeOffice(tester,
          locale: Locale(locale), homeOfficeDays: {DateTime(2026, 10, 5)});

      expect(find.byKey(const ValueKey('homeOfficeDayIcon')), findsOneWidget);
      expect(
          find.bySemanticsLabel(RegExp(RegExp.escape(suffix))), findsOneWidget);
      handle.dispose();
    });

    testWidgets(
        'Kalender: Tag ohne Flag zeigt weder Icon noch Suffix ($locale)',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHomeOffice(tester, locale: Locale(locale));

      expect(find.byKey(const ValueKey('homeOfficeDayIcon')), findsNothing);
      expect(
          find.bySemanticsLabel(RegExp(RegExp.escape(suffix))), findsNothing);
      handle.dispose();
    });
  }

  testWidgets('Tagesliste: Chip bei Home-Office-Eintrag (de und en)',
      (tester) async {
    await pumpHomeOffice(tester,
        locale: const Locale('de'), entries: [homeEntry()]);
    expect(find.widgetWithText(Chip, 'Home-Office'), findsOneWidget);
  });

  testWidgets('Tagesliste: Chip englisch', (tester) async {
    await pumpHomeOffice(tester,
        locale: const Locale('en'), entries: [homeEntry()]);
    expect(find.widgetWithText(Chip, 'Home office'), findsOneWidget);
  });

  testWidgets('Tagesliste: kein Chip ohne Flag oder bei Typ Urlaub',
      (tester) async {
    await pumpHomeOffice(tester,
        locale: const Locale('de'), entries: [homeEntry(homeOffice: false)]);
    expect(find.byType(Chip), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Tagesliste: kein Chip bei Typ Urlaub trotz Flag',
      (tester) async {
    await pumpHomeOffice(tester,
        locale: const Locale('de'),
        entries: [homeEntry(type: WorkEntryType.vacation)]);
    expect(find.byType(Chip), findsNothing);
  });
}
