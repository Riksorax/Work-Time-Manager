import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/clock_provider.dart';
import 'package:flutter_work_time/domain/entities/bundesland.dart';
import 'package:flutter_work_time/domain/entities/settings_entity.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
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

const _bannerText = 'Heute ist Feiertag: Tag der Deutschen Einheit';

class _FakeDashboardViewModel extends DashboardViewModel {
  _FakeDashboardViewModel(this.type);
  final WorkEntryType type;
  static int writes = 0;
  static DashboardState? initial;

  @override
  DashboardState build() => initial = DashboardState(
        workEntry: WorkEntryEntity(
          id: 'x',
          date: DateTime(2026, 10, 3),
          type: type,
        ),
        elapsedTime: Duration.zero,
        totalOvertime: Duration.zero,
        dailyOvertime: const Duration(minutes: 15),
      );

  @override
  Future<void> startOrStopTimer() async => writes++;
  @override
  Future<void> startOrStopBreak() async => writes++;
  @override
  Future<void> startNewSession() async => writes++;
  @override
  Future<void> setManualStartTime(TimeOfDay time) async => writes++;
  @override
  Future<void> setManualEndTime(TimeOfDay time) async => writes++;
}

Bundesland? _land;

class _FakeSettingsViewModel extends SettingsViewModel {
  @override
  AsyncValue<SettingsState> build() => AsyncValue.data(SettingsState(
      settings: SettingsEntity(bundesland: _land),
      overtimeBalance: Duration.zero));
}

class _FakeLeaveViewModel extends LeaveBalanceViewModel {
  @override
  LeaveBalanceState build() => const LeaveBalanceState();
}

/// Der Banner für offene Einträge (#385) ist hier nicht Thema.
class _NoOpenEntriesViewModel extends OpenEntryViewModel {
  @override
  OpenEntryState build() => const OpenEntryState();
}

void main() {
  setUp(() {
    _land = Bundesland.bayern;
    _FakeDashboardViewModel.writes = 0;
  });

  Future<void> pump(WidgetTester tester, double width,
      {DateTime? now, WorkEntryType type = WorkEntryType.work}) async {
    tester.view.physicalSize = Size(width, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final clockNow = now ?? DateTime(2026, 10, 3, 12);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        dashboardViewModelProvider
            .overrideWith(() => _FakeDashboardViewModel(type)),
        settingsViewModelProvider.overrideWith(_FakeSettingsViewModel.new),
        leaveBalanceViewModelProvider.overrideWith(_FakeLeaveViewModel.new),
        openEntryViewModelProvider.overrideWith(_NoOpenEntriesViewModel.new),
        authStateProvider
            .overrideWithValue(const AsyncValue<UserEntity?>.data(null)),
        clockProvider.overrideWithValue(() => clockNow),
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
      testWidgets('kein Bundesland -> kein Banner', (tester) async {
        _land = null;
        await pump(tester, width);
        expect(find.textContaining('Feiertag'), findsNothing);
      });

      testWidgets('Nicht-Feiertag -> kein Banner', (tester) async {
        await pump(tester, width, now: DateTime(2026, 10, 4, 12));
        expect(find.textContaining('Feiertag'), findsNothing);
      });

      testWidgets('Feiertag -> Banner oberhalb des Timers', (tester) async {
        await pump(tester, width);
        final banner = find.text(_bannerText);
        expect(banner, findsOneWidget);
        final timer = find.text('00:00:00');
        expect(timer, findsWidgets);
        final bannerTop = tester.getTopLeft(banner).dy;
        expect(bannerTop, lessThan(tester.getTopLeft(timer.first).dy));
        if (width > 900) {
          final controls = find.byType(ElevatedButton).first;
          expect(bannerTop, lessThan(tester.getTopLeft(controls).dy));
          final bannerBox = tester.getSize(find
              .ancestor(of: banner, matching: find.byType(Container))
              .first);
          // Banner liegt ueber beiden Spalten (Inhaltsbreite 1200 - Padding).
          expect(bannerBox.width, greaterThan(1100));
        }
      });

      for (final type in WorkEntryType.values) {
        testWidgets('Eintrag vom Typ ${type.name}: Banner, keine Aenderung',
            (tester) async {
          await pump(tester, width, type: type);
          expect(find.text(_bannerText), findsOneWidget);
          final container = ProviderScope.containerOf(
              tester.element(find.byType(DashboardScreen)));
          final state = container.read(dashboardViewModelProvider);
          expect(state, _FakeDashboardViewModel.initial);
          expect(state.workEntry.type, type);
          expect(state.dailyOvertime, const Duration(minutes: 15));
          expect(_FakeDashboardViewModel.writes, 0);
        });
      }
    });
  }
}
