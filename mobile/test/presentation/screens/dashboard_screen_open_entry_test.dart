import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/clock_provider.dart';
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
  Future<void> startOrStopTimer() async => writes++;
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
}
