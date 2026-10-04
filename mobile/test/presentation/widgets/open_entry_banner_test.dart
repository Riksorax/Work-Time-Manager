import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/clock_provider.dart';
import 'package:flutter_work_time/domain/entities/settings_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/usecases/close_open_work_entry.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/state/settings_state.dart';
import 'package:flutter_work_time/presentation/view_models/open_entry_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/settings_view_model.dart';
import 'package:flutter_work_time/presentation/widgets/open_entry_banner.dart';

class _FakeVm extends OpenEntryViewModel {
  _FakeVm(this.initial, {this.result = CloseOpenEntryResult.closed});
  final OpenEntryState initial;
  final CloseOpenEntryResult result;
  static int laterCalls = 0;
  static final List<DateTime> ends = [];

  @override
  OpenEntryState build() => initial;

  @override
  Duration targetFor(WorkEntryEntity entry) => const Duration(hours: 8);

  @override
  void later() {
    laterCalls++;
    state = const OpenEntryState();
  }

  @override
  Future<CloseOpenEntryResult?> endEntry(DateTime end) async {
    ends.add(end);
    return result;
  }
}

bool _use24 = true;

class _FakeSettings extends SettingsViewModel {
  @override
  AsyncValue<SettingsState> build() => AsyncValue.data(SettingsState(
        settings: SettingsEntity(use24HourFormat: _use24),
        overtimeBalance: Duration.zero,
      ));
}

WorkEntryEntity _entry(DateTime day, {int startHour = 22}) => WorkEntryEntity(
      id: 'e${day.day}',
      date: day,
      workStart: DateTime(day.year, day.month, day.day, startHour),
    );

