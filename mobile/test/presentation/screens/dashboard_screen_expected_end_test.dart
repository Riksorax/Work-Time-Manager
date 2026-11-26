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

// Feierabendzeit im Dashboard in der App-Sprache (#583): "Uhr" nur im
// deutschen Text und nur im 24-Stunden-Format. Feste Daten: Mo 2026-10-05,
// Uhr 09:00, Start 08:00, Soll 8 h, Saldo +2 h.
class _FakeOpenEntryViewModel extends OpenEntryViewModel {
  @override
  OpenEntryState build() => const OpenEntryState();
}

class _FakeLeaveViewModel extends LeaveBalanceViewModel {
  @override
  LeaveBalanceState build() => const LeaveBalanceState();
}

void main() {
  final mo = DateTime(2026, 10, 5);
  final now = DateTime(2026, 10, 5, 9);
  late FakeWorkRepository work;
  late FakeOvertimeRepository overtime;

  setUp(() {
    work = FakeWorkRepository();
    overtime = FakeOvertimeRepository()..stored = const Duration(hours: 2);
    work.store[dayKey(mo)] = WorkEntryEntity(
      id: dayKey(mo),
      date: mo,
      workStart: DateTime(2026, 10, 5, 8),
    );
  });

  Future<void> pump(WidgetTester tester, String locale,
      {required bool use24}) async {
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
        settingsViewModelProvider
            .overrideWith(() => _FakeSettingsViewModel(use24)),
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

  /// Text des Widgets, das mit [prefix] beginnt (genau eines).
  String textStartingWith(WidgetTester tester, String prefix) {
    final finder = find.byWidgetPredicate(
        (w) => w is Text && (w.data?.startsWith(prefix) ?? false));
    expect(finder, findsOneWidget, reason: prefix);
    return tester.widget<Text>(finder).data!;
  }

  for (final (locale, use24, endZero, endBalance) in [
    (
      'de',
      true,
      'Voraussichtlicher Feierabend (±0): 16:30 Uhr',
      'Mit Gleitzeit-Bilanz auf 0: 14:30 Uhr',
    ),
    (
      'de',
      false,
      'Voraussichtlicher Feierabend (±0): 4:30 PM',
      'Mit Gleitzeit-Bilanz auf 0: 2:30 PM',
    ),
    (
      'en',
      true,
      'Expected end of day (±0): 16:30',
      'With overtime balance at 0: 14:30',
    ),
    (
      'en',
      false,
      'Expected end of day (±0): 4:30 PM',
      'With overtime balance at 0: 2:30 PM',
    ),
  ]) {
    testWidgets('$locale, ${use24 ? 24 : 12} h: Feierabendzeiten', (t) async {
      await pump(t, locale, use24: use24);
      expect(textStartingWith(t, endZero.split(':').first), endZero);
      expect(textStartingWith(t, endBalance.split(':').first), endBalance);
      if (locale == 'en' || !use24) {
        expect(find.textContaining('Uhr'), findsNothing);
      }
      await unmount(t);
    });
  }
}

class _FakeSettingsViewModel extends SettingsViewModel {
  _FakeSettingsViewModel(this.use24);
  final bool use24;

  @override
  AsyncValue<SettingsState> build() => AsyncValue.data(SettingsState(
      settings:
          SettingsEntity(bundesland: Bundesland.bayern, use24HourFormat: use24),
      overtimeBalance: const Duration(hours: 2)));
}
