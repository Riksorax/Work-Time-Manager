import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/domain/entities/bundesland.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/repositories/overtime_repository.dart';
import 'package:flutter_work_time/domain/repositories/settings_repository.dart';
import 'package:flutter_work_time/domain/repositories/work_repository.dart';
import 'package:flutter_work_time/domain/usecases/get_today_work_entry.dart';
import 'package:flutter_work_time/domain/entities/settings_entity.dart';
import 'package:flutter_work_time/domain/usecases/overtime_usecases.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/state/settings_state.dart';
import 'package:flutter_work_time/presentation/view_models/dashboard_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/settings_view_model.dart';
import 'package:flutter_work_time/presentation/widgets/add_adjustment_modal.dart';

/// Regression test for #266: adjusting the Gleitzeit-Bilanz used to close the
/// dialog (and thus dispose its `WidgetRef`) before the underlying save had
/// completed. `SettingsViewModel.setOvertimeBalance` used that dialog's
/// `WidgetRef` *after* an `await` point to notify the Dashboard, which threw
/// once the dialog was gone - silently, since the call was fire-and-forget.
/// The Dashboard never saw the update until the app was restarted.
class _FakeWorkRepository implements WorkRepository {
  @override
  Future<WorkEntryEntity> getWorkEntry(DateTime date) async =>
      WorkEntryEntity(id: date.toIso8601String(), date: date);
  @override
  Future<void> saveWorkEntry(WorkEntryEntity entry) async {}
  @override
  Future<List<WorkEntryEntity>> getWorkEntriesForMonth(int year, int month) async => [];
  @override
  Future<void> deleteWorkEntry(String entryId) async {}
}

/// Simulates a real (slow) Firestore write: the `WidgetRef`-disposal bug only
/// manifests once the save takes long enough for the dialog to actually
/// close first.
class _DelayedOvertimeRepository implements OvertimeRepository {
  Duration _overtime = Duration.zero;
  DateTime? _lastUpdate;

  @override
  Duration getOvertime() => _overtime;

  @override
  Future<void> saveOvertime(Duration overtime) async {
    // Deutlich länger als jede Dialog-Übergangsanimation (~150ms), damit der
    // Test alt vs. neu tatsächlich unterscheiden kann: im alten (kaputten)
    // Code wird `Navigator.pop()` synchron aufgerufen, bevor dieser Save
    // hier überhaupt zu Ende ist - der Dialog (und sein `WidgetRef`) ist zu
    // diesem Zeitpunkt also längst weg.
    await Future.delayed(const Duration(milliseconds: 1000));
    _overtime = overtime;
  }

  @override
  DateTime? getLastUpdateDate() => _lastUpdate;

  @override
  Future<void> saveLastUpdateDate(DateTime date) async {
    _lastUpdate = date;
  }

  @override
  Future<Duration> ensureOvertimeLoaded() async => _overtime;

  @override
  Future<DateTime?> ensureLastUpdateLoaded() async => _lastUpdate;
}

class _FakeSettingsRepository implements SettingsRepository {
  @override
  ThemeMode getThemeMode() => ThemeMode.system;
  @override
  Future<void> setThemeMode(ThemeMode mode) async {}
  @override
  double getTargetWeeklyHours() => 40.0;
  @override
  Future<void> setTargetWeeklyHours(double hours) async {}
  @override
  List<int> getWorkdays() => const [1, 2, 3, 4, 5];
  @override
  Future<void> setWorkdays(List<int> days) async {}
  @override
  bool hasAcceptedTermsOfService() => true;
  @override
  Future<void> setAcceptedTermsOfService(bool accepted) async {}
  @override
  bool hasAcceptedPrivacyPolicy() => true;
  @override
  Future<void> setAcceptedPrivacyPolicy(bool accepted) async {}
  @override
  bool getNotificationsEnabled() => false;
  @override
  Future<void> setNotificationsEnabled(bool enabled) async {}
  @override
  String getNotificationTime() => '09:00';
  @override
  Future<void> setNotificationTime(String time) async {}
  @override
  List<int> getNotificationDays() => const [];
  @override
  Future<void> setNotificationDays(List<int> days) async {}
  @override
  bool getNotifyWorkStart() => false;
  @override
  Future<void> setNotifyWorkStart(bool enabled) async {}
  @override
  bool getNotifyWorkEnd() => false;
  @override
  Future<void> setNotifyWorkEnd(bool enabled) async {}
  @override
  bool getNotifyBreaks() => false;
  @override
  Future<void> setNotifyBreaks(bool enabled) async {}
  @override
  Bundesland? getBundesland() => null;
  @override
  Future<void> setBundesland(Bundesland? bundesland) async {}
  @override
  bool getWarnOnOvertimeThreshold() => false;
  @override
  Future<void> setWarnOnOvertimeThreshold(bool enabled) async {}
  @override
  double getOvertimeThresholdHours() => 0.0;
  @override
  Future<void> setOvertimeThresholdHours(double hours) async {}
  @override
  bool getWarnOnUndertimeThreshold() => false;
  @override
  Future<void> setWarnOnUndertimeThreshold(bool enabled) async {}
  @override
  double getUndertimeThresholdHours() => 0.0;
  @override
  Future<void> setUndertimeThresholdHours(double hours) async {}
  @override
  bool getUse24HourFormat() => true;
  @override
  Future<void> setUse24HourFormat(bool use24Hour) async {}
  @override
  String? getTimezoneOverride() => null;
  @override
  Future<void> setTimezoneOverride(String? timezone) async {}
  @override
  String getLocale() => 'de';
  @override
  Future<void> setLocale(String locale) async {}
}

