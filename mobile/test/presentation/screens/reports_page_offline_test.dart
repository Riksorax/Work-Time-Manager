import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_work_time/core/providers/clock_provider.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/providers/subscription_provider.dart';
import 'package:flutter_work_time/core/theme/app_theme.dart';
import 'package:flutter_work_time/core/utils/api_errors.dart';
import 'package:flutter_work_time/data/datasources/remote/api_client.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/entities/work_profile_entity.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/screens/reports_page.dart';
import 'package:flutter_work_time/presentation/view_models/settings_view_model.dart';

import '../../support/fake_repositories.dart';
import '../../support/offline_fixture.dart';

/// #573: Angemeldet ohne Netz zeigten die Berichte als einzigen Inhalt
/// „Fehler beim Laden der Einstellungen: ClientException with
/// SocketException …“. Echtes Settings- und Reports-ViewModel, echte
/// Hybrid-/Firebase-Repositories für den Saldo; feste Daten im Oktober 2026.
class _NoProfile extends ActiveWorkProfileIdNotifier {
  @override
  String? build() => null;
}

class _Api extends Fake implements ApiClient {
  @override
  Future<Map<String, dynamic>> getDailyReport(int y, int m, int d,
          {String? profileId}) =>
      Future.error(hostLookupError);
  @override
  Future<Map<String, dynamic>> getWeeklyReport(int y, int m, int d,
          {String? profileId}) =>
      Future.error(hostLookupError);
  @override
  Future<Map<String, dynamic>> getMonthlyReport(int y, int m,
          {String? profileId}) =>
      Future.error(hostLookupError);
}

const _user = UserEntity(id: 'u1', email: 'a@b.c');

const _texts = {
  'de': (
    offline: 'Keine Verbindung',
    retry: 'Erneut versuchen',
    settingsError: 'Die Einstellungen konnten nicht geladen werden.',
    stale: 'Offline – Stand vom letzten Abruf',
    unknown: 'Offline – noch kein Stand gespeichert',
  ),
  'en': (
    offline: 'No connection',
    retry: 'Retry',
    settingsError: 'Settings could not be loaded.',
    stale: 'Offline – last synced value',
    unknown: 'Offline – no value saved yet',
  ),
};

void main() {
  setUpAll(() async {
    await loadMaterialFonts();
    await initializeDateFormatting('de', null);
    await initializeDateFormatting('en', null);
  });

  late ProviderContainer container;
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
      {required int tab, String locale = 'de', double width = 412}) async {
    tester.view.physicalSize = Size(width, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    container = ProviderContainer(overrides: [
      clockProvider.overrideWithValue(() => DateTime(2026, 10, 9, 18)),
      sharedPreferencesProvider.overrideWithValue(prefs),
      workRepositoryProvider.overrideWithValue(work),
      overtimeRepositoryProvider
          .overrideWith((ref) => signedInOvertimeRepository(ds, prefs)),
      settingsRepositoryProvider.overrideWithValue(NoOpSettingsRepository()),
      activeWorkProfileIdProvider.overrideWith(_NoProfile.new),
      workProfilesProvider
          .overrideWith((ref) async => [WorkProfileEntity.defaultProfile()]),
      authStateProvider.overrideWithValue(const AsyncValue.data(_user)),
      isPremiumProvider.overrideWithValue(true),
      activeEntitlementProvider.overrideWithValue(null),
      apiClientProvider.overrideWithValue(_Api()),
    ]);
    container.read(pendingReportTabIndexProvider.notifier).state = tab;
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ReportsPage(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump(const Duration(seconds: 6));
  }

  void expectNoRawError() {
    for (final raw in ['Exception', 'SocketException', 'host lookup', 'uri=']) {
      expect(find.textContaining(raw), findsNothing, reason: raw);
    }
  }

  for (final locale in ['de', 'en']) {
    final t = _texts[locale]!;
    for (final (tab, name) in [
      (0, 'Täglich'),
      (1, 'Wöchentlich'),
      (2, 'Monatlich')
    ]) {
      group('$name ($locale)', () {
        testWidgets('ohne Netz: „Keine Verbindung“ statt Ausnahmetext',
            (tester) async {
          await pump(tester, tab: tab, locale: locale);
          expectNoRawError();
          expect(find.text(t.offline), findsOneWidget);
          expect(find.text(t.retry), findsOneWidget);
          await finish(tester);
        });

        testWidgets('„Erneut versuchen“ lädt neu', (tester) async {
          await pump(tester, tab: tab, locale: locale);
          final before = work.getMonthCalls;
          work
            ..failReads = false
            ..store['2026-10-09'] = WorkEntryEntity(
                id: '2026-10-09',
                date: DateTime(2026, 10, 9),
                workStart: DateTime(2026, 10, 9, 8),
                workEnd: DateTime(2026, 10, 9, 16));
          await tester.tap(find.text(t.retry));
          await tester.pumpAndSettle();
          expect(work.getMonthCalls, greaterThan(before));
          expect(find.text(t.offline), findsNothing);
          expect(find.text(t.retry), findsNothing);
          await finish(tester);
        });

        testWidgets(
            'unerwarteter Fehler der Einstellungen: Meldung ohne '
            'Ausnahmetext, „Erneut versuchen“ lädt neu', (tester) async {
          ds
            ..offline = false
            ..failWith = const ApiException('getOvertime', 500);
          work.failReads = false;
          await pump(tester, tab: tab, locale: locale);
          expectNoRawError();
          expect(find.textContaining('500'), findsNothing);
          expect(find.text(t.settingsError), findsOneWidget);

          ds.failWith = null;
          await tester.tap(find.text(t.retry));
          await tester.pumpAndSettle();
          expect(find.text(t.settingsError), findsNothing);
          expect(find.text(t.retry), findsNothing);
          await finish(tester);
        });

        for (final width in [320.0, 360.0]) {
          testWidgets('ohne Netz bei $width px: kein Überlauf', (tester) async {
            await rememberOvertime(prefs, 750);
            await pump(tester, tab: tab, locale: locale, width: width);
            expect(tester.takeException(), isNull);
            expect(find.text(t.offline), findsOneWidget);
            await finish(tester);
          });
        }
      });
    }

    group('Monatlich, Gesamt-Überstunden ($locale)', () {
      testWidgets('gemerkter Saldo mit Hinweis „nicht aktuell“',
          (tester) async {
        await rememberOvertime(prefs, 750);
        await pump(tester, tab: 2, locale: locale);
        expect(find.text('+12:30'), findsOneWidget);
        expect(find.text(t.stale), findsOneWidget);
        await finish(tester);
      });

      testWidgets('ohne gemerkten Saldo: Strich statt +00:00', (tester) async {
        await pump(tester, tab: 2, locale: locale);
        expect(find.text('+00:00'), findsNothing);
        expect(find.text('—'), findsOneWidget);
        expect(find.text(t.unknown), findsOneWidget);
        await finish(tester);
      });
    });
  }
}
