import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/clock_provider.dart';
import 'package:flutter_work_time/domain/entities/break_entity.dart';
import 'package:flutter_work_time/domain/entities/settings_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/state/settings_state.dart';
import 'package:flutter_work_time/presentation/view_models/edit_work_entry_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/open_entry_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/settings_view_model.dart';
import 'package:flutter_work_time/presentation/widgets/edit_work_entry_modal.dart';
import 'package:flutter_work_time/presentation/widgets/open_entry_banner.dart';
import 'package:flutter_work_time/presentation/widgets/open_entry_end_dialog.dart';

/// Block B (#418): Bearbeiten-Dialog und Anzeige-Stellen (Banner, Beenden-
/// Dialog) bilden den Tag des Eintrags ueber `entryDay`. Fixtures sind
/// **inkonsistent** (Id Montag 2026-10-05, `date` Sonntag 2026-10-04),
/// zonenunabhaengig; Texte deutsch (`locale: de`).
final _monday = WorkEntryEntity(
  id: '2026-10-05',
  date: DateTime(2026, 10, 4),
  workStart: DateTime(2026, 10, 5, 8),
  workEnd: DateTime(2026, 10, 5, 16),
  breaks: [
    BreakEntity(
      id: 'b1',
      name: 'Pause',
      start: DateTime(2026, 10, 5, 12),
      end: DateTime(2026, 10, 5, 12, 30),
    ),
  ],
);

class _FakeOpenEntryVm extends OpenEntryViewModel {
  _FakeOpenEntryVm(this.initial);
  final OpenEntryState initial;

  @override
  OpenEntryState build() => initial;

  @override
  Duration targetFor(WorkEntryEntity entry) => const Duration(hours: 8);
}

class _FakeSettings extends SettingsViewModel {
  @override
  AsyncValue<SettingsState> build() => const AsyncValue.data(SettingsState(
        settings: SettingsEntity(),
        overtimeBalance: Duration.zero,
      ));
}

Widget _app(Widget home, {List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );

void main() {
  group('EditWorkEntryViewModel', () {
    test('addBreak ohne Startzeit liegt am Tag der Id (#397/#418)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final entry = WorkEntryEntity(
        id: '2026-10-05',
        date: DateTime(2026, 10, 4),
      );
      container.read(editWorkEntryViewModelProvider(entry).notifier).addBreak();
      final start = container
          .read(editWorkEntryViewModelProvider(entry))
          .breaks
          .single
          .start;
      expect(
          DateTime(start.year, start.month, start.day), DateTime(2026, 10, 5));
    });
  });

  group('EditWorkEntryModal', () {
    late ProviderContainer container;

    Future<void> pumpModal(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
          _app(Scaffold(body: EditWorkEntryModal(workEntry: _monday))));
      await tester.pumpAndSettle();
      container = ProviderScope.containerOf(
          tester.element(find.byType(EditWorkEntryModal)));
    }

    /// Oeffnet den Zeit-Dialog des [fieldIndex]-ten Feldes (Start, Ende,
    /// Pause-Start, Pause-Ende) und bestaetigt die vorbelegte Uhrzeit.
    Future<void> pickSameTime(WidgetTester tester, int fieldIndex) async {
      await tester.tap(find.byType(TextFormField).at(fieldIndex));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    }

    testWidgets('Ueberschrift zeigt den 05.10.2026 (Tag der Id)',
        (tester) async {
      await pumpModal(tester);
      expect(find.textContaining('5.10.2026'), findsOneWidget);
      expect(find.textContaining('4.10.2026'), findsNothing);
    });

    testWidgets('Start- und Endzeit werden am Tag der Id kombiniert',
        (tester) async {
      await pumpModal(tester);
      await pickSameTime(tester, 0);
      await pickSameTime(tester, 1);
      final state = container.read(editWorkEntryViewModelProvider(_monday));
      expect(state.newStartTime, DateTime(2026, 10, 5, 8));
      expect(state.newEndTime, DateTime(2026, 10, 5, 16));
    });

    testWidgets('Pausenzeiten werden am Tag der Id kombiniert', (tester) async {
      await pumpModal(tester);
      await pickSameTime(tester, 2);
      await pickSameTime(tester, 3);
      final b =
          container.read(editWorkEntryViewModelProvider(_monday)).breaks.single;
      expect(b.start, DateTime(2026, 10, 5, 12));
      expect(b.end, DateTime(2026, 10, 5, 12, 30));
    });
  });

  group('Anzeige-Stellen', () {
    testWidgets('OpenEntryBanner zeigt den Tag der Id (Mo., 5. Okt.)',
        (tester) async {
      final entry = WorkEntryEntity(
        id: '2026-10-05',
        date: DateTime(2026, 10, 4),
        workStart: DateTime(2026, 10, 5, 8),
      );
      await tester.pumpWidget(_app(
        const Scaffold(body: SingleChildScrollView(child: OpenEntryBanner())),
        overrides: [
          openEntryViewModelProvider.overrideWith(
              () => _FakeOpenEntryVm(OpenEntryState(entries: [entry]))),
          settingsViewModelProvider.overrideWith(_FakeSettings.new),
          clockProvider.overrideWithValue(() => DateTime(2026, 10, 6, 9)),
        ],
      ));
      await tester.pump();
      expect(find.text('Dein Eintrag vom Mo., 5. Okt. läuft noch seit 08:00.'),
          findsOneWidget);
    });

    testWidgets('Beenden-Dialog fragt nach dem Tag der Id (Fr., 2. Okt.)',
        (tester) async {
      final entry = WorkEntryEntity(
        id: '2026-10-02',
        date: DateTime(2026, 10, 1),
        workStart: DateTime(2026, 10, 2, 8),
      );
      await tester.pumpWidget(_app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showOpenEntryEndDialog(
                context,
                entry: entry,
                now: DateTime(2026, 10, 3, 9),
                dailyTarget: const Duration(hours: 8),
                use24HourFormat: true,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(
          find.text('Wann hast du am Fr., 2. Okt. aufgehört?'), findsOneWidget);
    });
  });
}