void main() {
  final fri = DateTime(2026, 10, 2);
  final thu = DateTime(2026, 10, 1);
  final now = DateTime(2026, 10, 3, 9);

  setUp(() {
    _use24 = true;
    _FakeVm.laterCalls = 0;
    _FakeVm.ends.clear();
  });

  Future<void> pump(
    WidgetTester tester,
    OpenEntryState state, {
    String locale = 'de',
    double? textScale,
    ThemeData? theme,
    CloseOpenEntryResult result = CloseOpenEntryResult.closed,
  }) async {
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        openEntryViewModelProvider
            .overrideWith(() => _FakeVm(state, result: result)),
        settingsViewModelProvider.overrideWith(_FakeSettings.new),
        clockProvider.overrideWithValue(() => now),
      ],
      child: MaterialApp(
        locale: Locale(locale),
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: textScale == null
            ? null
            : (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(textScale)),
                  child: child!,
                ),
        home: const Scaffold(
            body: SingleChildScrollView(child: OpenEntryBanner())),
      ),
    ));
    await tester.pump();
  }

  OpenEntryState one() => OpenEntryState(entries: [_entry(fri)]);

  testWidgets('zeigt deutschen Text mit Datum und Startzeit', (tester) async {
    await pump(tester, one());
    expect(find.text('Dein Eintrag vom Fr., 2. Okt. läuft noch seit 22:00.'),
        findsOneWidget);
    expect(find.text('Beenden'), findsOneWidget);
    expect(find.text('Später'), findsOneWidget);
  });

  testWidgets('englisch, Uhrzeit folgt use24HourFormat', (tester) async {
    _use24 = false;
    await pump(tester, one(), locale: 'en');
    expect(
        find.text(
            'Your entry from Fri, Oct 2 has been running since 10:00 PM.'),
        findsOneWidget);
    expect(find.text('End'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
  });

  testWidgets('"weitere" nur bei mehr als einem Eintrag', (tester) async {
    await pump(tester, one());
    expect(find.textContaining('weitere'), findsNothing);
    expect(find.textContaining('weiterer'), findsNothing);

    await pump(
        tester,
        OpenEntryState(entries: [
          _entry(fri),
          _entry(thu),
          _entry(DateTime(2026, 9, 30))
        ]));
    expect(find.text('Noch 2 weitere offene Einträge'), findsOneWidget);

    await pump(tester, OpenEntryState(entries: [_entry(fri), _entry(thu)]));
    expect(find.text('Noch 1 weiterer offener Eintrag'), findsOneWidget);
  });

  testWidgets('nichts gerendert bei leerem Zustand', (tester) async {
    await pump(tester, const OpenEntryState());
    expect(find.byType(FilledButton), findsNothing);
    expect(find.textContaining('Dein Eintrag'), findsNothing);
  });

  testWidgets('Später blendet den Banner aus', (tester) async {
    await pump(tester, one());
    await tester.tap(find.text('Später'));
    await tester.pump();
    expect(_FakeVm.laterCalls, 1);
    expect(find.textContaining('Dein Eintrag'), findsNothing);
  });

  testWidgets('Buttons: Mindestgröße 48 dp', (tester) async {
    await pump(tester, one());
    for (final label in ['Beenden', 'Später']) {
      final size = tester.getSize(find
          .ancestor(
              of: find.text(label),
              matching: find.byWidgetPredicate((w) => w is ButtonStyleButton))
          .first);
      expect(size.height, greaterThanOrEqualTo(48), reason: label);
      expect(size.width, greaterThanOrEqualTo(48), reason: label);
    }
  });

  testWidgets(
      'Semantics: Container als Live-Region, Buttons mit Datum im Label',
      (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, one());

    final banner = tester.getSemantics(find
        .bySemanticsLabel(RegExp(r'^Dein Eintrag vom Fr\., 2\. Okt\.'))
        .first);
    expect(banner.flagsCollection.isLiveRegion, isTrue);

    expect(find.bySemanticsLabel('Eintrag vom Fr., 2. Okt. beenden'),
        findsOneWidget);
    expect(find.bySemanticsLabel('Eintrag vom Fr., 2. Okt. später bearbeiten'),
        findsOneWidget);
    final end = tester.getSemantics(
        find.bySemanticsLabel('Eintrag vom Fr., 2. Okt. beenden'));
    expect(end.flagsCollection.isButton, isTrue);
    expect(end.flagsCollection.isEnabled, Tristate.isTrue);
    handle.dispose();
  });

  testWidgets('Buttons sind einzeln per Tab fokussierbar', (tester) async {
    await pump(tester, one());
    String? focusedLabel() {
      final ctx = FocusManager.instance.primaryFocus?.context;
      if (ctx == null) return null;
      String? label;
      ctx.visitChildElements((e) {
        void walk(Element el) {
          if (label != null) return;
          final w = el.widget;
          if (w is Text) {
            label = w.data;
            return;
          }
          el.visitChildren(walk);
        }

        walk(e);
      });
      return label;
    }

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final first = focusedLabel();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final second = focusedLabel();
    expect({first, second}, {'Später', 'Beenden'});
  });

  testWidgets('schmal (320 px, Textskalierung 2.0): kein Overflow, Wrap',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(tester, OpenEntryState(entries: [_entry(fri), _entry(thu)]),
        textScale: 2.0);
    expect(tester.takeException(), isNull);
    expect(
        find.descendant(
            of: find.byType(OpenEntryBanner), matching: find.byType(Wrap)),
        findsOneWidget);
    expect(find.text('Beenden'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets('Farben aus dem ColorScheme (${dark ? 'dunkel' : 'hell'})',
        (tester) async {
      final theme = dark
          ? ThemeData(brightness: Brightness.dark, useMaterial3: true)
          : ThemeData(useMaterial3: true);
      await pump(tester, one(), theme: theme);
      final scheme = theme.colorScheme;
      final box = tester.widget<Container>(find
          .descendant(
              of: find.byType(OpenEntryBanner),
              matching: find.byType(Container))
          .first);
      expect(
          (box.decoration! as BoxDecoration).color, scheme.secondaryContainer);
      expect(scheme.secondaryContainer, isNot(scheme.tertiaryContainer),
          reason: 'unterscheidet sich vom Feiertag-Banner');
      final text = tester.widget<Text>(find.textContaining('Dein Eintrag'));
      expect(text.style?.color, scheme.onSecondaryContainer);
    });
  }

  testWidgets('busy: Buttons deaktiviert', (tester) async {
    await pump(tester, OpenEntryState(entries: [_entry(fri)], busy: true));
    for (final b in tester.widgetList<ButtonStyleButton>(
        find.byWidgetPredicate((w) => w is ButtonStyleButton))) {
      expect(b.onPressed, isNull);
    }
  });

  testWidgets('Beenden -> Dialog -> Bestätigen ruft endEntry mit Soll-Ende',
      (tester) async {
    await pump(tester, one());
    await tester.tap(find.text('Beenden'));
    await tester.pumpAndSettle();
    expect(find.text('Ende des Eintrags festlegen'), findsOneWidget);
    await tester.tap(find.text('Eintrag beenden'));
    await tester.pumpAndSettle();
    // Fr 22:00 + 8 h = Sa 06:00 < jetzt (Sa 09:00)
    expect(_FakeVm.ends, [DateTime(2026, 10, 3, 6)]);
    expect(find.text('Eintrag konnte nicht beendet werden.'), findsNothing);
  });

  testWidgets('Abbrechen im Dialog ruft endEntry nicht auf', (tester) async {
    await pump(tester, one());
    await tester.tap(find.text('Beenden'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(_FakeVm.ends, isEmpty);
  });

  testWidgets('Fehler: Snackbar, Banner bleibt', (tester) async {
    await pump(tester, one(), result: CloseOpenEntryResult.failed);
    await tester.tap(find.text('Beenden'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eintrag beenden'));
    await tester.pumpAndSettle();
    expect(find.text('Eintrag konnte nicht beendet werden.'), findsOneWidget);
    expect(find.textContaining('Dein Eintrag'), findsOneWidget);
  });
}
