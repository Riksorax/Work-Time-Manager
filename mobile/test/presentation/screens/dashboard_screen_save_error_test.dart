import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/clock_provider.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/domain/entities/break_entity.dart';
import 'package:flutter_work_time/domain/entities/bundesland.dart';
import 'package:flutter_work_time/domain/entities/settings_entity.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/screens/dashboard_screen.dart';
import 'package:flutter_work_time/presentation/state/leave_balance_state.dart';
import 'package:flutter_work_time/presentation/state/settings_state.dart';
import 'package:flutter_work_time/presentation/view_models/leave_balance_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/open_entry_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/settings_view_model.dart';

import '../../support/dashboard_harness.dart';
import '../../support/fake_repositories.dart';

// Saldo-Fehler beim Stoppen (#402): Snackbar mit lokalisiertem Text, der
// Eintrag laeuft weiter. Feste Daten: Mo 2026-10-05, Uhr 17:00, Start 08:00.
const _de = 'Speichern fehlgeschlagen. Bitte prüfe deine Verbindung und '
    'versuche es erneut.';
const _en = 'Saving failed. Please check your connection and try again.';

class _FakeOpenEntryViewModel extends OpenEntryViewModel {
  @override
  OpenEntryState build() => const OpenEntryState();
}

class _FakeSettingsViewModel extends SettingsViewModel {
  @override
  AsyncValue<SettingsState> build() => AsyncValue.data(SettingsState(
      settings: SettingsEntity(bundesland: Bundesland.bayern),
      overtimeBalance: Duration.zero));
}

class _FakeLeaveViewModel extends LeaveBalanceViewModel {
  @override
  LeaveBalanceState build() => const LeaveBalanceState();
}

