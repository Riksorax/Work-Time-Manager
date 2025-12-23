import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_work_time/domain/entities/break_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/presentation/state/dashboard_state.dart';
import 'package:flutter_work_time/presentation/view_models/dashboard_view_model.dart';
import 'package:flutter_work_time/presentation/widgets/dashboard/breaks_card.dart';

import 'breaks_card_test.mocks.dart';

// Reuse the callback logic for verification
abstract class BreakCallback {
  void call();
}

@GenerateMocks([BreakCallback])
void main() {
  late MockBreakCallback mockCallback;

  setUp(() {
    mockCallback = MockBreakCallback();
  });

  Widget createSubject(WorkEntryEntity entry, DashboardViewModel viewModel) {
    return ProviderScope(
      overrides: [
        dashboardViewModelProvider.overrideWith(() => viewModel),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: BreaksCard(workEntry: entry),
        ),
      ),
    );
  }

  group('BreaksCard Widget', () {
    testWidgets('shows "Keine Pausen erfasst" when list is empty', (tester) async {
      final entry = WorkEntryEntity(
        id: '1',
        date: DateTime.now(),
        breaks: const [],
      );

      final fakeViewModel = FakeDashboardViewModel(mockCallback);
      await tester.pumpWidget(createSubject(entry, fakeViewModel));

      expect(find.text('Keine Pausen erfasst'), findsOneWidget);
    });

    testWidgets('lists existing breaks', (tester) async {
      final now = DateTime.now();
      final entry = WorkEntryEntity(
        id: '1',
        date: now,
        breaks: [
          BreakEntity(
            id: 'b1',
            name: 'Mittagspause',
            start: DateTime(now.year, now.month, now.day, 12, 0),
            end: DateTime(now.year, now.month, now.day, 12, 30),
          ),
        ],
      );

      final fakeViewModel = FakeDashboardViewModel(mockCallback);
      await tester.pumpWidget(createSubject(entry, fakeViewModel));

      expect(find.text('Mittagspause'), findsOneWidget);
      expect(find.text('12:00 - 12:30'), findsOneWidget);
    });

    testWidgets('button shows "Pause beenden" when a break is active', (tester) async {
      final now = DateTime.now();
      final entry = WorkEntryEntity(
        id: '1',
        date: now,
        workStart: DateTime(now.year, now.month, now.day, 8, 0),
        breaks: [
          BreakEntity(
            id: 'b1',
            name: 'Laufende Pause',
            start: now.subtract(const Duration(minutes: 10)),
            end: null, // Active
          ),
        ],
      );

      final fakeViewModel = FakeDashboardViewModel(mockCallback);
      await tester.pumpWidget(createSubject(entry, fakeViewModel));

      expect(find.text('Pause beenden'), findsOneWidget);
      expect(find.byIcon(Icons.stop_circle_outlined), findsOneWidget);
    });

    testWidgets('button is disabled when work has not started', (tester) async {
      final entry = WorkEntryEntity(
        id: '1',
        date: DateTime.now(),
        workStart: null, // Not working
      );

      final fakeViewModel = FakeDashboardViewModel(mockCallback);
      await tester.pumpWidget(createSubject(entry, fakeViewModel));

      expect(find.text('Pause starten'), findsOneWidget);
      await tester.tap(find.text('Pause starten'));
      
      verifyNever(mockCallback.call());
    });

    testWidgets('button is disabled when work is already finished', (tester) async {
      final now = DateTime.now();
      final entry = WorkEntryEntity(
        id: '1',
        date: now,
        workStart: now.subtract(const Duration(hours: 9)),
        workEnd: now.subtract(const Duration(hours: 1)),
      );

      final fakeViewModel = FakeDashboardViewModel(mockCallback);
      await tester.pumpWidget(createSubject(entry, fakeViewModel));

      expect(find.text('Pause starten'), findsOneWidget);
      await tester.tap(find.text('Pause starten'));
      
      verifyNever(mockCallback.call());
    });

    testWidgets('tapping button calls startOrStopBreak', (tester) async {
      final now = DateTime.now();
      final entry = WorkEntryEntity(
        id: '1',
        date: now,
        workStart: now.subtract(const Duration(hours: 1)), // Currently working
      );

      final fakeViewModel = FakeDashboardViewModel(mockCallback);
      await tester.pumpWidget(createSubject(entry, fakeViewModel));

      await tester.tap(find.text('Pause starten'));
      verify(mockCallback.call()).called(1);
    });
  });
}

class FakeDashboardViewModel extends DashboardViewModel {
  final BreakCallback onToggle;

  FakeDashboardViewModel(this.onToggle);

  @override
  DashboardState build() {
    return DashboardState.initial();
  }

  @override
  Future<void> startOrStopBreak() async {
    onToggle.call();
  }
}
