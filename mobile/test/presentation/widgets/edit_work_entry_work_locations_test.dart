import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/data/repositories/work_location_history.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/state/reports_state.dart';
import 'package:flutter_work_time/presentation/view_models/reports_view_model.dart';
import 'package:flutter_work_time/presentation/widgets/edit_work_entry_modal.dart';
import 'package:flutter_work_time/presentation/widgets/work_locations_input.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Arbeitsorte im Bearbeiten-Dialog (#526): immer sichtbar bei Typ Arbeit,
// unabhängig von der Dashboard-Einstellung. Feste Daten, DE und EN.
class _RecordingReportsViewModel extends ReportsViewModel {
  final List<WorkEntryEntity> saved = [];

  @override
  ReportsState build() => ReportsState.initial(DateTime(2026, 6, 5));

  @override
  Future<void> saveWorkEntry(WorkEntryEntity entry) async => saved.add(entry);
}

void main() {
  final day = DateTime(2026, 6, 5);

  WorkEntryEntity entry({
    List<String>? locs,
    WorkEntryType type = WorkEntryType.work,
  }) =>
      WorkEntryEntity(
        id: '2026-06-05',
        date: day,
        workStart: DateTime(2026, 6, 5, 8),
        workEnd: DateTime(2026, 6, 5, 16),
        type: type,
        workLocations: locs,
      );

  late _RecordingReportsViewModel reports;

  Future<void> pump(WidgetTester tester, WorkEntryEntity e,
      {String locale = 'de', double width = 800}) async {
    tester.view.physicalSize = Size(width, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    reports = _RecordingReportsViewModel();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        reportsViewModelProvider.overrideWith(() => reports),
        workLocationHistoryProvider
            .overrideWithValue(WorkLocationHistory(prefs, userId: 'local')),
      ],
      child: MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: EditWorkEntryModal(workEntry: e)),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Finder input() => find.descendant(
      of: find.byType(WorkLocationsInput), matching: find.byType(TextField));

  testWidgets('DE: Orte als Chips, Hinzufügen und Speichern', (tester) async {
    await pump(tester, entry(locs: const ['Büro']));
    expect(find.widgetWithText(InputChip, 'Büro'), findsOneWidget);
    expect(find.text('Arbeitsort'), findsOneWidget);

    await tester.enterText(input(), 'Kunde A');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(InputChip, 'Kunde A'), findsOneWidget);

    await tester.tap(find.text('Änderungen speichern'));
    await tester.pumpAndSettle();
    expect(reports.saved.single.workLocations, ['Büro', 'Kunde A']);
  });

  testWidgets('noch getippter Ort wird beim Speichern übernommen',
      (tester) async {
    await pump(tester, entry());
    await tester.enterText(input(), 'Werk 2');
    await tester.tap(find.text('Änderungen speichern'));
    await tester.pumpAndSettle();
    expect(reports.saved.single.workLocations, ['Werk 2']);
  });

  testWidgets('ungültiger getippter Ort: nichts gespeichert, Hinweis',
      (tester) async {
    await pump(tester, entry(locs: const ['Büro']));
    await tester.enterText(input(), 'büro');
    await tester.tap(find.text('Änderungen speichern'));
    await tester.pumpAndSettle();
    expect(reports.saved, isEmpty);
    expect(find.text('Dieser Ort ist schon eingetragen.'), findsOneWidget);
  });

  testWidgets('EN: Beschriftung englisch', (tester) async {
    await pump(tester, entry(locs: const ['Office']), locale: 'en');
    expect(find.text('Work location'), findsOneWidget);
    expect(find.byTooltip('Remove Office'), findsOneWidget);
  });

  testWidgets('Typ Urlaub: keine Eingabe, Originalwert bleibt', (tester) async {
    await pump(
        tester, entry(locs: const ['Büro'], type: WorkEntryType.vacation));
    expect(find.byType(WorkLocationsInput), findsNothing);
    await tester.tap(find.text('Änderungen speichern'));
    await tester.pumpAndSettle();
    expect(reports.saved.single.workLocations, ['Büro']);
  });

  for (final locale in ['de', 'en']) {
    testWidgets('schmale Breite: kein Overflow ($locale)', (tester) async {
      await pump(
          tester, entry(locs: const ['Zentrale Düsseldorf, Königsallee 1']),
          locale: locale, width: 280);
      expect(tester.takeException(), isNull);
    });
  }
}
