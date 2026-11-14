import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/clock_provider.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/theme/app_theme.dart';
import 'package:flutter_work_time/data/repositories/work_location_history.dart';
import 'package:flutter_work_time/domain/entities/settings_entity.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/screens/dashboard_screen.dart';
import 'package:flutter_work_time/presentation/state/leave_balance_state.dart';
import 'package:flutter_work_time/presentation/state/settings_state.dart';
import 'package:flutter_work_time/presentation/view_models/leave_balance_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/open_entry_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/settings_view_model.dart';
import 'package:flutter_work_time/presentation/widgets/work_locations_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_repositories.dart';

// Arbeitsorte im Dashboard (#526): Button bzw. Orte-Zeile je nach Einstellung
// und Typ, Home-Office-Schalter ausblendbar. Feste Daten: Mo 2026-10-05,
// Uhr 17:00, Start 08:00.
class _FakeOpenEntryViewModel extends OpenEntryViewModel {
  @override
  OpenEntryState build() => const OpenEntryState();
}

SettingsEntity _settings = const SettingsEntity();

class _FakeSettingsViewModel extends SettingsViewModel {
  @override
  AsyncValue<SettingsState> build() => AsyncValue.data(
      SettingsState(settings: _settings, overtimeBalance: Duration.zero));
}

class _FakeLeaveViewModel extends LeaveBalanceViewModel {
  @override
  LeaveBalanceState build() => const LeaveBalanceState();
}

