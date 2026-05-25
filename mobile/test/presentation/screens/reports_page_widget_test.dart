import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/providers/subscription_provider.dart';
import 'package:flutter_work_time/domain/entities/settings_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
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
  @override
  AsyncValue<SettingsState> build() => const AsyncValue.data(
        SettingsState(settings: SettingsEntity(), overtimeBalance: Duration.zero),
      );
}

@GenerateMocks([])
void main() {
  setUpAll(() async => initializeDateFormatting('de_DE', null));

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('DailyReportView shows Zusatztag with no daily target and positive overtime',
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
          reportsViewModelProvider.overrideWith(() => FakeReportsViewModel(fakeState)),
        ],
        child: const MaterialApp(home: ReportsPage()),
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
}
