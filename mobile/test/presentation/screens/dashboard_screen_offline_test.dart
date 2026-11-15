import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_work_time/core/providers/clock_provider.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/theme/app_theme.dart';
import 'package:flutter_work_time/core/utils/api_errors.dart';
import 'package:flutter_work_time/domain/entities/settings_entity.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';
import 'package:flutter_work_time/domain/entities/work_profile_entity.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/screens/dashboard_screen.dart';
import 'package:flutter_work_time/presentation/state/leave_balance_state.dart';
import 'package:flutter_work_time/presentation/state/settings_state.dart';
import 'package:flutter_work_time/presentation/view_models/leave_balance_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/open_entry_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/settings_view_model.dart';

import '../../support/fake_repositories.dart';
import '../../support/offline_fixture.dart';
import '../../support/reported_logs.dart';

/// #573: Dashboard angemeldet ohne Netz. Der heutige Eintrag ist nicht ladbar
/// (Einträge kommen angemeldet nur über die API); das Dashboard zeigt keinen
/// Fehlertext, stürzt nicht ab und zeigt den zuletzt bekannten Saldo mit
/// Hinweis bzw. einen Strich. Echtes DashboardViewModel, echte Hybrid-/
/// Firebase-Repositories für den Saldo; feste Uhr Mo 05.10.2026, 10:00.
class _OpenEntry extends OpenEntryViewModel {
  @override
  OpenEntryState build() => const OpenEntryState();
}

class _Settings extends SettingsViewModel {
  @override
  AsyncValue<SettingsState> build() => const AsyncValue.data(
      SettingsState(settings: SettingsEntity(), overtimeBalance: null));
}

class _Leave extends LeaveBalanceViewModel {
  @override
  LeaveBalanceState build() => const LeaveBalanceState();
}

class _NoProfile extends ActiveWorkProfileIdNotifier {
  @override
  String? build() => null;
}

const _user = UserEntity(id: 'u1', email: 'a@b.c');

