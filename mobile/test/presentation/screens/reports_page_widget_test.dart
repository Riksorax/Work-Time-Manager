import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/presentation/screens/reports_page.dart';
import 'package:flutter_work_time/presentation/view_models/reports_view_model.dart';

import '../view_models/reports_view_model_test.mocks.dart';

@GenerateMocks([/* not used here, we import existing mocks */])
void main() {
  late MockWorkRepository mockWorkRepository;
  late MockSettingsRepository mockSettingsRepository;
  late ProviderContainer container;

  setUp(() {
    mockWorkRepository = MockWorkRepository();
    mockSettingsRepository = MockSettingsRepository();

    // Default settings
    when(mockSettingsRepository.getWorkdaysPerWeek()).thenReturn(5);
    when(mockSettingsRepository.getTargetWeeklyHours()).thenReturn(40.0);

    container = ProviderContainer(overrides: [
      workRepositoryProvider.overrideWithValue(mockWorkRepository),
      settingsRepositoryProvider.overrideWithValue(mockSettingsRepository),
    ]);
  });

  tearDown(() {
    container.dispose();
  });

  testWidgets('DailyReportView shows Zusatztag with no daily target and positive overtime', (WidgetTester tester) async {
    // Woche: Mo-Fri 8h, Sa 6h
    final entries = [
      WorkEntryEntity(id: '1', date: DateTime(2023,10,23), workStart: DateTime(2023,10,23,8,0), workEnd: DateTime(2023,10,23,16,0)),
      WorkEntryEntity(id: '2', date: DateTime(2023,10,24), workStart: DateTime(2023,10,24,8,0), workEnd: DateTime(2023,10,24,16,0)),
      WorkEntryEntity(id: '3', date: DateTime(2023,10,25), workStart: DateTime(2023,10,25,8,0), workEnd: DateTime(2023,10,25,16,0)),
      WorkEntryEntity(id: '4', date: DateTime(2023,10,26), workStart: DateTime(2023,10,26,8,0), workEnd: DateTime(2023,10,26,16,0)),
      WorkEntryEntity(id: '5', date: DateTime(2023,10,27), workStart: DateTime(2023,10,27,8,0), workEnd: DateTime(2023,10,27,16,0)),
      WorkEntryEntity(id: '6', date: DateTime(2023,10,28), workStart: DateTime(2023,10,28,8,0), workEnd: DateTime(2023,10,28,14,0)),
    ];

    // Stub repository for October 2023
    when(mockWorkRepository.getWorkEntriesForMonth(2023, 10))
        .thenAnswer((_) async => entries);

    // Build widget tree with our ProviderContainer using UncontrolledProviderScope
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: const ReportsPage(),
        ),
      ),
    );

    // Let initial microtasks run
    await tester.pumpAndSettle();

    // Now select the Saturday (Zusatztag)
    final targetDate = DateTime(2023,10,28);
    // trigger selection via the notifier in our container
    container.read(reportsViewModelProvider.notifier).selectDate(targetDate);

    // Wait for async loads
    await tester.pumpAndSettle();

    // Expect label to indicate Zusatztag
    expect(find.text('Soll (Zusatztag):'), findsOneWidget);

    // Expect '-' displayed for Soll value (there may be several '-' widgets, so just ensure one exists)
    expect(find.text('-'), findsWidgets);

    // Expect overtime for the day to show +06:00 (6 hours)
    expect(find.text('+06:00'), findsOneWidget);
  });
}
