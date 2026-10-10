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

/// Block B (#418): Das Tages-Sheet ordnet Eintraege ueber `entryDay` zu.
/// Fixture inkonsistent: Id Montag 2026-10-05, `date` am Sonntag 2026-10-04.
/// Zonenunabhaengig, feste Uhr Mo 2026-10-05 12:00.
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

class _FakeSettingsViewModel extends SettingsViewModel {
  @override
  AsyncValue<SettingsState> build() => const AsyncValue.data(
        SettingsState(
            settings: SettingsEntity(), overtimeBalance: Duration.zero),
      );
}

void main() {
  final now = DateTime(2026, 10, 5, 12);
  late SharedPreferences prefs;

  setUpAll(() async {
    await initializeDateFormatting('de', null);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  final monday = WorkEntryEntity(
    id: '2026-10-05',
    date: DateTime(2026, 10, 4),
    workStart: DateTime(2026, 10, 5, 8),
    workEnd: DateTime(2026, 10, 5, 16),
  );

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

  Future<void> pumpSheet(WidgetTester tester, DateTime day) async {
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
          reportsViewModelProvider.overrideWith(
              () => _FakeReportsViewModel(stateFor(day, [monday]))),
        ],
        child: MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DayEntriesBottomSheet(date: day)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('DayEntriesBottomSheet', () {
    testWidgets('Eintrag mit Id 05.10. erscheint im Sheet fuer den 05.10.',
        (tester) async {
      await pumpSheet(tester, DateTime(2026, 10, 5));
      expect(find.text('Arbeitszeit: 8:00:00'), findsOneWidget);
    });

    testWidgets('... und nicht im Sheet fuer den 04.10. (date-Tag)',
        (tester) async {
      await pumpSheet(tester, DateTime(2026, 10, 4));
      expect(find.text('Arbeitszeit: 8:00:00'), findsNothing);
    });
  });
}
