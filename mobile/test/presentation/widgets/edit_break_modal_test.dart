import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/break_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/state/dashboard_state.dart';
import 'package:flutter_work_time/presentation/view_models/dashboard_view_model.dart';
import 'package:flutter_work_time/presentation/widgets/edit_break_modal.dart';

void main() {
  group('EditBreakModal', () {
    late BreakEntity testBreak;

    setUp(() {
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
          dashboardViewModelProvider
              .overrideWith(() => FakeDashboardViewModel()),
        ],
        child: MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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

    testWidgets('shows error when end time is before start time on save',
        (tester) async {
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

      expect(find.text('Endzeit kann nicht vor der Startzeit liegen.'),
          findsOneWidget);
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

  group('EditBreakModal Standardnamen (#346)', () {
    late FakeDashboardViewModel fakeViewModel;

    Widget createSubject(BreakEntity breakEntity, Locale locale) {
      fakeViewModel = FakeDashboardViewModel();
      return ProviderScope(
        overrides: [
          dashboardViewModelProvider.overrideWith(() => fakeViewModel),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => EditBreakModal(breakEntity: breakEntity),
                ),
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );
    }

    BreakEntity breakNamed(String name) => BreakEntity(
          id: 'b1',
          name: name,
          start: DateTime(2024, 1, 15, 12, 0),
          end: DateTime(2024, 1, 15, 12, 30),
        );

    testWidgets('zeigt den Standardnamen in der App-Sprache', (tester) async {
      await tester
          .pumpWidget(createSubject(breakNamed('Pause 2'), const Locale('en')));
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Break 2'), findsOneWidget);
    });

    testWidgets(
        'speichert den Standardnamen unverändert, wenn er nicht '
        'bearbeitet wurde', (tester) async {
      await tester
          .pumpWidget(createSubject(breakNamed('Pause 2'), const Locale('en')));
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(fakeViewModel.lastUpdatedBreak!.name, 'Pause 2');
    });

    testWidgets('Saldo-Fehler (#402): Snackbar, Dialog schliesst',
        (tester) async {
      await tester
          .pumpWidget(createSubject(breakNamed('Pause 2'), const Locale('en')));
      fakeViewModel.updateResult = false;
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(fakeViewModel.lastUpdatedBreak, isNotNull);
      expect(find.text('Break name'), findsNothing);
      expect(
          find.text(
              'Saving failed. Please check your connection and try again.'),
          findsOneWidget);
    });

    testWidgets('Erfolg: kein Snackbar', (tester) async {
      await tester
          .pumpWidget(createSubject(breakNamed('Pause 2'), const Locale('en')));
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('speichert einen vom Nutzer geänderten Namen', (tester) async {
      await tester
          .pumpWidget(createSubject(breakNamed('Pause 2'), const Locale('en')));
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, 'Break name'), 'Coffee with Anna');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(fakeViewModel.lastUpdatedBreak!.name, 'Coffee with Anna');
    });
  });

  group('EditBreakModal Datum der Pause (#397)', () {
    late FakeDashboardViewModel fakeViewModel;

    Widget createSubject(BreakEntity breakEntity) {
      fakeViewModel = FakeDashboardViewModel();
      return ProviderScope(
        overrides: [
          dashboardViewModelProvider.overrideWith(() => fakeViewModel),
        ],
        child: MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // 24-h-Picker, damit Stunden 0 und 13 gültig sind.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => EditBreakModal(breakEntity: breakEntity),
                ),
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );
    }

    Future<void> openModal(WidgetTester tester, BreakEntity b) async {
      // Hoher Viewport, damit der Zeit-Picker im Tastatur-Modus nicht überläuft.
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(createSubject(b));
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();
    }

    /// Öffnet den Picker des Felds [label], gibt die Uhrzeit im
    /// Tastatur-Modus ein und bestätigt mit OK.
    Future<void> pickTime(
        WidgetTester tester, String label, int hour, int minute) async {
      await tester.tap(find.widgetWithText(TextField, label));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.keyboard_outlined));
      await tester.pumpAndSettle();
      final fields = find.descendant(
          of: find.byType(TimePickerDialog), matching: find.byType(TextField));
      expect(fields, findsNWidgets(2));
      await tester.enterText(fields.at(0), hour.toString().padLeft(2, '0'));
      await tester.enterText(fields.at(1), minute.toString().padLeft(2, '0'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    }

    Future<void> save(WidgetTester tester) async {
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
    }

    testWidgets('Start ändern: Pause bleibt am Datum der Pause',
        (tester) async {
      await openModal(
          tester,
          BreakEntity(
            id: 'b1',
            name: 'Mittagspause',
            start: DateTime(2024, 1, 15, 12, 0),
            end: DateTime(2024, 1, 15, 12, 30),
          ));

      await pickTime(tester, 'Startzeit', 13, 0);
      await save(tester);

      expect(fakeViewModel.lastUpdatedBreak!.start, DateTime(2024, 1, 15, 13));
      expect(
          fakeViewModel.lastUpdatedBreak!.end, DateTime(2024, 1, 15, 13, 30));
    });

    testWidgets('nur Ende ändern: Dauer bleibt auf den Tag der Pause begrenzt',
        (tester) async {
      await openModal(
          tester,
          BreakEntity(
            id: 'b1',
            name: 'Mittagspause',
            start: DateTime(2024, 1, 15, 12, 0),
            end: DateTime(2024, 1, 15, 12, 30),
          ));

      await pickTime(tester, 'Endzeit', 12, 45);
      await save(tester);

      expect(fakeViewModel.lastUpdatedBreak!.start, DateTime(2024, 1, 15, 12));
      expect(
          fakeViewModel.lastUpdatedBreak!.end, DateTime(2024, 1, 15, 12, 45));
    });

    testWidgets('Pause nach Mitternacht (Folgetag) bleibt am Folgetag',
        (tester) async {
      await openModal(
          tester,
          BreakEntity(
            id: 'b1',
            name: 'Nachtpause',
            start: DateTime(2024, 1, 16, 0, 10),
            end: DateTime(2024, 1, 16, 0, 40),
          ));

      await pickTime(tester, 'Endzeit', 0, 50);
      await save(tester);

      expect(
          fakeViewModel.lastUpdatedBreak!.start, DateTime(2024, 1, 16, 0, 10));
      expect(fakeViewModel.lastUpdatedBreak!.end, DateTime(2024, 1, 16, 0, 50));
    });

    testWidgets('Pause über Mitternacht: Ende ändern behält den Tag des Endes',
        (tester) async {
      await openModal(
          tester,
          BreakEntity(
            id: 'b1',
            name: 'Nachtpause',
            start: DateTime(2024, 1, 15, 23, 30),
            end: DateTime(2024, 1, 16, 0, 10),
          ));

      await pickTime(tester, 'Endzeit', 0, 20);
      await save(tester);

      expect(
          fakeViewModel.lastUpdatedBreak!.start, DateTime(2024, 1, 15, 23, 30));
      expect(fakeViewModel.lastUpdatedBreak!.end, DateTime(2024, 1, 16, 0, 20));
    });

    testWidgets('laufende Pause ohne Ende: Start behält das Datum der Pause',
        (tester) async {
      await openModal(
          tester,
          BreakEntity(
            id: 'b1',
            name: 'Laufende Pause',
            start: DateTime(2024, 1, 15, 12, 0),
            end: null,
          ));

      await pickTime(tester, 'Startzeit', 12, 15);
      await save(tester);

      expect(
          fakeViewModel.lastUpdatedBreak!.start, DateTime(2024, 1, 15, 12, 15));
      expect(fakeViewModel.lastUpdatedBreak!.end, isNull);
    });

    testWidgets(
        'Overnight-Eingabe (Ende vor Start) wird weiter abgelehnt und nicht '
        'gespeichert', (tester) async {
      await openModal(
          tester,
          BreakEntity(
            id: 'b1',
            name: 'Spätpause',
            start: DateTime(2024, 1, 15, 23, 30),
            end: DateTime(2024, 1, 15, 23, 50),
          ));

      await pickTime(tester, 'Endzeit', 0, 20);
      await save(tester);

      expect(find.text('Endzeit kann nicht vor der Startzeit liegen.'),
          findsOneWidget);
      expect(fakeViewModel.lastUpdatedBreak, isNull);
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
  group('EditBreakModal waehrend einer Schreibaktion (#413)', () {
    Widget createSubject({required bool isSaving}) => ProviderScope(
          overrides: [
            dashboardViewModelProvider
                .overrideWith(() => _SavingDashboardViewModel(isSaving)),
          ],
          child: MaterialApp(
            locale: const Locale('de'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: EditBreakModal(
                breakEntity: BreakEntity(
                  id: 'b1',
                  name: 'Pause 1',
                  start: DateTime(2024, 1, 15, 12, 0),
                  end: DateTime(2024, 1, 15, 12, 30),
                ),
              ),
            ),
          ),
        );

    testWidgets('isSaving: Speichern deaktiviert, Abbrechen aktiv',
        (tester) async {
      await tester.pumpWidget(createSubject(isSaving: true));
      await tester.pump();

      final save = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Speichern'));
      final cancel = tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Abbrechen'));
      expect(save.onPressed, isNull);
      expect(cancel.onPressed, isNotNull);
    });

    testWidgets('ohne isSaving: Speichern aktiv', (tester) async {
      await tester.pumpWidget(createSubject(isSaving: false));
      await tester.pump();

      final save = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Speichern'));
      expect(save.onPressed, isNotNull);
    });
  });
}

class FakeDashboardViewModel extends DashboardViewModel {
  BreakEntity? lastUpdatedBreak;
  bool updateResult = true;

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
  Future<bool> updateBreak(BreakEntity breakEntity) async {
    lastUpdatedBreak = breakEntity;
    return updateResult;
  }
}

class _SavingDashboardViewModel extends FakeDashboardViewModel {
  _SavingDashboardViewModel(this._isSaving);

  final bool _isSaving;

  @override
  DashboardState build() => super.build().copyWith(isSaving: _isSaving);
}
