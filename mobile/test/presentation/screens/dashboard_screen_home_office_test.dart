import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/clock_provider.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/domain/entities/bundesland.dart';
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

import '../../support/fake_repositories.dart';

// Home-Office-Schalter im Dashboard (#277). Feste Daten: Mo 2026-10-05,
// Uhr 17:00, Start 08:00.
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

  void seed(
      {WorkEntryType type = WorkEntryType.work, bool homeOffice = false}) {
    work.store[dayKey(mo)] = WorkEntryEntity(
      id: dayKey(mo),
      date: mo,
      workStart: DateTime(2026, 10, 5, 8),
      type: type,
      isHomeOffice: homeOffice,
    );
  }

  setUp(() {
    work = FakeWorkRepository();
    overtime = FakeOvertimeRepository()..stored = const Duration(minutes: 120);
  });

  Future<void> pump(WidgetTester tester, String locale,
      {double width = 600}) async {
    tester.view.physicalSize = Size(width, 1600);
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  for (final (locale, label, semantics) in [
    ('de', 'Von zu Hause gearbeitet', 'Home-Office für heute umschalten'),
    ('en', 'Worked from home', 'Toggle home office for today'),
  ]) {
    group('Sprache $locale', () {
      testWidgets('Schalter sichtbar bei Typ Arbeit, ruft setHomeOffice',
          (tester) async {
        seed();
        await pump(tester, locale);
        final tile = find.widgetWithText(SwitchListTile, label);
        expect(tile, findsOneWidget);
        expect(tester.widget<SwitchListTile>(tile).value, isFalse);

        await tester.tap(tile);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(work.saved, hasLength(1));
        expect(work.saved.single.isHomeOffice, isTrue);
        expect(work.saved.single.workEnd, isNull);
        expect(tester.widget<SwitchListTile>(tile).value, isTrue);
        await unmount(tester);
      });

      testWidgets('Semantics-Label fuer Screenreader', (tester) async {
        final handle = tester.ensureSemantics();
        seed(homeOffice: true);
        await pump(tester, locale);
        final outer = find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.hint == semantics);
        expect(outer, findsOneWidget);
        expect(tester.getSemantics(outer).hint, semantics);
        // Der Schalter selbst behaelt seinen sichtbaren Text als Label.
        expect(find.bySemanticsLabel(label), findsWidgets);
        handle.dispose();
        await unmount(tester);
      });

      testWidgets('nicht sichtbar bei Typ Urlaub', (tester) async {
        seed(type: WorkEntryType.vacation, homeOffice: true);
        await pump(tester, locale);
        expect(find.byType(SwitchListTile), findsNothing);
        await unmount(tester);
      });

      testWidgets('disabled waehrend isSaving', (tester) async {
        seed();
        work.holdSaves = true;
        await pump(tester, locale);
        // Eine laufende Aktion (Pause starten) sperrt das Dashboard.
        final breakBtn = find.byType(ElevatedButton).last;
        await tester.ensureVisible(breakBtn);
        await tester.tap(breakBtn);
        await tester.pump();

        final tile = find.widgetWithText(SwitchListTile, label);
        expect(tester.widget<SwitchListTile>(tile).onChanged, isNull);

        work.holdSaves = false;
        work.pendingSaves.single.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.widget<SwitchListTile>(tile).onChanged, isNotNull);
        await unmount(tester);
      });

      testWidgets('kein Overflow bei schmaler Breite', (tester) async {
        seed();
        await pump(tester, locale, width: 280);
        expect(tester.takeException(), isNull);
        await unmount(tester);
      });
    });
  }
}
