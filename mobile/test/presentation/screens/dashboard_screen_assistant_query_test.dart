import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/app_lock_provider.dart';
import 'package:flutter_work_time/core/providers/clock_provider.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/providers/subscription_provider.dart';
import 'package:flutter_work_time/core/services/assistant_query_inbox.dart';
import 'package:flutter_work_time/core/services/shortcut_service.dart';
import 'package:flutter_work_time/core/services/timer_action_inbox.dart';
import 'package:flutter_work_time/domain/entities/bundesland.dart';
import 'package:flutter_work_time/domain/entities/settings_entity.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/entities/work_profile_entity.dart';
import 'package:flutter_work_time/domain/utils/assistant_query.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/screens/dashboard_screen.dart';
import 'package:flutter_work_time/presentation/state/leave_balance_state.dart';
import 'package:flutter_work_time/presentation/state/settings_state.dart';
import 'package:flutter_work_time/presentation/view_models/assistant_query_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/dashboard_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/leave_balance_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/open_entry_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/settings_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/timer_action_view_model.dart';
import 'package:flutter_work_time/presentation/widgets/assistant_query_sheet.dart';
import 'package:quick_actions/quick_actions.dart';

import '../../support/dashboard_harness.dart';
import '../../support/fake_clock.dart';
import '../../support/fake_repositories.dart';

// Sprachabfragen (#287) mit echtem DashboardViewModel und Fake-Repos: die
// Abfrage oeffnet nur die Antwort-Ansicht und veraendert keine Daten, auch
// nicht bei laufendem Timer. Feste Daten: Mo 2026-10-05, Uhr 17:00, Start
// 08:00.

class _FakeQuickActions implements QuickActions {
  QuickActionHandler? handler;

  @override
  Future<void> initialize(QuickActionHandler handler) async =>
      this.handler = handler;

  @override
  Future<void> setShortcutItems(List<ShortcutItem> items) async {}

  @override
  Future<void> clearShortcutItems() async {}
}

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

class _DefaultProfile extends ActiveWorkProfileIdNotifier {
  @override
  String? build() => null;
}

const _user = UserEntity(id: 'u1');

