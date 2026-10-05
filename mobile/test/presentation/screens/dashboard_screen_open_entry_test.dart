import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/clock_provider.dart';
import 'package:flutter_work_time/core/providers/providers.dart'
    show
        overtimeRepositoryProvider,
        settingsRepositoryProvider,
        workRepositoryProvider;
import 'package:flutter_work_time/domain/entities/bundesland.dart';
import 'package:flutter_work_time/domain/entities/settings_entity.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/usecases/close_open_work_entry.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/screens/dashboard_screen.dart';
import 'package:flutter_work_time/presentation/state/dashboard_state.dart';
import 'package:flutter_work_time/presentation/state/leave_balance_state.dart';
import 'package:flutter_work_time/presentation/state/settings_state.dart';
import 'package:flutter_work_time/presentation/view_models/auth_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/dashboard_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/leave_balance_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/open_entry_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/settings_view_model.dart';

import '../../support/dashboard_harness.dart' show entryOf;
import '../../support/fake_repositories.dart';

const _openText = 'Dein Eintrag vom Fr., 2. Okt. läuft noch seit 22:00.';
const _holidayText = 'Heute ist Feiertag: Tag der Deutschen Einheit';

class _FakeDashboardViewModel extends DashboardViewModel {
  static int writes = 0;

  @override
  DashboardState build() => DashboardState(
        workEntry: WorkEntryEntity(id: 'x', date: DateTime(2026, 10, 3)),
        elapsedTime: Duration.zero,
        totalOvertime: Duration.zero,
        dailyOvertime: Duration.zero,
      );

  @override
  Future<bool> startOrStopTimer() async {
    writes++;
    return true;
  }
}

class _FakeOpenEntryViewModel extends OpenEntryViewModel {
  static CloseOpenEntryResult result = CloseOpenEntryResult.closed;
  static final List<DateTime> ends = [];

  @override
  OpenEntryState build() => OpenEntryState(entries: [
        WorkEntryEntity(
          id: 'fri',
          date: DateTime(2026, 10, 2),
          workStart: DateTime(2026, 10, 2, 22),
        ),
      ]);

  @override
  Duration targetFor(WorkEntryEntity entry) => const Duration(hours: 8);

  @override
  void later() => state = const OpenEntryState();

  @override
  Future<CloseOpenEntryResult?> endEntry(DateTime end) async {
    ends.add(end);
    return result;
  }
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

/// `pumpAndSettle` läuft hier nicht aus (Dashboard hat dauerhafte Animationen).
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUp(() {
    _FakeDashboardViewModel.writes = 0;
    _FakeOpenEntryViewModel.result = CloseOpenEntryResult.closed;
    _FakeOpenEntryViewModel.ends.clear();
  });