void main() {
  final mo = DateTime(2026, 10, 5);
  final now = DateTime(2026, 10, 5, 17);
  late FakeWorkRepository work;
  late FakeOvertimeRepository overtime;

  setUp(() {
    work = FakeWorkRepository()
      ..store[dayKey(mo)] = entryOf(mo, start: DateTime(2026, 10, 5, 8));
    overtime = FakeOvertimeRepository()..stored = const Duration(minutes: 120);
  });

  Future<void> pump(WidgetTester tester, String locale) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        workRepositoryProvider.overrideWithValue(work),
        overtimeRepositoryProvider.overrideWithValue(overtime),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        openEntryViewModelProvider.overrideWith(_FakeOpenEntryViewModel.new),
        settingsViewModelProvider.overrideWith(_FakeSettingsViewModel.new),
        leaveBalanceViewModelProvider.overrideWith(_FakeLeaveViewModel.new),
        authStateProvider
            .overrideWithValue(const AsyncValue<UserEntity?>.data(null)),
        clockProvider.overrideWithValue(() => now),
      ],
      child: MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const DashboardScreen(),
      ),
    ));
    // Laden des Dashboards (Fake-Repos, nur Microtasks).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Baut den Baum ab, damit Timer des ViewModels/`todayProvider` enden.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  for (final (locale, stop, text) in [
    ('de', 'Zeiterfassung beenden', _de),
    ('en', 'Stop time tracking', _en),
  ]) {
    group('Sprache $locale', () {
      testWidgets('Stop bei Saldo-Fehler: Snackbar, Eintrag laeuft weiter',
          (tester) async {
        overtime.failSaveOvertime = true;
        await pump(tester, locale);
        expect(find.text(stop), findsOneWidget);

        await tester.tap(find.text(stop));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text(text), findsOneWidget);
        expect(find.text(stop), findsOneWidget, reason: 'Eintrag laeuft noch');
        expect(overtime.savedOvertimes, isEmpty);
        expect(work.saved, isEmpty);
        await unmount(tester);
      });

      testWidgets('Stop bei Erfolg: kein Snackbar', (tester) async {
        await pump(tester, locale);

        await tester.tap(find.text(stop));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text(text), findsNothing);
        expect(find.byType(SnackBar), findsNothing);
        expect(find.text(stop), findsNothing, reason: 'Eintrag gestoppt');
        expect(overtime.savedOvertimes, hasLength(1));
        expect(work.saved, hasLength(1));
        await unmount(tester);
      });
    });
  }

  // Reentranz-Sperre (#413): waehrend eines Writes sind alle Schreib-Eingaben
  // deaktiviert, ein weiterer Tap bleibt ohne Wirkung und ohne Snackbar.
  for (final (locale, stop, addBreak, endBreak, startLabel, errText) in [
    (
      'de',
      'Zeiterfassung beenden',
      'Pause hinzufügen',
      'Pause beenden',
      'Startzeit',
      _de
    ),
    ('en', 'Stop time tracking', 'Add break', 'End break', 'Start time', _en),
  ]) {
    group('Sperre waehrend des Speicherns ($locale)', () {
      testWidgets('Buttons und Felder deaktiviert, danach wieder aktiv',
          (tester) async {
        work.holdSaves = true;
        await pump(tester, locale);
        ElevatedButton button(String label) => tester
            .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, label));
        expect(button(stop).onPressed, isNotNull);
        expect(button(addBreak).onPressed, isNotNull);

        await tester.tap(find.text(addBreak));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(work.pendingSaves, hasLength(1));
        expect(button(stop).onPressed, isNull);
        expect(button(endBreak).onPressed, isNull);
        expect(
            tester
                .widget<TextField>(find.widgetWithText(TextField, startLabel))
                .enabled,
            isFalse);
        final delete = tester
            .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.delete));
        expect(delete.onPressed, isNull);

        // Weitere Taps bleiben ohne Wirkung und ohne Snackbar.
        await tester.tap(find.text(stop), warnIfMissed: false);
        await tester.tap(find.text(endBreak), warnIfMissed: false);
        await tester.pump();
        expect(work.pendingSaves, hasLength(1));
        expect(find.byType(SnackBar), findsNothing);
        expect(find.text(errText), findsNothing);

        work.holdSaves = false;
        work.pendingSaves.single.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(button(stop).onPressed, isNotNull);
        expect(button(endBreak).onPressed, isNotNull);
        expect(
            tester
                .widget<TextField>(find.widgetWithText(TextField, startLabel))
                .enabled,
            isTrue);
        expect(find.byType(SnackBar), findsNothing);
        await unmount(tester);
      });
    });
  }

  // Weitere Aktionen des Dashboards mit Saldo-Block (Aufrufer im Screen):
  // Saldo-Fehler zeigt die Snackbar, der Eintrag bleibt unveraendert.
  group('weitere Aktionen bei Saldo-Fehler', () {
    final end = DateTime(2026, 10, 5, 17);
    final b1 = BreakEntity(
        id: 'b1',
        name: 'Pause 1',
        start: DateTime(2026, 10, 5, 12),
        end: DateTime(2026, 10, 5, 12, 30));

    void seedFinished({bool withBreak = false}) {
      work.store[dayKey(mo)] = entryOf(mo,
          start: DateTime(2026, 10, 5, 8),
          end: end,
          breaks: withBreak ? [b1] : const []);
    }

    Future<void> expectSnackbar(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(_en), findsOneWidget);
      expect(overtime.savedOvertimes, isEmpty);
      expect(work.saved, isEmpty);
      await unmount(tester);
    }

    testWidgets('Startzeit aendern', (tester) async {
      seedFinished();
      overtime.failSaveOvertime = true;
      await pump(tester, 'en');
      await tester.tap(find.widgetWithText(TextField, 'Start time'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('OK'));
      await tester.pump(const Duration(milliseconds: 500));
      await expectSnackbar(tester);
    });

    testWidgets('Endzeit aendern', (tester) async {
      seedFinished();
      overtime.failSaveOvertime = true;
      await pump(tester, 'en');
      await tester.tap(find.widgetWithText(TextField, 'End time'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('OK'));
      await tester.pump(const Duration(milliseconds: 500));
      await expectSnackbar(tester);
    });

    testWidgets('Pause hinzufuegen', (tester) async {
      seedFinished();
      overtime.failSaveOvertime = true;
      await pump(tester, 'en');
      await tester.tap(find.text('Add break'));
      await expectSnackbar(tester);
    });

    testWidgets('Pause loeschen', (tester) async {
      seedFinished(withBreak: true);
      overtime.failSaveOvertime = true;
      await pump(tester, 'en');
      await tester.tap(find.byIcon(Icons.delete).first);
      await expectSnackbar(tester);
    });
  });
}
