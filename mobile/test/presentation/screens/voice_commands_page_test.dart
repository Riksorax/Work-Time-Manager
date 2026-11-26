import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/providers/subscription_provider.dart';
import 'package:flutter_work_time/domain/entities/settings_entity.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/screens/settings_page.dart';
import 'package:flutter_work_time/presentation/screens/voice_commands_page.dart';
import 'package:flutter_work_time/presentation/state/leave_balance_state.dart';
import 'package:flutter_work_time/presentation/state/settings_state.dart';
import 'package:flutter_work_time/presentation/view_models/leave_balance_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/settings_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import '../../support/offline_fixture.dart' show loadMaterialFonts;

// Hilfe „Sprachbefehle“ in den Einstellungen (#584).
class _FakeSettingsViewModel extends SettingsViewModel {
  @override
  AsyncValue<SettingsState> build() => const AsyncValue.data(SettingsState(
      settings: SettingsEntity(), overtimeBalance: Duration.zero));
}

class _FakeLeave extends LeaveBalanceViewModel {
  @override
  LeaveBalanceState build() => const LeaveBalanceState();
}

const _de = (
  locale: 'de',
  title: 'Sprachbefehle',
  subtitle: 'Mit dem Google Assistant',
  intro: 'Sag „Hey Google, öffne … in Work Time Manager“',
  android: 'Funktioniert nur auf Android.',
  timer: 'Timer (kostenlos)',
  queries: 'Abfragen (Premium, Anmeldung nötig)',
  commands: [
    '„Arbeitstag starten“',
    '„Pause starten“',
    '„Pause beenden“',
    '„Feierabend“',
    '„Überstunden“',
    '„Resturlaub“',
    '„Wochen-Trend“',
  ],
  hint: 'Die Spracherkennung übernimmt der Google Assistant.',
);

const _en = (
  locale: 'en',
  title: 'Voice commands',
  subtitle: 'With Google Assistant',
  intro: 'Say “Hey Google, open … in Work Time Manager”',
  android: 'Android only.',
  timer: 'Timer (free)',
  queries: 'Queries (Premium, sign-in required)',
  commands: [
    '“clock in”',
    '“start break”',
    '“end break”',
    '“clock out”',
    '“overtime”',
    '“remaining leave”',
    '“weekly trend”',
  ],
  hint: 'Speech recognition is handled by Google Assistant.',
);

void main() {
  setUpAll(() async {
    tz_data.initializeTimeZones();
    await loadMaterialFonts();
  });

  Future<void> pumpSettings(WidgetTester tester, String locale) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsViewModelProvider.overrideWith(_FakeSettingsViewModel.new),
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

  Future<void> pumpPage(WidgetTester tester, String locale,
      {double width = 412, bool dark = false}) async {
    tester.view.physicalSize = Size(width, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(fontFamily: 'Roboto'),
      darkTheme: ThemeData(fontFamily: 'Roboto', brightness: Brightness.dark),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const VoiceCommandsPage(),
    ));
    await tester.pump();
  }

  for (final t in [_de, _en]) {
    group('Sprache ${t.locale}', () {
      testWidgets('Eintrag in den Einstellungen öffnet die Hilfe',
          (tester) async {
        await pumpSettings(tester, t.locale);
        final entry = find.widgetWithText(ListTile, t.title);
        await tester.scrollUntilVisible(entry, 200,
            scrollable: find.byType(Scrollable).first);
        expect(entry, findsOneWidget);
        expect(find.text(t.subtitle), findsOneWidget);
        expect(
            find.descendant(
                of: entry, matching: find.byIcon(Icons.chevron_right)),
            findsOneWidget);

        await tester.tap(entry);
        await tester.pumpAndSettle();
        expect(find.byType(VoiceCommandsPage), findsOneWidget);
        expect(find.widgetWithText(AppBar, t.title), findsOneWidget);
      });

      testWidgets('Inhalt der Hilfe', (tester) async {
        await pumpPage(tester, t.locale, width: 412);
        expect(find.textContaining(t.intro), findsOneWidget);
        expect(find.textContaining(t.android), findsOneWidget);
        expect(find.text(t.timer), findsOneWidget);
        expect(find.text(t.queries), findsOneWidget);
        await tester.scrollUntilVisible(find.textContaining(t.hint), 200,
            scrollable: find.byType(Scrollable).first);
        for (final c in t.commands) {
          expect(find.text(c), findsOneWidget, reason: c);
        }
        expect(find.textContaining(t.hint), findsOneWidget);
      });

      for (final width in [320.0, 360.0]) {
        for (final dark in [false, true]) {
          testWidgets(
              'kein Überlauf bei ${width.toInt()} px${dark ? ', dunkel' : ''}',
              (tester) async {
            await pumpPage(tester, t.locale, width: width, dark: dark);
            expect(tester.takeException(), isNull);
            await tester.scrollUntilVisible(find.textContaining(t.hint), 200,
                scrollable: find.byType(Scrollable).first);
            await tester.pump();
            expect(tester.takeException(), isNull);
          });
        }
      }
    });
  }
}
