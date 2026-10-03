import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/utils/leave_balance_utils.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/screens/dashboard_screen.dart';
import 'package:flutter_work_time/presentation/state/dashboard_state.dart';
import 'package:flutter_work_time/presentation/state/leave_balance_state.dart';
import 'package:flutter_work_time/presentation/state/settings_state.dart';
import 'package:flutter_work_time/presentation/view_models/auth_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/dashboard_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/leave_balance_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/settings_view_model.dart';
import 'package:flutter_work_time/domain/entities/settings_entity.dart';

class _FakeDashboardViewModel extends DashboardViewModel {
  @override
  DashboardState build() => DashboardState(
        workEntry: WorkEntryEntity(id: 'x', date: DateTime(2026, 6, 1)),
        elapsedTime: Duration.zero,
        totalOvertime: Duration.zero,
        dailyOvertime: Duration.zero,
      );
}

class _FakeSettingsViewModel extends SettingsViewModel {
  @override
  AsyncValue<SettingsState> build() => const AsyncValue.data(SettingsState(
      settings: SettingsEntity(), overtimeBalance: Duration.zero));
}

class _FakeLeaveViewModel extends LeaveBalanceViewModel {
  @override
  LeaveBalanceState build() => const LeaveBalanceState(
        balance: LeaveBalance(
            year: 2026, entitlement: 30, taken: 12, remaining: 18, sickDays: 0),
      );
}

void main() {
  for (final width in [600.0, 1400.0]) {
    testWidgets('kompakte Resturlaub-Karte ohne Login sichtbar (Breite $width)',
        (tester) async {
      final view = tester.view;
      view.physicalSize = Size(width, 1600);
      view.devicePixelRatio = 1.0;
      addTearDown(view.resetPhysicalSize);
      addTearDown(view.resetDevicePixelRatio);

      await tester.pumpWidget(ProviderScope(
        overrides: [
          dashboardViewModelProvider.overrideWith(_FakeDashboardViewModel.new),
          settingsViewModelProvider.overrideWith(_FakeSettingsViewModel.new),
          leaveBalanceViewModelProvider.overrideWith(_FakeLeaveViewModel.new),
          authStateProvider
              .overrideWithValue(const AsyncValue<UserEntity?>.data(null)),
        ],
        child: MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const DashboardScreen(),
        ),
      ));
      await tester.pump();

      expect(find.text('Resturlaub'), findsOneWidget);
      expect(find.text('18 von 30 Tagen'), findsOneWidget);
    });
  }
}
