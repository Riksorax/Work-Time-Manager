import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/presentation/state/dashboard_state.dart';
import 'package:flutter_work_time/presentation/view_models/dashboard_view_model.dart';
import 'package:flutter_work_time/presentation/widgets/dashboard/timer_card.dart';

import 'timer_card_test.mocks.dart';

// Create a simple class to mock the callback
abstract class Callback {
  void call();
}

@GenerateMocks([Callback])
void main() {
  late MockCallback mockCallback;

  setUp(() {
    mockCallback = MockCallback();
  });

  Widget createSubject(WorkEntryEntity entry, DashboardViewModel viewModel) {
    return ProviderScope(
      overrides: [
        dashboardViewModelProvider.overrideWith(() => viewModel),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: TimerCard(workEntry: entry),
        ),
      ),
    );
  }

  group('TimerCard Widget', () {
    testWidgets('shows "Arbeit starten" when work has not started', (tester) async {
      final entry = WorkEntryEntity(
        id: '1',
        date: DateTime.now(),
        workStart: null,
        workEnd: null,
      );

      final fakeViewModel = FakeDashboardViewModel(mockCallback);
      await tester.pumpWidget(createSubject(entry, fakeViewModel));

      expect(find.text('Arbeit starten'), findsOneWidget);
      expect(find.text('--:--:--'), findsNWidgets(2)); // Start and End
      expect(find.byIcon(Icons.play_circle_filled), findsOneWidget);
    });

    testWidgets('shows "Arbeit beenden" when timer is running', (tester) async {
      final entry = WorkEntryEntity(
        id: '1',
        date: DateTime.now(),
        workStart: DateTime(2023, 10, 26, 8, 0, 0),
        workEnd: null,
      );

      final fakeViewModel = FakeDashboardViewModel(mockCallback);
      await tester.pumpWidget(createSubject(entry, fakeViewModel));

      expect(find.text('Arbeit beenden'), findsOneWidget);
      expect(find.text('08:00:00'), findsOneWidget); // Start time
      expect(find.text('--:--:--'), findsOneWidget); // End time
      expect(find.byIcon(Icons.pause_circle_filled), findsOneWidget);
    });

    testWidgets('button is disabled when work is finished', (tester) async {
      final entry = WorkEntryEntity(
        id: '1',
        date: DateTime.now(),
        workStart: DateTime(2023, 10, 26, 8, 0, 0),
        workEnd: DateTime(2023, 10, 26, 17, 0, 0),
      );

      final fakeViewModel = FakeDashboardViewModel(mockCallback);
      await tester.pumpWidget(createSubject(entry, fakeViewModel));

      // Check text is present
      expect(find.text('Arbeit starten'), findsOneWidget);
      expect(find.text('08:00:00'), findsOneWidget);
      expect(find.text('17:00:00'), findsOneWidget);
      
      // Attempt to tap
      await tester.tap(find.text('Arbeit starten'));
      
      // Verify no interaction occurred
      verifyNever(mockCallback.call());
    });

    testWidgets('tapping button calls startOrStopTimer', (tester) async {
      final entry = WorkEntryEntity(
        id: '1',
        date: DateTime.now(),
        workStart: null,
        workEnd: null,
      );
      
      final fakeViewModel = FakeDashboardViewModel(mockCallback);

      await tester.pumpWidget(createSubject(entry, fakeViewModel));

      await tester.tap(find.text('Arbeit starten'));
      
      verify(mockCallback.call()).called(1);
    });
  });
}

class FakeDashboardViewModel extends DashboardViewModel {
  final Callback onStartStop;

  FakeDashboardViewModel(this.onStartStop);

  @override
  DashboardState build() {
    // Override build to avoid side effects (init, ref.watch)
    return DashboardState.initial();
  }

  @override
  Future<void> startOrStopTimer() async {
    onStartStop.call();
  }
}
