import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/widgets/work_locations_sheet.dart';

// Bottom Sheet „Arbeitsorte“ (#526) mit Chips und Vorschlägen.
void main() {
  const history = ['Büro Köln', 'Kunde A', 'Lager', 'Messe Essen'];
  List<String> suggest(List<String> selected, String filter) => [
        for (final h in history)
          if (!selected.any((s) => s.toLowerCase() == h.toLowerCase()) &&
              h.toLowerCase().contains(filter.trim().toLowerCase()))
            h
      ];

  late List<String>? result;
  late bool closed;

  Future<void> open(
    WidgetTester tester, {
    List<String> locations = const [],
    String locale = 'de',
    double width = 412,
    double keyboard = 0,
    double navBar = 0,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 900);
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
    tester.view.viewPadding = FakeViewPadding(bottom: navBar);
    tester.view.padding = FakeViewPadding(bottom: navBar);
    addTearDown(tester.view.reset);
    result = null;
    closed = false;
    await tester.pumpWidget(MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                result = await showWorkLocationsSheet(context,
                    locations: locations, suggestions: suggest);
                closed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder field() => find.byType(TextField);

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(field(), text);
    await tester.pump();
  }

  Future<void> enter(WidgetTester tester) async {
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  testWidgets('Vorschlagsliste ist beim Öffnen zu, Antippen öffnet sie',
      (tester) async {
    await open(tester);
    expect(find.text('Arbeitsorte'), findsOneWidget);
    expect(find.text('Messe Essen'), findsNothing);

    await tester.tap(field());
    await tester.pumpAndSettle();
    expect(find.text('Messe Essen'), findsOneWidget);
    // Die Buttons bleiben frei (die Liste öffnet nach oben).
    final list = tester.getRect(find
        .ancestor(of: find.text('Messe Essen'), matching: find.byType(Material))
        .first);
    final save = tester.getRect(find.text('Speichern'));
    expect(list.bottom, lessThanOrEqualTo(tester.getRect(field()).top + 1));
    expect(list.overlaps(save), isFalse);
  });

  testWidgets('Vorschlag antippen fügt hinzu und schließt die Liste',
      (tester) async {
    await open(tester);
    await tester.tap(field());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kunde A'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(InputChip, 'Kunde A'), findsOneWidget);
    expect(find.text('Messe Essen'), findsNothing);
  });

  testWidgets('Tippen filtert die Vorschläge', (tester) async {
    await open(tester);
    await tester.tap(field());
    await type(tester, 'mes');
    await tester.pumpAndSettle();
    expect(find.text('Messe Essen'), findsOneWidget);
    expect(find.text('Lager'), findsNothing);
  });

  testWidgets('Enter und Komma fügen hinzu, Speichern liefert die Liste',
      (tester) async {
    await open(tester);
    await tester.tap(field());
    await type(tester, '  Werk 2 ');
    await enter(tester);
    expect(find.widgetWithText(InputChip, 'Werk 2'), findsOneWidget);

    await type(tester, 'Halle 3,Rest');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(InputChip, 'Halle 3'), findsOneWidget);
    expect(tester.widget<TextField>(field()).controller!.text, 'Rest');

    // Noch getippter Text wird beim Speichern übernommen.
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(result, ['Werk 2', 'Halle 3', 'Rest']);
  });

  testWidgets('Duplikat und leer werden nicht übernommen', (tester) async {
    await open(tester, locations: const ['Büro Köln']);
    await tester.tap(field());
    await type(tester, 'büro köln');
    await enter(tester);
    expect(find.text('Dieser Ort ist schon eingetragen.'), findsOneWidget);
    expect(find.byType(InputChip), findsOneWidget);
  });

  testWidgets('ungültiger getippter Text: Sheet bleibt offen und erklärt',
      (tester) async {
    await open(tester);
    await tester.tap(field());
    await type(tester, 'x' * 61);
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(closed, isFalse);
    expect(find.text('Ein Ort darf höchstens 60 Zeichen lang sein.'),
        findsOneWidget);
  });

  testWidgets('bei 5 Orten gesperrt mit Hinweis', (tester) async {
    await open(tester, locations: const ['a', 'b', 'c', 'd', 'e']);
    expect(tester.widget<TextField>(field()).enabled, isFalse);
    expect(
        find.text(
            'Höchstens 5 Orte pro Tag. Entferne einen Ort, um einen neuen hinzuzufügen.'),
        findsOneWidget);
  });

  testWidgets('Entfernen je Ort benannt; alle entfernen liefert []',
      (tester) async {
    final handle = tester.ensureSemantics();
    await open(tester, locations: const ['Büro Köln']);
    expect(find.byTooltip('Büro Köln entfernen'), findsOneWidget);
    await tester.tap(find.byTooltip('Büro Köln entfernen'));
    await tester.pumpAndSettle();
    expect(find.byType(InputChip), findsNothing);
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(result, isEmpty);
    expect(result, isNotNull);
    handle.dispose();
  });

  testWidgets('Abbrechen liefert null', (tester) async {
    await open(tester, locations: const ['Büro Köln']);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(result, isNull);
  });

  testWidgets('Englisch', (tester) async {
    await open(tester, locale: 'en', locations: const ['Büro Köln']);
    expect(find.text('Work locations'), findsOneWidget);
    expect(find.text('Work location'), findsOneWidget);
    expect(find.byTooltip('Remove Büro Köln'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('Tastatur: Inhalt endet über der Tastatur (Edge-to-Edge)',
      (tester) async {
    await open(tester, keyboard: 300, navBar: 24);
    await tester.tap(field());
    await tester.pumpAndSettle();
    final save = tester.getRect(find.text('Speichern'));
    expect(save.bottom, lessThanOrEqualTo(900 - 300));
    expect(tester.takeException(), isNull);
  });

  for (final locale in ['de', 'en']) {
    testWidgets('schmale Breite mit 5 langen Orten: kein Overflow ($locale)',
        (tester) async {
      await open(tester, locale: locale, width: 320, locations: [
        for (var i = 0; i < 5; i++) 'Sehr langer Ortsname Nummer $i, Straße 1'
      ]);
      expect(tester.takeException(), isNull);
    });
  }
}