class _FakeGetTodayWorkEntry implements GetTodayWorkEntry {
  final WorkEntryEntity entry;
  _FakeGetTodayWorkEntry(this.entry);
  @override
  Future<WorkEntryEntity> call() async => entry;
}

/// Returns immediately with a fixed [SettingsState] so the dialog can render
/// right away, while `setOvertimeBalance` itself stays the real
/// implementation under test.
class _ImmediateSettingsViewModel extends SettingsViewModel {
  @override
  AsyncValue<SettingsState> build() {
    return const AsyncValue.data(SettingsState(
      settings: SettingsEntity(),
      overtimeBalance: Duration.zero,
    ));
  }
}

void main() {
  testWidgets(
    'adjusting the overtime balance updates the Dashboard even though the dialog closes right after saving (#266)',
    (tester) async {
      final overtimeRepository = _DelayedOvertimeRepository();
      final now = DateTime.now();
      // workStart == null (Tag noch nicht gestartet) - vermeidet den
      // periodischen 1s-Timer, der für diesen Test irrelevant ist und
      // ansonsten als "pending timer" die Testinfrastruktur stören würde.
      final entry = WorkEntryEntity(id: '1', date: now);

      late BuildContext capturedContext;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            getTodayWorkEntryUseCaseProvider.overrideWithValue(_FakeGetTodayWorkEntry(entry)),
            settingsRepositoryProvider.overrideWithValue(_FakeSettingsRepository()),
            overtimeRepositoryProvider.overrideWithValue(overtimeRepository),
            setOvertimeUseCaseProvider.overrideWithValue(SetOvertime(overtimeRepository)),
            workRepositoryProvider.overrideWithValue(_FakeWorkRepository()),
            settingsViewModelProvider.overrideWith(_ImmediateSettingsViewModel.new),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('de'),
            home: Scaffold(
              body: Builder(builder: (context) {
                capturedContext = context;
                return const SizedBox.shrink();
              }),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Warm up the Dashboard notifier, like a user who already visited that tab.
      final container = ProviderScope.containerOf(capturedContext);
      container.read(dashboardViewModelProvider.notifier);
      await tester.pumpAndSettle();
      expect(container.read(dashboardViewModelProvider).initialOvertime, Duration.zero);

      // Real dialog route, exactly like `showDialog` in SettingsPage - only
      // this way does `Navigator.pop()` actually dispose the dialog's
      // `WidgetRef`, which is what the original bug depended on.
      unawaited(showDialog<void>(
        context: capturedContext,
        builder: (_) => const AddAdjustmentModal(),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(AddAdjustmentModal), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Stunden'), '5');
      await tester.tap(find.text('Speichern'));

      // Advance well past any dialog close-transition animation (~150ms),
      // but well before the delayed save (1000ms) resolves. The fixed code
      // keeps the dialog open the whole time since it awaits the save first;
      // the original buggy code called Navigator.pop() synchronously here,
      // so by this point the dialog would already be gone.
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(AddAdjustmentModal), findsOneWidget);

      // Let the delayed save complete.
      await tester.pumpAndSettle();

      // No unhandled exception (the original bug threw a StateError from a
      // disposed WidgetRef, silently, inside a fire-and-forget Future).
      expect(tester.takeException(), isNull);

      // The dialog closed...
      expect(find.byType(AddAdjustmentModal), findsNothing);

      // ...and the Dashboard actually received the update.
      expect(container.read(dashboardViewModelProvider).initialOvertime, const Duration(hours: 5));
    },
  );
}
