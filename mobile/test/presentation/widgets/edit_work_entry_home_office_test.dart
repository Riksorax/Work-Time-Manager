import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/view_models/edit_work_entry_view_model.dart';
import 'package:flutter_work_time/presentation/widgets/edit_work_entry_modal.dart';

// Home-Office-Schalter im Bearbeiten-Dialog (#277). Feste Daten, DE und EN.
void main() {
  final day = DateTime(2026, 6, 5);

  WorkEntryEntity entry({
    bool homeOffice = false,
    WorkEntryType type = WorkEntryType.work,
  }) =>
      WorkEntryEntity(
        id: '2026-06-05',
        date: day,
        workStart: DateTime(2026, 6, 5, 8),
        workEnd: DateTime(2026, 6, 5, 16),
        type: type,
        isHomeOffice: homeOffice,
      );

  Future<ProviderContainer> pump(
    WidgetTester tester,
    WorkEntryEntity e, {
    Locale locale = const Locale('de'),
    double width = 800,
  }) async {
    tester.view.physicalSize = Size(width, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: EditWorkEntryModal(workEntry: e)),
      ),
    ));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('DE: Schalter bei Typ Arbeit sichtbar, Initialzustand aus',
      (tester) async {
    await pump(tester, entry());
    final tile = find.widgetWithText(SwitchListTile, 'Von zu Hause gearbeitet');
    expect(tile, findsOneWidget);
    expect(tester.widget<SwitchListTile>(tile).value, isFalse);
  });

  testWidgets('EN: Label englisch, Initialzustand an', (tester) async {
    await pump(tester, entry(homeOffice: true), locale: const Locale('en'));
    final tile = find.widgetWithText(SwitchListTile, 'Worked from home');
    expect(tile, findsOneWidget);
    expect(tester.widget<SwitchListTile>(tile).value, isTrue);
  });

  testWidgets('Umschalten aendert den ViewModel-State', (tester) async {
    final e = entry();
    final container = await pump(tester, e);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(
        container.read(editWorkEntryViewModelProvider(e)).isHomeOffice, isTrue);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue);
  });

  testWidgets('bei Typ Urlaub nicht sichtbar', (tester) async {
    await pump(tester, entry(type: WorkEntryType.vacation, homeOffice: true));
    expect(find.byType(SwitchListTile), findsNothing);
  });

  testWidgets('DE: kein Overflow bei schmaler Breite', (tester) async {
    await pump(tester, entry(), width: 280);
    expect(tester.takeException(), isNull);
    expect(find.byType(SwitchListTile), findsOneWidget);
  });

  testWidgets('EN: kein Overflow bei schmaler Breite', (tester) async {
    await pump(tester, entry(), width: 280, locale: const Locale('en'));
    expect(tester.takeException(), isNull);
    expect(find.byType(SwitchListTile), findsOneWidget);
  });
}
