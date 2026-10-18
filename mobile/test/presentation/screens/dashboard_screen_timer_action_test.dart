import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/domain/entities/settings_entity.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/screens/dashboard_screen.dart';
import 'package:flutter_work_time/presentation/state/dashboard_state.dart';
import 'package:flutter_work_time/presentation/state/settings_state.dart';
import 'package:flutter_work_time/presentation/view_models/dashboard_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/open_entry_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/settings_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/timer_action_view_model.dart';

// Fehlerhinweis einer fehlgeschlagenen Timer-Aktion von aussen (#274):
// Snackbar `dashboardSaveError`, de und en.
class _FakeDashboard extends DashboardViewModel {
  @override
  DashboardState build() => DashboardState(
        workEntry: WorkEntryEntity(id: 'x', date: DateTime(2026, 10, 5)),
        elapsedTime: Duration.zero,
        totalOvertime: Duration.zero,
        dailyOvertime: Duration.zero,
      );
}

class _FakeSettings extends SettingsViewModel {
  @override
  AsyncValue<SettingsState> build() => const AsyncValue.data(SettingsState(
      settings: SettingsEntity(), overtimeBalance: Duration.zero));
}

class _NoOpenEntries extends OpenEntryViewModel {
  @override
  OpenEntryState build() => const OpenEntryState();
}

void main() {
  Future<ProviderContainer> pump(WidgetTester tester, String locale) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(overrides: [
      dashboardViewModelProvider.overrideWith(_FakeDashboard.new),
      settingsViewModelProvider.overrideWith(_FakeSettings.new),
      openEntryViewModelProvider.overrideWith(_NoOpenEntries.new),
      authStateProvider
          .overrideWithValue(const AsyncValue<UserEntity?>.data(null)),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: DashboardScreen()),
      ),
    ));
    await tester.pump();
    return container;
  }

  const de =
      'Speichern fehlgeschlagen. Bitte prüfe deine Verbindung und versuche es erneut.';

  testWidgets('failed -> Snackbar dashboardSaveError (de) und Hinweis zurueck',
      (tester) async {
    final container = await pump(tester, 'de');
    expect(find.text(de), findsNothing);

    container.read(timerActionFailurePendingProvider.notifier).state = true;
    await tester.pump();
    await tester.pump();

    expect(find.text(de), findsOneWidget);
    expect(container.read(timerActionFailurePendingProvider), isFalse);
  });

  testWidgets('failed -> Snackbar dashboardSaveError (en)', (tester) async {
    final container = await pump(tester, 'en');
    final en = lookupAppLocalizations(const Locale('en')).dashboardSaveError;

    container.read(timerActionFailurePendingProvider.notifier).state = true;
    await tester.pump();
    await tester.pump();

    expect(find.text(en), findsOneWidget);
    expect(find.text(de), findsNothing);
  });

  testWidgets('kein Fehlerhinweis -> keine Snackbar (applied/notApplicable)',
      (tester) async {
    await pump(tester, 'de');
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('Hinweis vor dem ersten Frame des Screens wird nachgeholt',
      (tester) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(overrides: [
      dashboardViewModelProvider.overrideWith(_FakeDashboard.new),
      settingsViewModelProvider.overrideWith(_FakeSettings.new),
      openEntryViewModelProvider.overrideWith(_NoOpenEntries.new),
      authStateProvider
          .overrideWithValue(const AsyncValue<UserEntity?>.data(null)),
    ]);
    addTearDown(container.dispose);
    container.read(timerActionFailurePendingProvider.notifier).state = true;

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: DashboardScreen()),
      ),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text(de), findsOneWidget);
  });
}