void main() {
  final logs = <LogEvent>[];
  captureLogs(logs);

  setUpAll(loadMaterialFonts);

  late OfflineOvertimeDataSource ds;
  late FakeWorkRepository work;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    ds = OfflineOvertimeDataSource()..offline = true;
    work = FakeWorkRepository()
      ..failReads = true
      ..readError = hostLookupError;
  });

  Future<void> pump(WidgetTester tester,
      {String locale = 'de', double width = 412}) async {
    tester.view.physicalSize = Size(width, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        workRepositoryProvider.overrideWithValue(work),
        overtimeRepositoryProvider
            .overrideWith((ref) => signedInOvertimeRepository(ds, prefs)),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        openEntryViewModelProvider.overrideWith(_OpenEntry.new),
        settingsViewModelProvider.overrideWith(_Settings.new),
        leaveBalanceViewModelProvider.overrideWith(_Leave.new),
        activeWorkProfileIdProvider.overrideWith(_NoProfile.new),
        workProfilesProvider
            .overrideWith((ref) async => [WorkProfileEntity.defaultProfile()]),
        authStateProvider.overrideWithValue(const AsyncValue.data(_user)),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 5, 10)),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
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

  void expectNoRawError() {
    for (final raw in ['Exception', 'host lookup', 'uri=', 'Fehler']) {
      expect(find.textContaining(raw), findsNothing, reason: raw);
    }
  }

  /// Button mit [label] (ElevatedButton/TextButton) ist bedienbar.
  bool enabled(WidgetTester tester, String label) => tester
      .widget<ButtonStyleButton>(find.ancestor(
          of: find.text(label), matching: find.bySubtype<ButtonStyleButton>()))
      .enabled;

  for (final (
        locale,
        total,
        stale,
        unknown,
        offline,
        offlineText,
        failedText,
        retry,
        start,
        addBreak,
      ) in [
    (
      'de',
      'Überstunden Gesamt',
      'Offline – Stand vom letzten Abruf',
      'Offline – noch kein Stand gespeichert',
      'Keine Verbindung',
      'Die heutigen Zeiten können gerade nicht geladen werden.',
      'Das Dashboard konnte nicht geladen werden.',
      'Erneut versuchen',
      'Zeiterfassung starten',
      'Pause hinzufügen',
    ),
    (
      'en',
      'Total overtime',
      'Offline – last synced value',
      'Offline – no value saved yet',
      'No connection',
      "Today's times can't be loaded right now.",
      'The dashboard could not be loaded.',
      'Retry',
      'Start time tracking',
      'Add break',
    ),
  ]) {
    group('Sprache $locale', () {
      testWidgets('ohne Netz mit gemerktem Saldo: Wert und Hinweis',
          (tester) async {
        await rememberOvertime(prefs, 750);
        await pump(tester, locale: locale);
        expect(tester.takeException(), isNull);
        expectNoRawError();
        expect(find.text(total), findsOneWidget);
        expect(find.text('+12:30'), findsOneWidget);
        expect(find.text(stale), findsOneWidget);
        expect(reported(logs, ''), isEmpty);
        await unmount(tester);
      });

      testWidgets('ohne Netz ohne gemerkten Saldo: Strich statt +00:00',
          (tester) async {
        await pump(tester, locale: locale);
        expect(tester.takeException(), isNull);
        expectNoRawError();
        expect(find.text('+00:00'), findsNothing);
        // Zeit und Saldo unbekannt.
        expect(find.text('—'), findsNWidgets(2));
        expect(find.text(unknown), findsOneWidget);
        await unmount(tester);
      });

      testWidgets(
          'ohne Netz: Hinweis „Keine Verbindung“, Zeit „—“, Aktionen gesperrt',
          (tester) async {
        await rememberOvertime(prefs, 750);
        await pump(tester, locale: locale);
        expect(find.text(offline), findsOneWidget);
        expect(find.text(offlineText), findsOneWidget);
        expect(find.text(retry), findsOneWidget);
        expect(find.text('00:00:00'), findsNothing);
        expect(enabled(tester, start), isFalse);
        expect(enabled(tester, addBreak), isFalse);
        // Zeitfelder und Home-Office-Schalter ebenfalls gesperrt.
        expect(
            tester
                .widget<SwitchListTile>(find.byType(SwitchListTile))
                .onChanged,
            isNull);
        expect(enabled(tester, retry), isTrue);
        // Ein Tipp auf das gesperrte „Starten“ schreibt nichts.
        await tester.tap(find.text(start), warnIfMissed: false);
        await tester.pump();
        expect(work.saved, isEmpty);
        expect(find.byType(SnackBar), findsNothing);
        await unmount(tester);
      });

      testWidgets('„Erneut versuchen“ lädt neu, danach alles bedienbar',
          (tester) async {
        await pump(tester, locale: locale);
        expect(find.text(offline), findsOneWidget);

        ds
          ..offline = false
          ..minutes['u1|default'] = 30;
        work.failReads = false;
        await tester.tap(find.text(retry));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text(offline), findsNothing);
        expect(find.text(retry), findsNothing);
        expect(find.text('00:00:00'), findsOneWidget);
        expect(find.text('+00:30'), findsOneWidget);
        expect(find.text(stale), findsNothing);
        expect(enabled(tester, start), isTrue);
        expect(enabled(tester, addBreak), isTrue);
        await unmount(tester);
      });

      testWidgets('unerwarteter Fehler: eigener Text, ohne Ausnahmetext',
          (tester) async {
        ds.offline = false;
        work.readError = const ApiException('getWorkEntry', 500);
        await pump(tester, locale: locale);
        expectNoRawError();
        expect(find.textContaining('500'), findsNothing);
        expect(find.text(failedText), findsOneWidget);
        expect(find.text(offline), findsNothing);
        // Saldo nicht geladen: Strich statt +00:00.
        expect(find.text('+00:00'), findsNothing);
        expect(enabled(tester, start), isFalse);

        work.failReads = false;
        await tester.tap(find.text(retry));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text(failedText), findsNothing);
        expect(enabled(tester, start), isTrue);
        await unmount(tester);
      });

      testWidgets('online: kein Hinweis', (tester) async {
        ds
          ..offline = false
          ..minutes['u1|default'] = 30;
        work.failReads = false;
        await pump(tester, locale: locale);
        expect(find.text('+00:30'), findsOneWidget);
        expect(find.text(stale), findsNothing);
        expect(find.text(unknown), findsNothing);
        expect(find.text(offline), findsNothing);
        expect(enabled(tester, start), isTrue);
        await unmount(tester);
      });

      for (final width in [320.0, 360.0]) {
        testWidgets('ohne Netz bei $width px: kein Überlauf', (tester) async {
          await rememberOvertime(prefs, -95);
          await pump(tester, locale: locale, width: width);
          expect(tester.takeException(), isNull);
          expect(find.text(stale), findsOneWidget);
          expect(find.text(offline), findsOneWidget);
          expect(find.text(retry), findsOneWidget);
          await unmount(tester);
        });
      }
    });
  }
}
