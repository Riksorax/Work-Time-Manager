import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/clock_provider.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/providers/subscription_provider.dart';
import 'package:flutter_work_time/domain/entities/settings_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/screens/reports_page.dart';
import 'package:flutter_work_time/presentation/state/reports_state.dart';
import 'package:flutter_work_time/presentation/state/settings_state.dart';
import 'package:flutter_work_time/presentation/view_models/reports_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/settings_view_model.dart';
import 'package:flutter_work_time/presentation/widgets/edit_target_hours_modal.dart';
import 'package:flutter_work_time/presentation/widgets/edit_timezone_modal.dart';
import 'package:flutter_work_time/presentation/widgets/edit_vacation_days_modal.dart';
import 'package:flutter_work_time/presentation/widgets/edit_work_entry_modal.dart';
import 'package:flutter_work_time/presentation/widgets/edit_workdays_modal.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;

/// Edge-to-Edge (#468): Bottom-Sheets muessen ihren Inhalt oberhalb der
/// Navigationsleiste bzw. der Tastatur halten. Feste MediaQuery-Werte,
/// keine Datums-/Zeitzonenabhaengigkeit.
class _FakeSettingsViewModel extends SettingsViewModel {
  @override
  AsyncValue<SettingsState> build() => const AsyncValue.data(
        SettingsState(
            settings: SettingsEntity(), overtimeBalance: Duration.zero),
      );
}

class _FakeReportsViewModel extends ReportsViewModel {
  final ReportsState initialState;
  _FakeReportsViewModel(this.initialState);

  @override
  ReportsState build() => initialState;

  @override
  Duration getEffectiveDailyTargetForDate(DateTime date) =>
      const Duration(hours: 8);

  @override
  WorkEntryEntity applyBreakCalculation(WorkEntryEntity entry) => entry;

  @override
  void loadCurrentMonthData() {}

  @override
  void selectDate(DateTime selected) {}
}

const _screenHeight = 800.0;
const _navBar = 34.0;
const _keyboard = 300.0;

/// Navigationsleiste ohne Tastatur.
const _withNavBar = MediaQueryData(
  padding: EdgeInsets.only(bottom: _navBar),
  viewPadding: EdgeInsets.only(bottom: _navBar),
);

/// Tastatur sichtbar: Flutter zieht die Tastatur vom `padding` ab, das
/// `viewPadding` bleibt.
const _withKeyboard = MediaQueryData(
  viewInsets: EdgeInsets.only(bottom: _keyboard),
  viewPadding: EdgeInsets.only(bottom: _navBar),
);