void main() {
  final mo = DateTime(2026, 10, 5);
  final start = DateTime(2026, 10, 5, 8);
  final now = DateTime(2026, 10, 5, 17);
  final de = lookupAppLocalizations(const Locale('de'));

  late FakeWorkRepository work;
  late FakeOvertimeRepository overtime;
  late FakeClock inboxClock;
  late AssistantQueryInbox queryInbox;
  late TimerActionInbox timerInbox;
  late _FakeQuickActions quickActions;
  late bool locked;
  ProviderContainer? current;

  setUp(() {
    work = FakeWorkRepository()..store[dayKey(mo)] = entryOf(mo, start: start);
    overtime = FakeOvertimeRepository()..stored = const Duration(minutes: 120);
    inboxClock = FakeClock(DateTime.utc(2026, 10, 5, 15));
    queryInbox = AssistantQueryInbox(clock: inboxClock.call);
    timerInbox = TimerActionInbox(clock: inboxClock.call);
    quickActions = _FakeQuickActions();
    locked = false;
  });

  Future<ProviderContainer> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(overrides: [
      workRepositoryProvider.overrideWithValue(work),
      overtimeRepositoryProvider.overrideWithValue(overtime),
      settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
      openEntryViewModelProvider.overrideWith(_FakeOpenEntryViewModel.new),
      settingsViewModelProvider.overrideWith(_FakeSettingsViewModel.new),
      leaveBalanceViewModelProvider.overrideWith(_FakeLeaveViewModel.new),
      authStateProvider
          .overrideWithValue(const AsyncValue<UserEntity?>.data(_user)),
      activeWorkProfileIdProvider.overrideWith(_DefaultProfile.new),
      workProfilesProvider
          .overrideWith((ref) async => [WorkProfileEntity.defaultProfile()]),
      isPremiumProvider.overrideWithValue(true),
      isAppLockedProvider.overrideWith((ref) => locked),
      clockProvider.overrideWithValue(() => now),
      assistantQueryInboxProvider.overrideWithValue(queryInbox),
      timerActionInboxProvider.overrideWithValue(timerInbox),
    ]);
    current = container;
    // Wie main.dart: beide ViewModels der Aktionen von außen am Leben halten.
    container.listen(assistantQueryViewModelProvider, (_, __) {});
    container.listen(timerActionViewModelProvider, (_, __) {});
    // Wie main.dart: Shortcut-/Assistant-Typen in die Briefkästen.
    await ShortcutService(quickActions: quickActions, supported: true)
        .initialize(timerInbox.push, onQuery: queryInbox.push);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const DashboardScreen(),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    return container;
  }

  /// Baut den Baum ab, damit Timer des ViewModels/`todayProvider` enden.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    current?.dispose();
    current = null;
    await tester.pump();
  }

  /// Zustellung, Frame mit Post-Frame-Callback (Sheet öffnen) und Animation.
  /// Kein pumpAndSettle: der laufende Timer tickt jede Sekunde.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Wie `AssistantTimerIntent` -> `quick_actions` -> Handler.
  Future<void> speak(WidgetTester tester, String id) async {
    quickActions.handler!(id);
    await settle(tester);
  }

  Future<void> closeSheet(WidgetTester tester) async {
    await tester.tap(find.text('Schließen'));
    await settle(tester);
  }

  testWidgets(
      'laufender Timer + Trend, Ueberstunden, Resturlaub: Eintrag unveraendert',
      (tester) async {
    final container = await pump(tester);
    expect(find.text('Zeiterfassung beenden'), findsOneWidget);
    final before = container.read(dashboardViewModelProvider).workEntry;
    expect(before.workStart, start);
    expect(before.workEnd, isNull);

    // Trend: in Teil A still verworfen, keine Ansicht, kein Stop.
    await speak(tester, 'query_trend');
    expect(find.byType(AssistantQuerySheet), findsNothing);

    await speak(tester, 'query_overtime');
    expect(find.byType(AssistantQuerySheet), findsOneWidget);
    expect(find.text(de.overtimeTotalLabel), findsWidgets);
    await closeSheet(tester);

    await speak(tester, 'query_leave');
    expect(find.byType(AssistantQuerySheet), findsOneWidget);
    expect(find.text(de.remainingVacationTitle), findsWidgets);
    await closeSheet(tester);

    final after = container.read(dashboardViewModelProvider).workEntry;
    expect(after.workStart, before.workStart);
    expect(after.workEnd, isNull, reason: 'Timer laeuft weiter');
    expect(after.breaks, before.breaks);
    expect(after.type, WorkEntryType.work);
    expect(work.saved, isEmpty, reason: 'kein Eintrag geschrieben');
    expect(work.store[dayKey(mo)]!.workEnd, isNull);
    expect(overtime.savedOvertimes, isEmpty, reason: 'kein Saldo geschrieben');
    expect(timerInbox.hasPending, isFalse);
    expect(container.read(timerActionViewModelProvider).handled, 0,
        reason: 'keine Timer-Aktion ausgeloest');
    expect(find.text('Zeiterfassung beenden'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('App gesperrt: Antwort erst nach dem Entsperren', (tester) async {
    locked = true;
    final container = await pump(tester);

    await speak(tester, 'query_overtime');
    expect(find.byType(AssistantQuerySheet), findsNothing);

    container.read(isAppLockedProvider.notifier).state = false;
    await tester.pump();
    await settle(tester);

    expect(find.byType(AssistantQuerySheet), findsOneWidget);
    expect(work.saved, isEmpty);
    await unmount(tester);
  });

  testWidgets('App gesperrt laenger als 2 Minuten: Abfrage verfaellt still',
      (tester) async {
    locked = true;
    final container = await pump(tester);

    await speak(tester, 'query_leave');
    inboxClock.jumpTo(DateTime.utc(2026, 10, 5, 15, 3));
    container.read(isAppLockedProvider.notifier).state = false;
    await tester.pump();
    await settle(tester);

    expect(find.byType(AssistantQuerySheet), findsNothing);
    expect(container.read(assistantQueryPendingProvider), isNull);
    await unmount(tester);
  });

  testWidgets('Abfrage vor dem ersten Frame des Screens wird nachgeholt',
      (tester) async {
    queryInbox.push(AssistantQuery.overtime);
    await pump(tester);
    await settle(tester);

    expect(find.byType(AssistantQuerySheet), findsOneWidget);
    await unmount(tester);
  });
}
