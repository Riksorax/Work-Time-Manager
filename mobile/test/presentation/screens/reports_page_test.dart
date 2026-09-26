import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/providers/subscription_provider.dart';
import 'package:flutter_work_time/domain/entities/settings_entity.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';
import 'package:flutter_work_time/domain/entities/weekly_reflection_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/repositories/weekly_reflection_repository.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/screens/reports_page.dart';
import 'package:flutter_work_time/presentation/state/reports_state.dart';
import 'package:flutter_work_time/presentation/state/settings_state.dart';
import 'package:flutter_work_time/presentation/state/monthly_report_state.dart';
import 'package:flutter_work_time/presentation/state/weekly_report_state.dart';
import 'package:flutter_work_time/presentation/view_models/reports_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/settings_view_model.dart';

import 'reports_page_test.mocks.dart';
import '../view_models/reports_view_model_test.mocks.dart';
import '../view_models/dashboard_view_model_test.mocks.dart' hide MockSettingsRepository;

// Abstract callbacks for verification
abstract class NavigationCallback {
  void onMonthChanged(DateTime date);
  void selectDate(DateTime date);
}

@GenerateMocks([NavigationCallback, WeeklyReflectionRepository])
void main() {
  late MockNavigationCallback mockCallback;
  late MockSettingsRepository mockSettingsRepository;
  late MockOvertimeRepository mockOvertimeRepository;
  late MockWorkRepository mockWorkRepository;
  late MockWeeklyReflectionRepository mockWeeklyReflectionRepository;
  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await initializeDateFormatting('de_DE', null);
  });

  setUp(() {
    mockCallback = MockNavigationCallback();
    mockSettingsRepository = MockSettingsRepository();
    mockOvertimeRepository = MockOvertimeRepository();
    mockWorkRepository = MockWorkRepository();
    mockWeeklyReflectionRepository = MockWeeklyReflectionRepository();
    when(mockSettingsRepository.getWorkdays()).thenReturn([1, 2, 3, 4, 5]);
    when(mockSettingsRepository.getTargetWeeklyHours()).thenReturn(40.0);
    when(mockOvertimeRepository.getOvertime()).thenReturn(Duration.zero);
    when(mockOvertimeRepository.getLastUpdateDate()).thenReturn(null);
    when(mockWorkRepository.getWorkEntriesForMonth(any, any)).thenAnswer((_) async => []);
    when(mockWeeklyReflectionRepository.getReflection(any, any))
        .thenAnswer((_) async => null);
    when(mockWeeklyReflectionRepository.saveReflection(any))
        .thenAnswer((_) async {});
  });

  Widget createSubject({
    required ReportsViewModel reportsViewModel,
    required SettingsViewModel settingsViewModel,
    required AsyncValue<UserEntity?> authState,
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        isPremiumProvider.overrideWithValue(true),
        settingsRepositoryProvider.overrideWithValue(mockSettingsRepository),
        overtimeRepositoryProvider.overrideWithValue(mockOvertimeRepository),
        workRepositoryProvider.overrideWithValue(mockWorkRepository),
        weeklyReflectionRepositoryProvider.overrideWithValue(mockWeeklyReflectionRepository),
        reportsViewModelProvider.overrideWith(() => reportsViewModel),
        settingsViewModelProvider.overrideWith(() => settingsViewModel),
        authStateProvider.overrideWithValue(authState),
      ],
      child: MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ReportsPage(),
      ),
    );
  }

  group('ReportsPage', () {
    testWidgets('shows DailyReportView by default', (tester) async {
      final now = DateTime.now();
      
      final reportsViewModel = FakeReportsViewModel(
        initialState: ReportsState.initial().copyWith(
          isLoading: false,
          selectedDay: now,
          selectedMonth: now,
        ),
        callback: mockCallback,
      );

      final settingsViewModel = FakeSettingsViewModel(
        initialState: const AsyncValue.data(SettingsState(
          settings: SettingsEntity(), 
          overtimeBalance: Duration.zero
        )),
      );

      await tester.pumpWidget(createSubject(
        reportsViewModel: reportsViewModel,
        settingsViewModel: settingsViewModel,
        authState: const AsyncValue.data(UserEntity(id: '1', email: 'test@test.com')),
      ));

      await tester.pumpAndSettle();

      if (find.byType(ErrorWidget).evaluate().isNotEmpty) {
        final errorWidget = tester.widget<ErrorWidget>(find.byType(ErrorWidget));
        fail('Render error: ${errorWidget.message}');
      }
      
      if (find.textContaining('Fehler beim Laden').evaluate().isNotEmpty) {
        fail('AsyncValue Error state found');
      }

      // Check for TabBar
      expect(find.text('Täglich'), findsOneWidget);
      expect(find.text('Wöchentlich'), findsOneWidget);
      expect(find.text('Monatlich'), findsOneWidget);

      // Check if DailyReportView is visible by finding the Calendar navigation icon
      expect(find.byIcon(Icons.chevron_left), findsWidgets); // Can be multiple (month nav)
    });

    testWidgets('can switch tabs to Weekly and Monthly', (tester) async {
      final dummyState = ReportsState.initial().copyWith(
        isLoading: false,
        monthlyReportState: MonthlyReportState(
          workDays: 5,
          dailyWork: {DateTime.now(): const Duration(hours: 8)},
          weeklyWork: {1: const Duration(hours: 40)},
        ),
        weeklyReportState: WeeklyReportState(
           workDays: 5,
           dailyWork: {DateTime.now(): const Duration(hours: 8)},
        ),
      );

      final reportsViewModel = FakeReportsViewModel(
        initialState: dummyState,
        callback: mockCallback,
      );
      final settingsViewModel = FakeSettingsViewModel(
        initialState: const AsyncValue.data(SettingsState(settings: SettingsEntity(), overtimeBalance: Duration.zero)),
      );

      await tester.pumpWidget(createSubject(
        reportsViewModel: reportsViewModel,
        settingsViewModel: settingsViewModel,
        authState: const AsyncValue.data(UserEntity(id: '1', email: 'test@test.com')),
      ));
      await tester.pumpAndSettle();

      // Switch to Weekly
      await tester.tap(find.text('Wöchentlich'));
      await tester.pumpAndSettle();
      expect(find.text('Wochenbericht'), findsOneWidget);

      // Switch to Monthly
      await tester.tap(find.text('Monatlich'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Wochenübersicht'), findsOneWidget); 
    });

    testWidgets('Wochen-Reflexion Button öffnet Dialog und speichert', (tester) async {
      final reportsViewModel = FakeReportsViewModel(
        initialState: ReportsState.initial().copyWith(isLoading: false),
        callback: mockCallback,
      );
      final settingsViewModel = FakeSettingsViewModel(
        initialState: const AsyncValue.data(SettingsState(settings: SettingsEntity(), overtimeBalance: Duration.zero)),
      );

      await tester.pumpWidget(createSubject(
        reportsViewModel: reportsViewModel,
        settingsViewModel: settingsViewModel,
        authState: const AsyncValue.data(UserEntity(id: '1', email: 'test@test.com')),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Wöchentlich'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Wochen-Reflexion'));
      await tester.pumpAndSettle();

      verify(mockWeeklyReflectionRepository.getReflection(any, any)).called(1);
      expect(find.text('Was lief gut?'), findsOneWidget);
      expect(find.text('Was war anstrengend?'), findsOneWidget);

      await tester.enterText(
          find.widgetWithText(TextField, 'Was lief gut?'), 'Guter Sprint');
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();

      final captured = verify(
              mockWeeklyReflectionRepository.saveReflection(captureAny))
          .captured
          .single as WeeklyReflectionEntity;
      expect(captured.whatWentWell, 'Guter Sprint');
      expect(find.text('Was lief gut?'), findsNothing); // Dialog geschlossen
      expect(find.textContaining('Reflexion gespeichert'), findsOneWidget);
    });

    testWidgets('Insights-Tab zeigt Platzhalter ohne Datenbasis', (tester) async {
      final reportsViewModel = FakeReportsViewModel(
        initialState: ReportsState.initial().copyWith(isLoading: false),
        callback: mockCallback,
      );
      final settingsViewModel = FakeSettingsViewModel(
        initialState: const AsyncValue.data(SettingsState(settings: SettingsEntity(), overtimeBalance: Duration.zero)),
      );

      await tester.pumpWidget(createSubject(
        reportsViewModel: reportsViewModel,
        settingsViewModel: settingsViewModel,
        authState: const AsyncValue.data(UserEntity(id: '1', email: 'test@test.com')),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Insights'));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorWidget), findsNothing);
      expect(find.textContaining('Noch nicht genug Daten'), findsOneWidget);
    });

    testWidgets('Insights-Tab zeigt Wochentags-Analyse und Heatmap mit Datenbasis', (tester) async {
      final now = DateTime.now();
      // Zwei Einträge am selben Wochentag + selber Startstunde, damit sowohl
      // die Wochentags-Analyse als auch die Heatmap (minSampleCount: 2)
      // Ergebnisse liefern.
      final testEntries = [
        WorkEntryEntity(
          id: '1',
          date: DateTime(now.year, now.month, 1, 8),
          workStart: DateTime(now.year, now.month, 1, 8),
          workEnd: DateTime(now.year, now.month, 1, 17),
        ),
        WorkEntryEntity(
          id: '2',
          date: DateTime(now.year, now.month, 2, 8),
          workStart: DateTime(now.year, now.month, 2, 8),
          workEnd: DateTime(now.year, now.month, 2, 17),
        ),
      ];
      when(mockWorkRepository.getWorkEntriesForMonth(any, any))
          .thenAnswer((_) async => testEntries);

      final reportsViewModel = FakeReportsViewModel(
        initialState: ReportsState.initial().copyWith(isLoading: false),
        callback: mockCallback,
      );
      final settingsViewModel = FakeSettingsViewModel(
        initialState: const AsyncValue.data(SettingsState(settings: SettingsEntity(), overtimeBalance: Duration.zero)),
      );

      await tester.pumpWidget(createSubject(
        reportsViewModel: reportsViewModel,
        settingsViewModel: settingsViewModel,
        authState: const AsyncValue.data(UserEntity(id: '1', email: 'test@test.com')),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Insights'));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorWidget), findsNothing);
      expect(find.text('Wochentags-Analyse'), findsOneWidget);
      expect(find.text('Produktivitäts-Heatmap nach Startzeit'), findsOneWidget);
      expect(find.text('Start 08:00 Uhr'), findsOneWidget);
    });

    testWidgets('navigating previous month calls onMonthChanged', (tester) async {
      final now = DateTime.now();
      final reportsViewModel = FakeReportsViewModel(
        initialState: ReportsState.initial().copyWith(
          isLoading: false,
          selectedDay: now,
          selectedMonth: now,
        ),
        callback: mockCallback,
      );
      final settingsViewModel = FakeSettingsViewModel(
        initialState: const AsyncValue.data(SettingsState(settings: SettingsEntity(), overtimeBalance: Duration.zero)),
      );

      await tester.pumpWidget(createSubject(
        reportsViewModel: reportsViewModel,
        settingsViewModel: settingsViewModel,
        authState: const AsyncValue.data(UserEntity(id: '1', email: 'test@test.com')),
      ));
      await tester.pumpAndSettle();

      // Find the "Previous Month" icon button in the Calendar widget
      final prevMonthFinder = find.widgetWithIcon(IconButton, Icons.chevron_left).first;
      
      await tester.tap(prevMonthFinder);
      
      verify(mockCallback.onMonthChanged(any)).called(1);
    });
  });
}

class FakeReportsViewModel extends ReportsViewModel {
  final ReportsState initialState;
  final NavigationCallback callback;

  FakeReportsViewModel({required this.initialState, required this.callback});

  @override
  ReportsState build() {
    return initialState;
  }

  @override
  void loadCurrentMonthData() {
    // No-op for test
  }

  @override
  void onMonthChanged(DateTime newMonth) {
    callback.onMonthChanged(newMonth);
  }
  
  @override
  void selectDate(DateTime date) {
    callback.selectDate(date);
  }
}

class FakeSettingsViewModel extends SettingsViewModel {
  final AsyncValue<SettingsState> initialState;

  FakeSettingsViewModel({required this.initialState});

  @override
  AsyncValue<SettingsState> build() {
    return initialState;
  }
}