import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/clock_provider.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/providers/subscription_provider.dart';
import 'package:flutter_work_time/domain/entities/trend_report.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/entities/work_profile_entity.dart';
import 'package:flutter_work_time/domain/utils/assistant_query.dart';
import 'package:flutter_work_time/domain/utils/leave_balance_utils.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/screens/login_page.dart';
import 'package:flutter_work_time/presentation/state/dashboard_state.dart';
import 'package:flutter_work_time/presentation/state/leave_balance_state.dart';
import 'package:flutter_work_time/presentation/view_models/dashboard_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/leave_balance_view_model.dart';
import 'package:flutter_work_time/presentation/widgets/assistant_query_sheet.dart';

import '../../support/trend_fixture.dart';

/// Antwort-Ansicht der Sprachabfragen (#287). Feste Werte, keine Abhaengigkeit
/// von Datum, Wochentag oder Zeitzone.
class _FakeDashboard extends DashboardViewModel {
  _FakeDashboard(this.initial);
  final DashboardState initial;

  @override
  DashboardState build() => initial;
}

class _FakeLeave extends LeaveBalanceViewModel {
  _FakeLeave(this.initial);
  final LeaveBalanceState initial;
  int reloads = 0;

  @override
  LeaveBalanceState build() => initial;

  @override
  Future<void> reload() async => reloads++;
}

class _FakeActiveProfile extends ActiveWorkProfileIdNotifier {
  _FakeActiveProfile(this.id);
  final String? id;

  @override
  String? build() => id;
}

DashboardState _dash({Duration? total, bool loading = false}) => DashboardState(
      workEntry: WorkEntryEntity(id: '2026-10-05', date: DateTime(2026, 10, 5)),
      elapsedTime: Duration.zero,
      isLoading: loading,
      totalOvertime: total,
    );

const _balance = LeaveBalance(
    year: 2026, entitlement: 30, taken: 18, remaining: 12, sickDays: 2);

const _user = UserEntity(id: 'u1');

const _screenHeight = 800.0;
const _navBar = 34.0;