void main() {
  late SharedPreferences prefs;

  setUpAll(() async {
    await initializeDateFormatting('de', null);
    tz_data.initializeTimeZones();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> openSheet(
    WidgetTester tester,
    MediaQueryData insets,
    void Function(BuildContext) open, {
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = const Size(400, _screenHeight);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clockProvider.overrideWithValue(() => DateTime(2026, 10, 5, 12)),
          sharedPreferencesProvider.overrideWithValue(prefs),
          isPremiumProvider.overrideWithValue(false),
          settingsViewModelProvider
              .overrideWith(() => _FakeSettingsViewModel()),
          ...overrides,
        ],
        child: MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: insets.padding,
              viewPadding: insets.viewPadding,
              viewInsets: insets.viewInsets,
            ),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => open(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  double bottomOf(WidgetTester tester, Finder finder) =>
      tester.getBottomLeft(finder).dy;

  /// Scrollt die (erste) Liste im Sheet ans Ende.
  Future<void> scrollListToEnd(WidgetTester tester) async {
    final scrollable = tester.state<ScrollableState>(find
        .descendant(
            of: find.byType(ListView).first, matching: find.byType(Scrollable))
        .first);
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pumpAndSettle();
  }

  /// Unterkante der Schaltflaeche, die den Text [label] traegt.
  Finder buttonWithText(String label) => find.ancestor(
      of: find.text(label), matching: find.bySubtype<ButtonStyleButton>());

  final simpleSheets = <String, void Function(BuildContext)>{
    'Arbeitstage': (c) => showEditWorkdaysModal(c, const [1, 2, 3, 4, 5]),
    'Urlaubsanspruch': (c) => showEditVacationDaysModal(c, 30),
    'Soll-Stunden': (c) => showEditTargetHoursModal(c, 40),
  };

  for (final entry in simpleSheets.entries) {
    group('Sheet ${entry.key}', () {
      testWidgets('Speichern liegt oberhalb der Navigationsleiste',
          (tester) async {
        await openSheet(tester, _withNavBar, entry.value);
        final save = buttonWithText('Speichern');
        expect(save, findsOneWidget);
        expect(
            bottomOf(tester, save), lessThanOrEqualTo(_screenHeight - _navBar));
      });

      testWidgets('Speichern liegt oberhalb der Tastatur', (tester) async {
        await openSheet(tester, _withKeyboard, entry.value);
        final save = buttonWithText('Speichern');
        expect(save, findsOneWidget);
        expect(bottomOf(tester, save),
            lessThanOrEqualTo(_screenHeight - _keyboard));
      });
    });
  }

  group('Sheet Zeitzone', () {
    Future<void> scrollToEnd(WidgetTester tester) async {
      await scrollListToEnd(tester);
      await tester.pumpAndSettle();
    }

    testWidgets('letzter Eintrag liegt oberhalb der Navigationsleiste',
        (tester) async {
      await openSheet(
          tester, _withNavBar, (c) => showEditTimezoneModal(c, null));
      await scrollToEnd(tester);
      expect(bottomOf(tester, find.byType(ListTile).last),
          lessThanOrEqualTo(_screenHeight - _navBar));
    });
  });

  group('Sheet Eintrag bearbeiten', () {
    final entry = WorkEntryEntity(
      id: '2026-10-05',
      date: DateTime(2026, 10, 5),
      workStart: DateTime(2026, 10, 5, 8),
      workEnd: DateTime(2026, 10, 5, 16),
    );

    testWidgets('Speichern liegt oberhalb der Navigationsleiste',
        (tester) async {
      await openSheet(
        tester,
        _withNavBar,
        (c) => showModalBottomSheet(
          context: c,
          isScrollControlled: true,
          builder: (_) => EditWorkEntryModal(workEntry: entry),
        ),
      );
      final save = buttonWithText('Änderungen speichern');
      expect(save, findsOneWidget);
      expect(
          bottomOf(tester, save), lessThanOrEqualTo(_screenHeight - _navBar));
    });
  });

  group('Sheet Tageseintraege', () {
    final day = DateTime(2026, 10, 5);
    final entries = [
      for (var i = 0; i < 12; i++)
        WorkEntryEntity(
          id: '2026-10-05',
          date: day,
          workStart: DateTime(2026, 10, 5, 8),
          workEnd: DateTime(2026, 10, 5, 16),
        ),
    ];
    final reportsState = ReportsState(
      isLoading: false,
      focusedDay: day,
      selectedDay: day,
      selectedMonth: DateTime(2026, 10),
      workEntries: const {},
      dailyReportState: DailyReportState(
        entries: entries,
        workTime: Duration.zero,
        breakTime: Duration.zero,
        totalTime: Duration.zero,
        overtime: Duration.zero,
      ),
    );

    testWidgets('letzter Eintrag liegt oberhalb der Navigationsleiste',
        (tester) async {
      await openSheet(
        tester,
        _withNavBar,
        (c) => showModalBottomSheet(
          context: c,
          isScrollControlled: true,
          builder: (_) => DayEntriesBottomSheet(date: day),
        ),
        overrides: [
          reportsViewModelProvider
              .overrideWith(() => _FakeReportsViewModel(reportsState)),
        ],
      );
      await scrollListToEnd(tester);
      await tester.pumpAndSettle();
      expect(bottomOf(tester, find.byType(Card).last),
          lessThanOrEqualTo(_screenHeight - _navBar));
    });
  });
}
