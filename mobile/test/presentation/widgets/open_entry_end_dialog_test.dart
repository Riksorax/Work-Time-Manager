import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/break_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/widgets/open_entry_end_dialog.dart';

const eight = Duration(hours: 8);

WorkEntryEntity entryOn(DateTime start,
        {List<BreakEntity> breaks = const []}) =>
    WorkEntryEntity(
      id: 'e',
      date: DateTime(start.year, start.month, start.day),
      workStart: start,
      breaks: breaks,
    );

void main() {
  DateTime? result;
  var resultSet = false;

  Future<void> open(
    WidgetTester tester, {
    required WorkEntryEntity entry,
    required DateTime now,
    Duration dailyTarget = eight,
    bool use24HourFormat = true,
    String locale = 'de',
    OpenEntryDatePicker? pickDate,
    OpenEntryTimePicker? pickTime,
  }) async {
    result = null;
    resultSet = false;
    await tester.pumpWidget(MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await showOpenEntryEndDialog(
                context,
                entry: entry,
                now: now,
                dailyTarget: dailyTarget,
                use24HourFormat: use24HourFormat,
                pickDate: pickDate,
                pickTime: pickTime,
              );
              resultSet = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder confirm() => find.widgetWithText(FilledButton, 'Eintrag beenden');

  bool confirmEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(confirm()).onPressed != null;

  final friStart = DateTime(2026, 10, 2, 8);
  final satMorning = DateTime(2026, 10, 3, 9);

  testWidgets('Soll-Ende ist vorbelegt, Bestätigen liefert das Datum',
      (tester) async {
    await open(tester, entry: entryOn(friStart), now: satMorning);
    expect(find.text('Ende des Eintrags festlegen'), findsOneWidget);
    expect(find.text('Soll-Ende (16:00)'), findsOneWidget);
    expect(find.text('16:00'), findsWidgets);
    expect(confirmEnabled(tester), isTrue);

    await tester.tap(confirm());
    await tester.pumpAndSettle();
    expect(resultSet, isTrue);
    expect(result, DateTime(2026, 10, 2, 16));
  });

  testWidgets('geschlossene Pausen verschieben das Soll-Ende', (tester) async {
    final e = entryOn(friStart, breaks: [
      BreakEntity(
          id: 'b',
          name: 'P',
          start: DateTime(2026, 10, 2, 12),
          end: DateTime(2026, 10, 2, 12, 30)),
    ]);
    await open(tester, entry: e, now: satMorning);
    await tester.tap(confirm());
    await tester.pumpAndSettle();
    expect(result, DateTime(2026, 10, 2, 16, 30));
  });

  testWidgets('Abbrechen liefert null', (tester) async {
    await open(tester, entry: entryOn(friStart), now: satMorning);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(resultSet, isTrue);
    expect(result, isNull);
  });

  testWidgets('"Jetzt" ist bei höchstens 24 h sichtbar und setzt die Uhr',
      (tester) async {
    // Fr 22:00, Soll 8 h -> Soll-Ende Sa 06:00 liegt nach jetzt (Sa 02:00)
    await open(tester,
        entry: entryOn(DateTime(2026, 10, 2, 22)),
        now: DateTime(2026, 10, 3, 2, 0, 40));
    expect(find.text('Jetzt'), findsOneWidget);
    expect(find.textContaining('Soll-Ende'), findsNothing,
        reason: 'Soll-Ende liegt nach jetzt, keine Schnellwahl');
    expect(confirmEnabled(tester), isTrue);
    await tester.tap(confirm());
    await tester.pumpAndSettle();
    expect(result, DateTime(2026, 10, 3, 2, 0));
  });

  testWidgets('älter als 24 h und ohne Soll: kein "Jetzt", keine Vorbelegung',
      (tester) async {
    await open(tester,
        entry: entryOn(DateTime(2026, 10, 3, 10)),
        now: DateTime(2026, 10, 5, 9),
        dailyTarget: Duration.zero);
    expect(find.text('Jetzt'), findsNothing);
    expect(find.text('Uhrzeit wählen'), findsOneWidget);
    expect(confirmEnabled(tester), isFalse);
  });

  testWidgets('Datumsbereich der Wahl ist [Starttag, heute]', (tester) async {
    await open(tester,
        entry: entryOn(DateTime(2026, 9, 30, 8)),
        now: DateTime(2026, 10, 3, 9));
    await tester.tap(find.byKey(const Key('openEntryEndDate')));
    await tester.pumpAndSettle();
    final picker =
        tester.widget<CalendarDatePicker>(find.byType(CalendarDatePicker));
    expect(picker.firstDate, DateTime(2026, 9, 30));
    expect(picker.lastDate, DateTime(2026, 10, 3));
  });

  group('Validierung (Text, Bestätigen gesperrt)', () {
    testWidgets('Ende vor dem Start', (tester) async {
      await open(tester,
          entry: entryOn(friStart),
          now: satMorning,
          pickTime: (context, initial) async =>
              const TimeOfDay(hour: 7, minute: 0));
      await tester.tap(find.byKey(const Key('openEntryEndTime')));
      await tester.pumpAndSettle();
      expect(find.text('Das Ende muss nach dem Start und vor jetzt liegen.'),
          findsOneWidget);
      expect(confirmEnabled(tester), isFalse);
    });

    testWidgets('Ende nach jetzt', (tester) async {
      await open(tester,
          entry: entryOn(DateTime(2026, 10, 3, 6)),
          now: DateTime(2026, 10, 4, 9),
          pickDate: (context, initial, first, last) async =>
              DateTime(2026, 10, 4),
          pickTime: (context, initial) async =>
              const TimeOfDay(hour: 10, minute: 0));
      await tester.tap(find.byKey(const Key('openEntryEndDate')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('openEntryEndTime')));
      await tester.pumpAndSettle();
      expect(find.text('Das Ende muss nach dem Start und vor jetzt liegen.'),
          findsOneWidget);
      expect(confirmEnabled(tester), isFalse);
    });

    testWidgets('Ende vor dem Beginn der letzten Pause', (tester) async {
      final e = entryOn(friStart, breaks: [
        BreakEntity(
            id: 'b',
            name: 'P',
            start: DateTime(2026, 10, 2, 12),
            end: DateTime(2026, 10, 2, 12, 30)),
      ]);
      await open(tester,
          entry: e,
          now: satMorning,
          pickTime: (context, initial) async =>
              const TimeOfDay(hour: 11, minute: 0));
      await tester.tap(find.byKey(const Key('openEntryEndTime')));
      await tester.pumpAndSettle();
      expect(find.text('Das Ende muss nach dem Start und vor jetzt liegen.'),
          findsOneWidget);
      expect(confirmEnabled(tester), isFalse);
    });

    testWidgets('gültige Eingabe löscht den Fehler', (tester) async {
      var hour = 7;
      await open(tester,
          entry: entryOn(friStart),
          now: satMorning,
          pickTime: (context, initial) async =>
              TimeOfDay(hour: hour, minute: 0));
      await tester.tap(find.byKey(const Key('openEntryEndTime')));
      await tester.pumpAndSettle();
      expect(confirmEnabled(tester), isFalse);
      hour = 15;
      await tester.tap(find.byKey(const Key('openEntryEndTime')));
      await tester.pumpAndSettle();
      expect(find.text('Das Ende muss nach dem Start und vor jetzt liegen.'),
          findsNothing);
      expect(confirmEnabled(tester), isTrue);
    });
  });

  testWidgets('Warnung bei mehr als 16 h Netto ist weich (bestätigbar)',
      (tester) async {
    await open(tester,
        entry: entryOn(DateTime(2026, 10, 1, 8)),
        now: satMorning,
        pickDate: (context, initial, first, last) async =>
            DateTime(2026, 10, 2),
        pickTime: (context, initial) async =>
            const TimeOfDay(hour: 2, minute: 0));
    await tester.tap(find.byKey(const Key('openEntryEndDate')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('openEntryEndTime')));
    await tester.pumpAndSettle();
    expect(find.text('Das ergibt mehr als 16 Stunden. Stimmt das?'),
        findsOneWidget);
    expect(confirmEnabled(tester), isTrue);
    await tester.tap(confirm());
    await tester.pumpAndSettle();
    expect(result, DateTime(2026, 10, 2, 2));
  });

  testWidgets('keine Warnung bei normaler Dauer', (tester) async {
    await open(tester, entry: entryOn(friStart), now: satMorning);
    expect(
        find.text('Das ergibt mehr als 16 Stunden. Stimmt das?'), findsNothing);
  });

  testWidgets('Titel ist ein Semantics-Header', (tester) async {
    final handle = tester.ensureSemantics();
    await open(tester, entry: entryOn(friStart), now: satMorning);
    final data = tester.getSemantics(find.text('Ende des Eintrags festlegen'));
    expect(data.flagsCollection.isHeader, isTrue);
    handle.dispose();
  });

  testWidgets('englisch, 12-h-Format', (tester) async {
    await open(tester,
        entry: entryOn(friStart),
        now: satMorning,
        locale: 'en',
        use24HourFormat: false);
    expect(find.text('Set the end of the entry'), findsOneWidget);
    expect(find.text('Target end (4:00 PM)'), findsOneWidget);
    expect(find.text('End entry'), findsOneWidget);
  });
}
