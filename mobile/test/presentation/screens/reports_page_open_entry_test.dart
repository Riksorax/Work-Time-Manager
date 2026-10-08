import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// #404: Offene Einträge in den Reports. Feste Uhr (Mo 2026-10-05 12:00),
/// alle Zeiten lokal konstruiert, keine Abhängigkeit von Datum/Zeitzone.
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
}

class _FakeSettingsViewModel extends SettingsViewModel {
  @override
  AsyncValue<SettingsState> build() => const AsyncValue.data(
        SettingsState(
            settings: SettingsEntity(), overtimeBalance: Duration.zero),
      );
}

const _hintDe =
    'Kein Ende erfasst – dieser Eintrag zählt nicht in die Auswertung.';
const _hintEn = 'No end recorded – this entry is not counted in the reports.';

void main() {
  final now = DateTime(2026, 10, 5, 12);
  late SharedPreferences prefs;

  setUpAll(() async {
    await initializeDateFormatting('de', null);
    await initializeDateFormatting('en', null);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ReportsState stateFor(DateTime day, List<WorkEntryEntity> entries) =>
      ReportsState(
        isLoading: false,
        focusedDay: day,
        selectedDay: day,
        selectedMonth: DateTime(day.year, day.month),
        workEntries: const {},
        dailyReportState: DailyReportState(
          entries: entries,
          workTime: Duration.zero,
          breakTime: Duration.zero,
          totalTime: Duration.zero,
          overtime: Duration.zero,
        ),
      );

  Future<void> pump(
    WidgetTester tester,
    Widget home,
    ReportsState state, {
    Locale locale = const Locale('de'),
  }) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clockProvider.overrideWithValue(() => now),
          sharedPreferencesProvider.overrideWithValue(prefs),
          isPremiumProvider.overrideWithValue(false),
          settingsViewModelProvider
              .overrideWith(() => _FakeSettingsViewModel()),
          reportsViewModelProvider
              .overrideWith(() => _FakeReportsViewModel(state)),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Freitag, 3 Tage vor "heute" (Montag 2026-10-05 12:00).
  final orphanDay = DateTime(2026, 10, 2);
  final orphan = WorkEntryEntity(
    id: 'o',
    date: orphanDay,
    workStart: DateTime(2026, 10, 2, 8),
  );
  final today = DateTime(2026, 10, 5);
  final runningToday = WorkEntryEntity(
    id: 't',
    date: today,
    workStart: DateTime(2026, 10, 5, 8),
  );
  final closed = WorkEntryEntity(
    id: 'c',
    date: orphanDay,
    workStart: DateTime(2026, 10, 2, 8),
    workEnd: DateTime(2026, 10, 2, 16),
  );

  group('Tages-Tab', () {
    testWidgets(
        'verwaister Vortag: Summe 00:00, Saldo -Soll, Hinweis, keine '
        'absurde Arbeitszeit', (tester) async {
      await pump(tester, const ReportsPage(), stateFor(orphanDay, [orphan]));

      // Ist (Tag) 00:00, Saldo (Tag) = -Soll (Backend-konform)
      expect(find.text('00:00'), findsOneWidget);
      expect(find.text('-08:00'), findsOneWidget);
      expect(find.textContaining('76:00:00'), findsNothing);
      expect(find.textContaining('Arbeitszeit:'), findsNothing);
      expect(find.text('Unvollständig'), findsOneWidget);
      expect(find.text(_hintDe), findsOneWidget);
      // Ueberstundenzeile der Karte entfaellt
      expect(find.textContaining('Überstunden:'), findsNothing);
    });

    testWidgets('Hinweis auch auf Englisch', (tester) async {
      await pump(tester, const ReportsPage(), stateFor(orphanDay, [orphan]),
          locale: const Locale('en'));
      expect(find.text('Incomplete'), findsOneWidget);
      expect(find.text(_hintEn), findsOneWidget);
    });

    testWidgets('heute laufender Eintrag zählt live, ohne Hinweis',
        (tester) async {
      await pump(tester, const ReportsPage(), stateFor(today, [runningToday]));

      expect(find.text('04:00'), findsOneWidget);
      expect(find.text('-04:00'), findsOneWidget);
      expect(find.text('Arbeitszeit: 4:00:00'), findsOneWidget);
      expect(find.text(_hintDe), findsNothing);
      expect(find.text('Unvollständig'), findsNothing);
    });

    testWidgets('abgeschlossener Eintrag unverändert, ohne Hinweis',
        (tester) async {
      await pump(tester, const ReportsPage(), stateFor(orphanDay, [closed]));

      expect(find.text('08:00'), findsWidgets); // Soll und Ist
      expect(find.text('Arbeitszeit: 8:00:00'), findsOneWidget);
      expect(find.text('Überstunden: +00:00'), findsOneWidget);
      expect(find.text(_hintDe), findsNothing);
    });

    testWidgets(
        'verwaister Vortag plus abgeschlossener Eintrag desselben '
        'Tages: nur der geschlossene zählt', (tester) async {
      await pump(
          tester, const ReportsPage(), stateFor(orphanDay, [orphan, closed]));

      expect(find.text('Arbeitszeit: 8:00:00'), findsOneWidget);
      expect(find.text(_hintDe), findsOneWidget);
      expect(find.textContaining('76:00:00'), findsNothing);
    });
  });

  group('Tages-Tab, Typ ungleich work', () {
    testWidgets(
        'Urlaub mit Zeiten zählt nicht als Arbeitszeit, Soll gilt als erfüllt',
        (tester) async {
      final vacation = WorkEntryEntity(
        id: 'v',
        date: orphanDay,
        workStart: DateTime(2026, 10, 2, 8),
        workEnd: DateTime(2026, 10, 2, 10),
        type: WorkEntryType.vacation,
      );
      await pump(tester, const ReportsPage(), stateFor(orphanDay, [vacation]));

      // Ist = Soll (08:00), Saldo 00:00 (nicht 02:00 - 08:00)
      expect(find.text('-06:00'), findsNothing);
      expect(find.text('08:00'), findsWidgets);
      expect(find.text('Unvollständig'), findsNothing);
    });
  });

  group('Bottom-Sheet je Kalendertag', () {
    Widget sheet(DateTime day) =>
        Scaffold(body: DayEntriesBottomSheet(date: day));

    testWidgets('verwaister Vortag: Hinweis statt absurder Arbeitszeit',
        (tester) async {
      await pump(tester, sheet(orphanDay), stateFor(orphanDay, [orphan]));

      expect(find.textContaining('76:00:00'), findsNothing);
      expect(find.textContaining('Arbeitszeit:'), findsNothing);
      expect(find.text('Unvollständig'), findsOneWidget);
      expect(find.text(_hintDe), findsOneWidget);
    });

    testWidgets('Hinweis auch auf Englisch', (tester) async {
      await pump(tester, sheet(orphanDay), stateFor(orphanDay, [orphan]),
          locale: const Locale('en'));
      expect(find.text('Incomplete'), findsOneWidget);
      expect(find.text(_hintEn), findsOneWidget);
    });

    testWidgets('heute laufender Eintrag zählt live, ohne Hinweis',
        (tester) async {
      await pump(tester, sheet(today), stateFor(today, [runningToday]));

      expect(find.text('Arbeitszeit: 4:00:00'), findsOneWidget);
      expect(find.text(_hintDe), findsNothing);
    });

    testWidgets('abgeschlossener Eintrag unverändert', (tester) async {
      await pump(tester, sheet(orphanDay), stateFor(orphanDay, [closed]));

      expect(find.text('Arbeitszeit: 8:00:00'), findsOneWidget);
      expect(find.text(_hintDe), findsNothing);
    });
  });
}