void main() {
  late _FakeLeave leave;
  late FakeTrendApi trendApi;

  Future<void> open(
    WidgetTester tester,
    AssistantQuery query, {
    String locale = 'de',
    bool signedIn = true,
    bool premium = true,
    DashboardState? dashboard,
    LeaveBalanceState leaveState = const LeaveBalanceState(balance: _balance),
    String? activeProfile,
    Size size = const Size(400, _screenHeight),
    double navBar = 0,
    double textScale = 1.0,
    Future<Map<String, dynamic>> Function(TrendCall c)? trend,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    leave = _FakeLeave(leaveState);
    trendApi = FakeTrendApi(
        trend ?? (c) async => trendJson(c.date, c.granularity.apiValue));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authStateProvider.overrideWithValue(
            AsyncValue<UserEntity?>.data(signedIn ? _user : null)),
        isPremiumProvider.overrideWithValue(premium),
        // Fester Bezugstag (Do 12.11.2026) für die Trend-Abfrage.
        clockProvider.overrideWithValue(() => DateTime(2026, 11, 12, 9)),
        apiClientProvider.overrideWithValue(trendApi),
        dashboardViewModelProvider.overrideWith(() => _FakeDashboard(
            dashboard ?? _dash(total: const Duration(hours: 2, minutes: 30)))),
        leaveBalanceViewModelProvider.overrideWith(() => leave),
        activeWorkProfileIdProvider
            .overrideWith(() => _FakeActiveProfile(activeProfile)),
        workProfilesProvider.overrideWith((ref) async => [
              WorkProfileEntity.defaultProfile(),
              const WorkProfileEntity(id: 'p2', name: 'Nebenjob'),
            ]),
      ],
      child: MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: EdgeInsets.only(bottom: navBar),
            viewPadding: EdgeInsets.only(bottom: navBar),
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showAssistantQuerySheet(context, query),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    // Kein pumpAndSettle: die Ladeanzeige animiert endlos.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  final de = lookupAppLocalizations(const Locale('de'));
  final en = lookupAppLocalizations(const Locale('en'));

  Color? colorOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style?.color;

  group('Ueberstunden (Premium)', () {
    testWidgets('positiver Wert wie im Dashboard, gruen (de)', (tester) async {
      await open(tester, AssistantQuery.overtime);

      expect(find.text('Überstunden Gesamt'), findsOneWidget);
      expect(find.text('+02:30'), findsOneWidget);
      expect(colorOf(tester, '+02:30'), Colors.green);
    });

    testWidgets('negativer Wert mit Vorzeichen, rot', (tester) async {
      await open(tester, AssistantQuery.overtime,
          dashboard: _dash(total: -const Duration(hours: 1, minutes: 15)));

      expect(find.text('-01:15'), findsOneWidget);
      expect(colorOf(tester, '-01:15'), Colors.red);
    });

    testWidgets('englisch', (tester) async {
      await open(tester, AssistantQuery.overtime, locale: 'en');

      expect(find.text(en.overtimeTotalLabel), findsOneWidget);
      expect(find.text('+02:30'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('Laden: Fortschrittsanzeige', (tester) async {
      await open(tester, AssistantQuery.overtime,
          dashboard: _dash(loading: true));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(de.assistantQueryOvertimeError), findsNothing);
    });

    testWidgets('Fehler: Dashboard nicht geladen', (tester) async {
      await open(tester, AssistantQuery.overtime, dashboard: _dash());

      expect(find.text(de.assistantQueryOvertimeError), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('Resturlaub (Premium)', () {
    testWidgets('Rest, Anspruch und Jahr (de)', (tester) async {
      await open(tester, AssistantQuery.leave);

      expect(find.text('Resturlaub'), findsOneWidget);
      expect(find.text('12 von 30 Tagen'), findsOneWidget);
      expect(find.text('Jahr 2026'), findsOneWidget);
    });

    testWidgets('englisch', (tester) async {
      await open(tester, AssistantQuery.leave, locale: 'en');

      expect(find.text('12 of 30 days'), findsOneWidget);
      expect(find.text('Year 2026'), findsOneWidget);
    });

    testWidgets('Laden: Fortschrittsanzeige', (tester) async {
      await open(tester, AssistantQuery.leave,
          leaveState: const LeaveBalanceState(isLoading: true));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Fehler mit Erneut versuchen', (tester) async {
      await open(tester, AssistantQuery.leave,
          leaveState: const LeaveBalanceState(hasError: true));

      expect(find.text(de.leaveLoadError), findsOneWidget);
      await tester.tap(find.text(de.leaveRetry));
      await tester.pump();
      expect(leave.reloads, 1);
    });

    testWidgets('ueber dem Anspruch', (tester) async {
      await open(tester, AssistantQuery.leave,
          leaveState: const LeaveBalanceState(
              balance: LeaveBalance(
                  year: 2026,
                  entitlement: 30,
                  taken: 32,
                  remaining: -2,
                  sickDays: 0)));

      expect(find.text('2 Tage über dem Anspruch'), findsOneWidget);
    });
  });

  group('Wochen-Trend (Premium, #287 Teil B)', () {
    testWidgets('Daten (de): Wortlaut wie die Karte der Trend-Ansicht',
        (tester) async {
      await open(tester, AssistantQuery.trend);

      expect(find.text('Wochen-Trend'), findsOneWidget);
      expect(
          find.text('+02:30 h gegenüber dem Durchschnitt der letzten 4 Wochen'),
          findsOneWidget);
      expect(
          find.text('KW 45: 41:30 h · Durchschnitt 39:00 h'), findsOneWidget);
      expect(find.byIcon(Icons.trending_up), findsOneWidget);
      // Dieselbe Quelle wie die Trend-Ansicht: Wochen, Bezugstag heute,
      // Standard-Profil.
      final call = trendApi.calls.single;
      expect(call.date, DateTime(2026, 11, 12));
      expect(call.granularity, TrendGranularity.week);
      expect(call.profileId, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('englisch', (tester) async {
      await open(tester, AssistantQuery.trend, locale: 'en');

      expect(find.text('Weekly trend'), findsOneWidget);
      expect(
          find.text(
              '+02:30 h compared with the average of the previous 4 weeks'),
          findsOneWidget);
      expect(find.text('CW 45: 41:30 h · average 39:00 h'), findsOneWidget);
    });

    testWidgets('neutral: Icon ohne Wertungsfarbe, auch bei Minus',
        (tester) async {
      await open(tester, AssistantQuery.trend,
          trend: (c) async => trendJson(c.date, c.granularity.apiValue)
            ..['weeklyTrend'] = {
              'lastWeekKey': '2026-W45',
              'lastWeekWorkedMs': 36 * 3600000,
              'averageWorkedMs': 39 * 3600000,
              'deltaMs': -3 * 3600000,
              'comparedWeeks': 3,
            });

      expect(
          find.text('-03:00 h gegenüber dem Durchschnitt der letzten 3 Wochen'),
          findsOneWidget);
      expect(
          find.text('KW 45: 36:00 h · Durchschnitt 39:00 h'), findsOneWidget);
      final icon = tester.widget<Icon>(find.byIcon(Icons.trending_down));
      final cs = Theme.of(tester.element(find.byType(AssistantQuerySheet)))
          .colorScheme;
      expect(icon.color, cs.onSurfaceVariant);
    });

    testWidgets('weeklyTrend null: zu wenig Daten wie in der Karte',
        (tester) async {
      await open(tester, AssistantQuery.trend,
          trend: (c) async =>
              trendJson(c.date, c.granularity.apiValue, weeklyTrend: false));

      expect(find.text('Für den Wochen-Trend liegen noch zu wenig Daten vor.'),
          findsOneWidget);
      expect(find.textContaining('Durchschnitt'), findsNothing);
    });

    testWidgets('englisch null', (tester) async {
      await open(tester, AssistantQuery.trend,
          locale: 'en',
          trend: (c) async =>
              trendJson(c.date, c.granularity.apiValue, weeklyTrend: false));

      expect(find.text(en.trendWeekTooLittle), findsOneWidget);
    });

    testWidgets('Laden: Fortschrittsanzeige', (tester) async {
      await open(tester, AssistantQuery.trend,
          trend: (_) => Completer<Map<String, dynamic>>().future);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Wochen-Trend'), findsOneWidget);
    });

    testWidgets('Fehler mit Erneut versuchen, lädt einmal neu', (tester) async {
      var fail = true;
      await open(tester, AssistantQuery.trend, trend: (c) async {
        if (fail) throw Exception('boom');
        return trendJson(c.date, c.granularity.apiValue);
      });

      expect(find.text(de.trendLoadError), findsOneWidget);
      // Kein automatisches Wiederholen.
      await tester.pump(const Duration(seconds: 30));
      expect(trendApi.calls, hasLength(1));

      fail = false;
      await tester.tap(find.text(de.retryButton));
      await tester.pump();
      await tester.pump();

      expect(trendApi.calls, hasLength(2));
      expect(find.text(de.trendLoadError), findsNothing);
      expect(
          find.text('KW 45: 41:30 h · Durchschnitt 39:00 h'), findsOneWidget);
    });

    testWidgets('Fehler englisch', (tester) async {
      await open(tester, AssistantQuery.trend,
          locale: 'en', trend: (_) async => throw Exception('boom'));

      expect(find.text(en.trendLoadError), findsOneWidget);
      expect(find.text(en.retryButton), findsOneWidget);
    });

    testWidgets('zusaetzliches Profil: Profilname und profileId',
        (tester) async {
      await open(tester, AssistantQuery.trend, activeProfile: 'p2');

      expect(find.text('Profil: Nebenjob'), findsOneWidget);
      expect(trendApi.calls.single.profileId, 'p2');
      expect(
          find.text('KW 45: 41:30 h · Durchschnitt 39:00 h'), findsOneWidget);
    });

    testWidgets('ohne Premium englisch: eigener Hinweis', (tester) async {
      await open(tester, AssistantQuery.trend, premium: false, locale: 'en');

      expect(find.text(en.assistantQueryTrendPremiumHint), findsOneWidget);
      expect(trendApi.calls, isEmpty);
    });

    testWidgets('nicht angemeldet: Anmelde-Hinweis, kein Aufruf',
        (tester) async {
      await open(tester, AssistantQuery.trend, signedIn: false);

      expect(find.text('Melde dich an, um deine Arbeitszeit-Daten abzufragen.'),
          findsOneWidget);
      expect(find.textContaining('Resturlaub'), findsNothing);
      expect(find.text(de.loginButton), findsOneWidget);
      expect(trendApi.calls, isEmpty);
    });

    testWidgets('TalkBack: Antwort liegt in der Live-Region', (tester) async {
      await open(tester, AssistantQuery.trend);

      final live = find.descendant(
        of: find.byType(AssistantQuerySheet),
        matching: find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.liveRegion == true),
      );
      expect(
          find.descendant(
              of: live,
              matching: find.text(
                  '+02:30 h gegenüber dem Durchschnitt der letzten 4 Wochen')),
          findsOneWidget);
    });
  });

  group('ohne Premium', () {
    for (final query in AssistantQuery.values) {
      testWidgets('${query.name}: Hinweis statt Zahl, Button oeffnet Paywall',
          (tester) async {
        await open(tester, query, premium: false);

        expect(
            find.text(query == AssistantQuery.trend
                ? de.assistantQueryTrendPremiumHint
                : de.assistantQueryPremiumHint),
            findsOneWidget);
        expect(find.text('+02:30'), findsNothing);
        expect(find.text('12 von 30 Tagen'), findsNothing);
        expect(find.textContaining('Durchschnitt'), findsNothing);
        expect(trendApi.calls, isEmpty, reason: 'kein Backend-Aufruf');

        // Ohne konfiguriertes RevenueCat (Test) meldet `showPaywall` das per
        // Snackbar; das belegt den Aufruf.
        await tester.tap(find.text(de.unlockPremiumButton));
        await tester.pump();
        expect(find.text(de.paywallUnavailable), findsOneWidget);
      });
    }

    testWidgets('englisch', (tester) async {
      await open(tester, AssistantQuery.overtime, premium: false, locale: 'en');

      expect(find.text(en.assistantQueryPremiumHint), findsOneWidget);
      expect(find.text(en.unlockPremiumButton), findsOneWidget);
    });
  });

  group('nicht angemeldet', () {
    testWidgets('Hinweis mit Anmelden, fuehrt zur Anmeldung', (tester) async {
      await open(tester, AssistantQuery.overtime,
          signedIn: false, premium: false);

      expect(find.text(de.assistantQueryLoginHint), findsOneWidget);
      // Allgemein formuliert, passt zu allen Abfragen (auch Wochen-Trend).
      expect(find.text('Melde dich an, um deine Arbeitszeit-Daten abzufragen.'),
          findsOneWidget);
      expect(find.text(de.assistantQueryPremiumHint), findsNothing);
      expect(find.text('+02:30'), findsNothing);

      await tester.tap(find.text(de.loginButton));
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(AssistantQuerySheet), findsNothing);
    });

    testWidgets('englisch', (tester) async {
      await open(tester, AssistantQuery.leave, signedIn: false, locale: 'en');

      expect(find.text(en.assistantQueryLoginHint), findsOneWidget);
      expect(find.text('Sign in to check your working time data.'),
          findsOneWidget);
      expect(find.text(en.loginButton), findsOneWidget);
    });
  });

  group('Arbeitszeit-Profil', () {
    testWidgets('Standard-Profil: kein Profilname', (tester) async {
      await open(tester, AssistantQuery.overtime);

      expect(find.textContaining('Profil:'), findsNothing);
    });

    testWidgets('zusaetzliches Profil: Name wird genannt', (tester) async {
      await open(tester, AssistantQuery.overtime, activeProfile: 'p2');

      expect(find.text('Profil: Nebenjob'), findsOneWidget);
    });
  });

  testWidgets('TalkBack: Inhalt ist eine Live-Region', (tester) async {
    await open(tester, AssistantQuery.overtime);

    final live = find.descendant(
      of: find.byType(AssistantQuerySheet),
      matching: find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.liveRegion == true),
    );
    expect(live, findsOneWidget);
    expect(find.descendant(of: live, matching: find.text('+02:30')), findsOne);
  });

  testWidgets('Schliessen-Button schliesst das Sheet', (tester) async {
    await open(tester, AssistantQuery.overtime);

    await tester.tap(find.text('Schließen'));
    await tester.pumpAndSettle();

    expect(find.byType(AssistantQuerySheet), findsNothing);
  });

  testWidgets('Edge-to-Edge: Schliessen liegt oberhalb der Navigationsleiste',
      (tester) async {
    await open(tester, AssistantQuery.overtime, navBar: _navBar);

    expect(tester.getBottomLeft(find.text('Schließen')).dy,
        lessThanOrEqualTo(_screenHeight - _navBar));
  });

  testWidgets('neue Abfrage ersetzt ein offenes Sheet, dismiss schliesst',
      (tester) async {
    await open(tester, AssistantQuery.overtime);
    final ctx = tester.element(find.text('open'));

    showAssistantQuerySheet(ctx, AssistantQuery.leave);
    await tester.pumpAndSettle();

    expect(find.byType(AssistantQuerySheet), findsOneWidget);
    expect(find.text('12 von 30 Tagen'), findsOneWidget);

    dismissAssistantQuerySheet();
    await tester.pumpAndSettle();
    expect(find.byType(AssistantQuerySheet), findsNothing);
    // Ohne offenes Sheet ein No-op.
    dismissAssistantQuerySheet();
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
  });

  group('schmale Breite ohne Overflow', () {
    for (final locale in ['de', 'en']) {
      for (final (label, query, signedIn, premium) in [
        ('Ueberstunden', AssistantQuery.overtime, true, true),
        ('Resturlaub', AssistantQuery.leave, true, true),
        ('Free', AssistantQuery.overtime, true, false),
        ('Gast', AssistantQuery.leave, false, false),
        ('Wochen-Trend', AssistantQuery.trend, true, true),
        ('Wochen-Trend Free', AssistantQuery.trend, true, false),
      ]) {
        testWidgets('$label ($locale) bei 320 dp und 1,5-facher Schrift',
            (tester) async {
          await open(tester, query,
              locale: locale,
              signedIn: signedIn,
              premium: premium,
              activeProfile: 'p2',
              size: const Size(320, 568),
              textScale: 1.5);

          expect(find.byType(AssistantQuerySheet), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  test('Format wie im Dashboard', () {
    expect(formatOvertimeLikeDashboard(Duration.zero), '+00:00');
    expect(formatOvertimeLikeDashboard(const Duration(hours: 12, minutes: 5)),
        '+12:05');
    expect(formatOvertimeLikeDashboard(-const Duration(minutes: 59)), '-00:59');
    expect(formatOvertimeLikeDashboard(-const Duration(hours: 100, minutes: 1)),
        '-100:01');
  });
}