void main() {
  final mo = DateTime(2026, 10, 5);
  final now = DateTime(2026, 10, 5, 17);
  late FakeWorkRepository work;

  const showLocation = SettingsEntity(showWorkLocationOnDashboard: true);

  void seed({WorkEntryType type = WorkEntryType.work, List<String>? locs}) {
    work.store[dayKey(mo)] = WorkEntryEntity(
      id: dayKey(mo),
      date: mo,
      workStart: DateTime(2026, 10, 5, 8),
      type: type,
      workLocations: locs,
    );
  }

  setUp(() => work = FakeWorkRepository());

  Future<void> pump(WidgetTester tester,
      {String locale = 'de',
      SettingsEntity settings = showLocation,
      double width = 600,
      bool dark = false}) async {
    _settings = settings;
    tester.view.physicalSize = Size(width, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final history = WorkLocationHistory(prefs, userId: 'local')
      ..record([
        WorkEntryEntity(
            id: '2026-10-02',
            date: DateTime(2026, 10, 2),
            workLocations: const ['Lager Neuss']),
      ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        workRepositoryProvider.overrideWithValue(work),
        overtimeRepositoryProvider.overrideWithValue(FakeOvertimeRepository()),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        openEntryViewModelProvider.overrideWith(_FakeOpenEntryViewModel.new),
        settingsViewModelProvider.overrideWith(_FakeSettingsViewModel.new),
        leaveBalanceViewModelProvider.overrideWith(_FakeLeaveViewModel.new),
        workLocationHistoryProvider.overrideWithValue(history),
        authStateProvider
            .overrideWithValue(const AsyncValue<UserEntity?>.data(null)),
        clockProvider.overrideWithValue(() => now),
      ],
      child: MaterialApp(
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const DashboardScreen(),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  testWidgets('Einstellung aus (Standard): weder Button noch Orte',
      (tester) async {
    seed(locs: const ['Büro']);
    await pump(tester, settings: const SettingsEntity());
    expect(find.text('Arbeitsort hinzufügen'), findsNothing);
    expect(find.text('Büro'), findsNothing);
    expect(find.text('Von zu Hause gearbeitet'), findsOneWidget);
    await unmount(tester);
  });

  for (final (locale, button, semantics) in [
    ('de', 'Arbeitsort hinzufügen', 'Arbeitsorte bearbeiten: Büro, Kunde A'),
    ('en', 'Add work location', 'Edit work locations: Büro, Kunde A'),
  ]) {
    group('Sprache $locale', () {
      testWidgets('ohne Orte: Button; Sheet speichert die Orte',
          (tester) async {
        final handle = tester.ensureSemantics();
        seed();
        await pump(tester, locale: locale);
        expect(find.text(button), findsOneWidget);
        expect(find.bySemanticsLabel(button), findsOneWidget);

        await tester.tap(find.text(button));
        await tester.pumpAndSettle();
        expect(find.byType(WorkLocationsSheet), findsOneWidget);

        await tester.enterText(
            find.descendant(
                of: find.byType(WorkLocationsSheet),
                matching: find.byType(TextField)),
            'Werk 2');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        await tester.tap(find.text(locale == 'de' ? 'Speichern' : 'Save'));
        await tester.pumpAndSettle();

        expect(work.saved.single.workLocations, ['Werk 2']);
        expect(work.saved.single.workEnd, isNull, reason: 'Timer läuft');
        expect(find.text('Werk 2'), findsOneWidget);
        expect(find.text(button), findsNothing);
        handle.dispose();
        await unmount(tester);
      });

      testWidgets('mit Orten: schlanke Zeile, Tipp öffnet das Sheet',
          (tester) async {
        final handle = tester.ensureSemantics();
        seed(locs: const ['Büro', 'Kunde A']);
        await pump(tester, locale: locale);
        expect(find.text(button), findsNothing);
        expect(find.text('Büro'), findsOneWidget);
        expect(find.text('Kunde A'), findsOneWidget);
        expect(find.bySemanticsLabel(semantics), findsOneWidget);

        await tester.tap(find.text('Büro'));
        await tester.pumpAndSettle();
        expect(find.byType(WorkLocationsSheet), findsOneWidget);
        // Abbrechen speichert nichts.
        await tester.tap(find.text(locale == 'de' ? 'Abbrechen' : 'Cancel'));
        await tester.pumpAndSettle();
        expect(work.saved, isEmpty);
        handle.dispose();
        await unmount(tester);
      });

      testWidgets('schmale Breite mit fünf langen Orten: kein Overflow',
          (tester) async {
        seed(locs: [
          for (var i = 0; i < 5; i++) 'Sehr langer Ortsname Nummer $i, Straße'
        ]);
        await pump(tester, locale: locale, width: 320);
        expect(tester.takeException(), isNull);
        // Die Zeile bleibt schlank: höchstens drei Chip-Reihen.
        final row = tester.getRect(find.bySemanticsLabel(
            RegExp(locale == 'de' ? '^Arbeitsorte bearbeiten' : '^Edit work')));
        expect(row.height, lessThan(130));
        await unmount(tester);
      });
    });
  }

  testWidgets('Home-Office ausgeblendet: Schalter fehlt, kein Leerraum',
      (tester) async {
    seed();
    await pump(tester,
        settings: const SettingsEntity(
            showWorkLocationOnDashboard: true,
            showHomeOfficeOnDashboard: false));
    expect(find.text('Von zu Hause gearbeitet'), findsNothing);
    expect(find.text('Arbeitsort hinzufügen'), findsOneWidget);
    final gap = tester.getRect(find.byType(ElevatedButton).first).top -
        tester.getRect(find.text('Arbeitsort hinzufügen')).bottom;
    expect(gap, lessThan(60));
    await unmount(tester);
  });

  testWidgets('beides aus: Endzeit direkt vor dem Start-/Stop-Button',
      (tester) async {
    seed(locs: const ['Büro']);
    await pump(tester,
        settings: const SettingsEntity(showHomeOfficeOnDashboard: false));
    expect(find.text('Von zu Hause gearbeitet'), findsNothing);
    expect(find.text('Büro'), findsNothing);
    expect(find.text('Arbeitsort hinzufügen'), findsNothing);
    await unmount(tester);
  });

  testWidgets('Typ Urlaub: weder Orte noch Button', (tester) async {
    seed(type: WorkEntryType.vacation, locs: const ['Büro']);
    await pump(tester);
    expect(find.text('Büro'), findsNothing);
    expect(find.text('Arbeitsort hinzufügen'), findsNothing);
    await unmount(tester);
  });

  testWidgets('Dunkelmodus: Orte-Zeile ohne Fehler', (tester) async {
    seed(locs: const ['Büro', 'Kunde A']);
    await pump(tester, dark: true, width: 360);
    expect(tester.takeException(), isNull);
    expect(find.text('Kunde A'), findsOneWidget);
    await unmount(tester);
  });
}
