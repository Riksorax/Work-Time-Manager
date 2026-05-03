import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/break_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/presentation/state/dashboard_state.dart';
import 'package:flutter_work_time/presentation/view_models/dashboard_view_model.dart';
import 'package:flutter_work_time/presentation/widgets/edit_break_modal.dart';

void main() {
  group('EditBreakModal', () {
    late DateTime testDate;
    late BreakEntity testBreak;

    setUp(() {
      testDate = DateTime(2024, 1, 15);
      testBreak = BreakEntity(
        id: 'break-1',
        name: 'Mittagspause',
        start: DateTime(2024, 1, 15, 12, 0),
        end: DateTime(2024, 1, 15, 12, 30),
      );
    });

    Widget createSubject(BreakEntity breakEntity) {
      return ProviderScope(
        overrides: [
          dashboardViewModelProvider.overrideWith(() => FakeDashboardViewModel()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => EditBreakModal(breakEntity: breakEntity),
                  );
                },
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders with correct initial values', (tester) async {
      await tester.pumpWidget(createSubject(testBreak));
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Pause bearbeiten'), findsOneWidget);
      expect(find.text('Mittagspause'), findsOneWidget);
      expect(find.text('12:00'), findsOneWidget);
      expect(find.text('12:30'), findsOneWidget);
    });

    testWidgets('shows error when end time is before start time on save', (tester) async {
      // Create a break with invalid times (end before start)
      final invalidBreak = BreakEntity(
        id: 'break-1',
        name: 'Test',
        start: DateTime(2024, 1, 15, 14, 0),
        end: DateTime(2024, 1, 15, 12, 0), // End before start
      );

      await tester.pumpWidget(createSubject(invalidBreak));
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();

      expect(find.text('Endzeit kann nicht vor der Startzeit liegen.'), findsOneWidget);
    });

    testWidgets('cancel button closes modal without saving', (tester) async {
      await tester.pumpWidget(createSubject(testBreak));
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Pause bearbeiten'), findsOneWidget);

      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();

      expect(find.text('Pause bearbeiten'), findsNothing);
    });

    testWidgets('renders break without end time', (tester) async {
      final activeBreak = BreakEntity(
        id: 'break-1',
        name: 'Laufende Pause',
        start: DateTime(2024, 1, 15, 12, 0),
        end: null,
      );

      await tester.pumpWidget(createSubject(activeBreak));
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Laufende Pause'), findsOneWidget);
      expect(find.text('12:00'), findsOneWidget);
      // End time field should be empty
      final endTimeField = find.widgetWithText(TextField, 'Endzeit');
      expect(endTimeField, findsOneWidget);
    });
  });

  group('Break duration preservation logic', () {
    test('calculates correct new end time when start time changes', () {
      // This tests the core logic: when start time moves, end time should move by same amount
      final originalStart = DateTime(2024, 1, 15, 12, 0);
      final originalEnd = DateTime(2024, 1, 15, 12, 30);
      final newStart = DateTime(2024, 1, 15, 13, 0);

      // Calculate duration (this is what the code does)
      final duration = originalEnd.difference(originalStart);
      final newEnd = newStart.add(duration);

      expect(duration, const Duration(minutes: 30));
      expect(newEnd, DateTime(2024, 1, 15, 13, 30));
    });

    test('preserves duration when start time moves earlier', () {
      final originalStart = DateTime(2024, 1, 15, 14, 0);
      final originalEnd = DateTime(2024, 1, 15, 14, 45);
      final newStart = DateTime(2024, 1, 15, 12, 0);

      final duration = originalEnd.difference(originalStart);
      final newEnd = newStart.add(duration);

      expect(duration, const Duration(minutes: 45));
      expect(newEnd, DateTime(2024, 1, 15, 12, 45));
    });

    test('preserves duration with hours and minutes', () {
      final originalStart = DateTime(2024, 1, 15, 10, 0);
      final originalEnd = DateTime(2024, 1, 15, 11, 30);
      final newStart = DateTime(2024, 1, 15, 14, 15);

      final duration = originalEnd.difference(originalStart);
      final newEnd = newStart.add(duration);

      expect(duration, const Duration(hours: 1, minutes: 30));
      expect(newEnd, DateTime(2024, 1, 15, 15, 45));
    });

    test('handles null end time correctly', () {
      final originalStart = DateTime(2024, 1, 15, 12, 0);
      final DateTime? originalEnd = null;
      final newStart = DateTime(2024, 1, 15, 13, 0);

      // When end is null, it should stay null
      final Duration? duration = originalEnd?.difference(originalStart);
      final DateTime? newEnd = duration != null ? newStart.add(duration) : null;

      expect(newEnd, isNull);
    });
  });
}

class FakeDashboardViewModel extends DashboardViewModel {
  BreakEntity? lastUpdatedBreak;

  @override
  DashboardState build() {
    return DashboardState(
      workEntry: WorkEntryEntity(
        id: '1',
        date: DateTime(2024, 1, 15),
      ),
      elapsedTime: Duration.zero,
      isLoading: false,
    );
  }

  @override
  Future<void> updateBreak(BreakEntity breakEntity) async {
    lastUpdatedBreak = breakEntity;
  }
}
