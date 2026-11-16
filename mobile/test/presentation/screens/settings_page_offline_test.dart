import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/providers/subscription_provider.dart';
import 'package:flutter_work_time/core/theme/app_theme.dart';
import 'package:flutter_work_time/core/utils/api_errors.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';
import 'package:flutter_work_time/domain/entities/work_profile_entity.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/screens/settings_page.dart';
import 'package:flutter_work_time/presentation/state/leave_balance_state.dart';
import 'package:flutter_work_time/presentation/view_models/leave_balance_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/settings_view_model.dart';

import '../../support/offline_fixture.dart';

/// #573: Einstellungen angemeldet ohne Netz. Echtes SettingsViewModel, echte
/// Hybrid-/Firebase-Repositories für den Saldo.
class _Leave extends LeaveBalanceViewModel {
  @override
  LeaveBalanceState build() => const LeaveBalanceState();
}

class _NoProfile extends ActiveWorkProfileIdNotifier {
  @override
  String? build() => null;
}

const _user = UserEntity(id: 'u1', email: 'a@b.c', displayName: 'Lea');

void main() {
  setUpAll(() async {
    tz_data.initializeTimeZones();
    await loadMaterialFonts();
  });

  late OfflineOvertimeDataSource ds;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    ds = OfflineOvertimeDataSource()..offline = true;
  });

  /// Feste Schritte statt `pumpAndSettle`: ein Ladekreis eines
  /// Nebenabschnitts animiert dauerhaft.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pump(WidgetTester tester,
      {String locale = 'de', double width = 412}) async {
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsRepositoryProvider.overrideWithValue(NoOpSettingsRepository()),
        overtimeRepositoryProvider
            .overrideWith((ref) => signedInOvertimeRepository(ds, prefs)),
        leaveBalanceViewModelProvider.overrideWith(_Leave.new),
        authStateProvider.overrideWithValue(const AsyncValue.data(_user)),
        activeWorkProfileIdProvider.overrideWith(_NoProfile.new),
        workProfilesProvider
            .overrideWith((ref) async => [WorkProfileEntity.defaultProfile()]),
        isPremiumProvider.overrideWithValue(false),
        activeEntitlementProvider.overrideWithValue(null),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SettingsPage(),
      ),
    ));
    await settle(tester);
  }

  void expectNoRawError() {
    for (final raw in ['Exception', 'host lookup', 'uri=', 'Fehler:']) {
      expect(find.textContaining(raw), findsNothing, reason: raw);
    }
  }

  for (final (locale, stale, unknown, error, retry) in [
    (
      'de',
      'Offline – Stand vom letzten Abruf',
      'Offline – noch kein Stand gespeichert',
      'Die Einstellungen konnten nicht geladen werden.',
      'Erneut versuchen',
    ),
    (
      'en',
      'Offline – last synced value',
      'Offline – no value saved yet',
      'Settings could not be loaded.',
      'Retry',
    ),
  ]) {
    group('Sprache $locale', () {
      testWidgets('ohne Netz mit gemerktem Saldo: Wert und Hinweis',
          (tester) async {
        await rememberOvertime(prefs, -95);
        await pump(tester, locale: locale);
        expectNoRawError();
        expect(find.text('-01:35'), findsOneWidget);
        expect(find.text(stale), findsOneWidget);
        // Die übrigen Einstellungen sind da (Wochensoll aus dem lokalen Repo).
        expect(find.textContaining('40'), findsWidgets);
      });

      testWidgets('ohne Netz ohne gemerkten Saldo: Strich statt +00:00',
          (tester) async {
        await pump(tester, locale: locale);
        expectNoRawError();
        expect(find.text('+00:00'), findsNothing);
        expect(find.text('—'), findsOneWidget);
        expect(find.text(unknown), findsOneWidget);
      });

      testWidgets('online: kein Hinweis', (tester) async {
        ds
          ..offline = false
          ..minutes['u1|default'] = 30;
        await pump(tester, locale: locale);
        expect(find.text('+00:30'), findsOneWidget);
        expect(find.text(stale), findsNothing);
        expect(find.text(unknown), findsNothing);
      });

      testWidgets('unerwarteter Fehler: Meldung, „Erneut versuchen“ lädt neu',
          (tester) async {
        ds
          ..offline = false
          ..failWith = const ApiException('getOvertime', 500);
        await pump(tester, locale: locale);
        expectNoRawError();
        expect(find.text(error), findsOneWidget);

        ds
          ..failWith = null
          ..minutes['u1|default'] = 30;
        await tester.tap(find.text(retry));
        await settle(tester);
        expect(find.text(error), findsNothing);
        expect(find.text('+00:30'), findsOneWidget);
      });

      for (final width in [320.0, 360.0]) {
        testWidgets('ohne Netz bei $width px: kein Überlauf', (tester) async {
          await pump(tester, locale: locale, width: width);
          expect(tester.takeException(), isNull);
          expect(find.text(unknown), findsOneWidget);
        });
      }
    });
  }
}
