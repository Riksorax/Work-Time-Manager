import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_work_time/domain/entities/settings_entity.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';
import 'package:flutter_work_time/presentation/screens/reports_page.dart';
import 'package:flutter_work_time/presentation/state/reports_state.dart';
import 'package:flutter_work_time/presentation/state/settings_state.dart';
import 'package:flutter_work_time/presentation/state/monthly_report_state.dart';
import 'package:flutter_work_time/presentation/state/weekly_report_state.dart';
import 'package:flutter_work_time/presentation/view_models/auth_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/reports_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/settings_view_model.dart';

import 'reports_page_test.mocks.dart';

// Abstract callbacks for verification
abstract class NavigationCallback {
  void onMonthChanged(DateTime date);
  void selectDate(DateTime date);
}

@GenerateMocks([NavigationCallback])
void main() {
  late MockNavigationCallback mockCallback;

  setUpAll(() async {
    await initializeDateFormatting('de_DE', null);
  });

  setUp(() {
    mockCallback = MockNavigationCallback();
  });

  Widget createSubject({
    required ReportsViewModel reportsViewModel,
    required SettingsViewModel settingsViewModel,
    required AsyncValue<UserEntity?> authState,
  }) {
    return ProviderScope(
      overrides: [
        reportsViewModelProvider.overrideWith(() => reportsViewModel),
        settingsViewModelProvider.overrideWith(() => settingsViewModel),
        authStateProvider.overrideWithValue(authState),
      ],
      child: MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('de', 'DE')],
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