import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/providers/subscription_provider.dart';
import 'package:flutter_work_time/domain/entities/settings_entity.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/screens/settings_page.dart';
import 'package:flutter_work_time/presentation/state/leave_balance_state.dart';
import 'package:flutter_work_time/presentation/state/settings_state.dart';
import 'package:flutter_work_time/presentation/view_models/leave_balance_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/settings_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;

// Abschnitt „Dashboard-Anzeige“ in den Einstellungen (#526).
class _RecordingSettingsViewModel extends SettingsViewModel {
  final List<(String, bool)> calls = [];

  @override
  AsyncValue<SettingsState> build() => const AsyncValue.data(SettingsState(
      settings: SettingsEntity(), overtimeBalance: Duration.zero));

  @override
  Future<void> updateShowWorkLocationOnDashboard(bool value) async {
    calls.add(('location', value));
    state = state.whenData((v) => v.copyWith(
        settings: v.settings.copyWith(showWorkLocationOnDashboard: value)));
  }

  @override
  Future<void> updateShowHomeOfficeOnDashboard(bool value) async {
    calls.add(('homeOffice', value));
    state = state.whenData((v) => v.copyWith(
        settings: v.settings.copyWith(showHomeOfficeOnDashboard: value)));
  }
}

class _FakeLeave extends LeaveBalanceViewModel {
  @override
  LeaveBalanceState build() => const LeaveBalanceState();
}

void main() {
  setUpAll(tz_data.initializeTimeZones);

  late _RecordingSettingsViewModel vm;

  Future<void> pump(WidgetTester tester, String locale,
      {double width = 800}) async {
    tester.view.physicalSize = Size(width, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    vm = _RecordingSettingsViewModel();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsViewModelProvider.overrideWith(() => vm),
        leaveBalanceViewModelProvider.overrideWith(_FakeLeave.new),
        authStateProvider
            .overrideWithValue(const AsyncValue<UserEntity?>.data(null)),
        isPremiumProvider.overrideWithValue(false),
        activeEntitlementProvider.overrideWithValue(null),
      ],
      child: MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SettingsPage(),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  for (final (locale, title, location, homeOffice, hint) in [
    (
      'de',
      'Dashboard-Anzeige',
      'Arbeitsort im Dashboard anzeigen',
      'Home-Office im Dashboard anzeigen',
      'Gilt nur fürs Dashboard'
    ),
    (
      'en',
      'Dashboard display',
      'Show work location on dashboard',
      'Show home office on dashboard',
      'Applies to the dashboard only'
    ),
  ]) {
    testWidgets('Abschnitt mit Standardwerten und Umschalten ($locale)',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, locale);
      await tester.scrollUntilVisible(find.text(homeOffice), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text(title), findsOneWidget);
      expect(find.textContaining(hint), findsOneWidget);
      final loc = find.widgetWithText(SwitchListTile, location);
      final ho = find.widgetWithText(SwitchListTile, homeOffice);
      expect(tester.widget<SwitchListTile>(loc).value, isFalse);
      expect(tester.widget<SwitchListTile>(ho).value, isTrue);

      await tester.tap(loc);
      await tester.pump();
      await tester.tap(ho);
      await tester.pump();

      expect(vm.calls, [('location', true), ('homeOffice', false)]);
      expect(tester.widget<SwitchListTile>(loc).value, isTrue);
      expect(tester.widget<SwitchListTile>(ho).value, isFalse);
      handle.dispose();
    });

    testWidgets('schmale Breite: Abschnitt bleibt in der Breite ($locale)',
        (tester) async {
      await pump(tester, locale, width: 320);
      // Profil-/Anmeldezeilen weiter oben laufen mit der Test-Schrift bei
      // 320 px schon vor #526 über; geprüft wird der neue Abschnitt.
      tester.takeException();
      await tester.scrollUntilVisible(find.text(homeOffice), 200,
          scrollable: find.byType(Scrollable).first);
      tester.takeException();
      for (final f in [
        find.text(title),
        find.text(location),
        find.text(homeOffice),
        find.textContaining(hint),
      ]) {
        expect(tester.getRect(f).right, lessThanOrEqualTo(320));
      }
    });
  }
}