  Future<void> pump(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // Sa 2026-10-03 ist Feiertag (Bayern): beide Banner gleichzeitig.
    final now = DateTime(2026, 10, 3, 12);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        dashboardViewModelProvider.overrideWith(_FakeDashboardViewModel.new),
        openEntryViewModelProvider.overrideWith(_FakeOpenEntryViewModel.new),
        settingsViewModelProvider.overrideWith(_FakeSettingsViewModel.new),
        leaveBalanceViewModelProvider.overrideWith(_FakeLeaveViewModel.new),
        authStateProvider
            .overrideWithValue(const AsyncValue<UserEntity?>.data(null)),
        clockProvider.overrideWithValue(() => now),
      ],
      child: MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const DashboardScreen(),
      ),
    ));
    await tester.pump();
  }

  for (final width in [600.0, 1400.0]) {
    group('Breite $width', () {
      testWidgets('Banner steht unter dem Feiertag-Banner und über dem Timer',
          (tester) async {
        await pump(tester, width);
        final holiday = tester.getTopLeft(find.text(_holidayText)).dy;
        final open = tester.getTopLeft(find.text(_openText)).dy;
        final timer = tester.getTopLeft(find.text('00:00:00').first).dy;
        expect(holiday, lessThan(open));
        expect(open, lessThan(timer));
        if (width > 900) {
          final controls =
              tester.getTopLeft(find.byType(ElevatedButton).first).dy;
          expect(open, lessThan(controls));
        }
      });

      testWidgets('Beenden -> Dialog -> Bestätigen ruft das ViewModel',
          (tester) async {
        await pump(tester, width);
        await tester.tap(find.text('Beenden'));
        await _settle(tester);
        expect(find.text('Ende des Eintrags festlegen'), findsOneWidget);
        await tester.tap(find.text('Eintrag beenden'));
        await _settle(tester);
        expect(_FakeOpenEntryViewModel.ends, [DateTime(2026, 10, 3, 6)]);
      });

      testWidgets('Fehler: Snackbar, Banner bleibt', (tester) async {
        _FakeOpenEntryViewModel.result = CloseOpenEntryResult.failed;
        await pump(tester, width);
        await tester.tap(find.text('Beenden'));
        await _settle(tester);
        await tester.tap(find.text('Eintrag beenden'));
        await _settle(tester);
        expect(
            find.text('Eintrag konnte nicht beendet werden.'), findsOneWidget);
        expect(find.text(_openText), findsOneWidget);
      });

      testWidgets('Später blendet den Banner aus', (tester) async {
        await pump(tester, width);
        await tester.tap(find.text('Später'));
        await tester.pump();
        expect(find.text(_openText), findsNothing);
        expect(find.text(_holidayText), findsOneWidget);
      });

      testWidgets('nicht modal: Timer-Start bleibt bedienbar', (tester) async {
        await pump(tester, width);
        expect(find.text(_openText), findsOneWidget);
        await tester.tap(find.byType(ElevatedButton).first);
        await tester.pump();
        expect(_FakeDashboardViewModel.writes, 1);
        expect(find.text(_openText), findsOneWidget);
      });
    });
  }

  // Ende-zu-Ende mit echtem Dashboard- und Banner-ViewModel (#385 PR 1b).
  // So 2026-10-04 22:00 offen, jetzt Mo 2026-10-05 09:00 (kein Feiertag).
  group('Fortsetzen mit echten ViewModels', () {
    final sun = DateTime(2026, 10, 4);
    final mon = DateTime(2026, 10, 5);
    final now = DateTime(2026, 10, 5, 9);
    const openTitle = 'Dein Eintrag vom So., 4. Okt. läuft noch seit 22:00.';
    late FakeWorkRepository work;
    late FakeOvertimeRepository overtime;

    setUp(() {
      work = FakeWorkRepository()
        ..store[dayKey(sun)] = entryOf(sun, start: DateTime(2026, 10, 4, 22));
      overtime = FakeOvertimeRepository();
    });

    Future<void> pumpReal(WidgetTester tester) async {
      tester.view.physicalSize = const Size(600, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          workRepositoryProvider.overrideWithValue(work),
          overtimeRepositoryProvider.overrideWithValue(overtime),
          settingsRepositoryProvider
              .overrideWithValue(FakeSettingsRepository()),
          settingsViewModelProvider.overrideWith(_FakeSettingsViewModel.new),
          leaveBalanceViewModelProvider.overrideWith(_FakeLeaveViewModel.new),
          authStateProvider
              .overrideWithValue(const AsyncValue<UserEntity?>.data(null)),
          clockProvider.overrideWithValue(() => now),
        ],
        child: MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const DashboardScreen(),
        ),
      ));
      await _settle(tester);
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }

    testWidgets(
        'Fortsetzen: Timer läuft mit Vortag-Start, Banner weg, Stop geht',
        (tester) async {
      await pumpReal(tester);
      expect(find.text(openTitle), findsOneWidget);
      expect(find.text('Fortsetzen'), findsOneWidget);
      expect(find.text('Zeiterfassung starten'), findsOneWidget);

      await tester.tap(find.text('Fortsetzen'));
      await _settle(tester);

      expect(find.text(openTitle), findsNothing);
      expect(find.text('Zeiterfassung beenden'), findsOneWidget);
      expect(find.text('Zeiterfassung starten'), findsNothing);
      expect(find.text('22:00'), findsWidgets);
      expect(find.byType(SnackBar), findsNothing);
      expect(work.saved, isEmpty, reason: 'Fortsetzen schreibt nichts');

      await tester.tap(find.text('Zeiterfassung beenden'));
      await _settle(tester);
      expect(work.saved.last.date, sun);
      expect(work.saved.last.workEnd, isNotNull);
      expect(find.text('Zeiterfassung starten'), findsOneWidget,
          reason: 'Dashboard zeigt wieder heute');
      expect(find.text(openTitle), findsNothing);
      await unmount(tester);
    });

    testWidgets('heute schon gestartet: nur Beenden, kein Fortsetzen',
        (tester) async {
      work.store[dayKey(mon)] = entryOf(mon, start: DateTime(2026, 10, 5, 8));
      await pumpReal(tester);
      expect(find.text(openTitle), findsOneWidget);
      expect(find.text('Beenden'), findsOneWidget);
      expect(find.text('Fortsetzen'), findsNothing);
      await unmount(tester);
    });

    testWidgets('Eintrag älter als 24 h: nur Beenden', (tester) async {
      work.store[dayKey(sun)] = entryOf(sun, start: DateTime(2026, 10, 4, 8));
      await pumpReal(tester);
      expect(find.text('Beenden'), findsOneWidget);
      expect(find.text('Fortsetzen'), findsNothing);
      await unmount(tester);
    });

    testWidgets('abgelehnt (anderes Gerät beendet): Dashboard bleibt bedienbar',
        (tester) async {
      await pumpReal(tester);
      work.store[dayKey(sun)] = entryOf(sun,
          start: DateTime(2026, 10, 4, 22), end: DateTime(2026, 10, 4, 23));
      await tester.tap(find.text('Fortsetzen'));
      await _settle(tester);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Zeiterfassung starten'), findsOneWidget);

      await tester.tap(find.text('Zeiterfassung starten'));
      await _settle(tester);
      expect(find.text('Zeiterfassung beenden'), findsOneWidget);
      expect(work.saved.last.date, mon);
      await unmount(tester);
    });
  });
}
