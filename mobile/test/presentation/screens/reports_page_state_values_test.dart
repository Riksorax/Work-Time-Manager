import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_work_time/core/providers/clock_provider.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/providers/subscription_provider.dart';
import 'package:flutter_work_time/core/services/pdf_report_service.dart';
import 'package:flutter_work_time/core/utils/api_errors.dart';
import 'package:flutter_work_time/data/datasources/remote/api_client.dart';
import 'package:flutter_work_time/domain/entities/break_entity.dart';
import 'package:flutter_work_time/domain/entities/settings_entity.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/entities/work_profile_entity.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/screens/reports_page.dart';
import 'package:flutter_work_time/presentation/state/monthly_report_state.dart';
import 'package:flutter_work_time/presentation/state/reports_state.dart';
import 'package:flutter_work_time/presentation/state/settings_state.dart';
import 'package:flutter_work_time/presentation/state/weekly_report_state.dart';
import 'package:flutter_work_time/presentation/view_models/reports_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/settings_view_model.dart';
import 'package:flutter_work_time/presentation/widgets/quick_entry_dialog.dart';

import '../../support/fake_repositories.dart';

/// #535, Teil 3: Die Berichts-Tabs zeigen die Werte des ViewModels (für
/// Angemeldete die des Backends) und rechnen nicht selbst. Feste Daten in
/// KW 41/2026 (Mo 5.10. bis So 11.10.), alles lokal konstruiert, keine
/// Abhängigkeit von heutigem Datum oder Zeitzone.

class _StateViewModel extends ReportsViewModel {
  _StateViewModel(this.initialState);
  final ReportsState initialState;

  @override
  ReportsState build() => initialState;

  @override
  WorkEntryEntity applyBreakCalculation(WorkEntryEntity entry) => entry;

  @override
  void loadCurrentMonthData() {}
}

class _Settings extends SettingsViewModel {
  _Settings(this.settings);
  final SettingsEntity settings;

  @override
  AsyncValue<SettingsState> build() => AsyncValue.data(
      SettingsState(settings: settings, overtimeBalance: Duration.zero));
}

class _NoProfile extends ActiveWorkProfileIdNotifier {
  @override
  String? build() => null;
}

/// Zeichnet die an den PDF-Export übergebenen Werte auf.
class _RecordingPdf extends PdfReportService {
  Duration? weeklyTotal;
  Duration? weeklyOvertime;
  Duration? monthlyTotal;
  Duration? monthlyOvertime;
  Duration? monthlyTotalOvertime;

  @override
  Future<void> exportWeeklyReport({
    required AppLocalizations l10n,
    required String locale,
    required DateTime startOfWeek,
    required DateTime endOfWeek,
    required int weekNumber,
    required int workDays,
    required Duration totalWorkDuration,
    required Duration totalBreakDuration,
    required Duration averageWorkDuration,
    required Duration overtime,
    required Map<DateTime, Duration> dailyWork,
  }) async {
    weeklyTotal = totalWorkDuration;
    weeklyOvertime = overtime;
  }

  @override
  Future<void> exportMonthlyReport({
    required AppLocalizations l10n,
    required String locale,
    required DateTime month,
    required int workDays,
    required Duration totalWorkDuration,
    required Duration totalBreakDuration,
    required Duration averageWorkDuration,
    required Duration avgWorkDurationPerWeek,
    required Duration monthlyOvertime,
    required Duration totalOvertime,
    required Map<int, Duration> weeklyWork,
    required Map<DateTime, Duration> dailyWork,
  }) async {
    monthlyTotal = totalWorkDuration;
    this.monthlyOvertime = monthlyOvertime;
    monthlyTotalOvertime = totalOvertime;
  }
}

/// API: ohne [answers] offline (lokale, kanonische Rechnung bleibt stehen),
/// sonst feste Antworten wie vom Backend.
class _Api extends Fake implements ApiClient {
  _Api([this.answers]);
  final ({
    Map<String, dynamic> daily,
    Map<String, dynamic> weekly,
    Map<String, dynamic> monthly,
  })? answers;

  Future<Map<String, dynamic>> _or(Map<String, dynamic>? v, String op) async {
    if (v == null) throw ApiException(op, 503);
    return v;
  }

  @override
  Future<Map<String, dynamic>> getDailyReport(int y, int m, int d,
          {String? profileId}) =>
      _or(answers?.daily, 'getDailyReport');
  @override
  Future<Map<String, dynamic>> getWeeklyReport(int y, int m, int d,
          {String? profileId}) =>
      _or(answers?.weekly, 'getWeeklyReport');
  @override
  Future<Map<String, dynamic>> getMonthlyReport(int y, int m,
          {String? profileId}) =>
      _or(answers?.monthly, 'getMonthlyReport');
}

const _user = UserEntity(id: 'u1', email: 'a@b.c');

WorkEntryEntity _work(int day, int sh, int sm, int eh, int em,
    {int pauseMin = 0, Duration? manual}) {
  return WorkEntryEntity(
    id: '2026-10-${day.toString().padLeft(2, '0')}',
    date: DateTime(2026, 10, day),
    workStart: DateTime(2026, 10, day, sh, sm),
    workEnd: DateTime(2026, 10, day, eh, em),
    manualOvertime: manual,
    breaks: [
      if (pauseMin > 0)
        BreakEntity(
          id: 'b$day',
          name: 'Pause',
          start: DateTime(2026, 10, day, 12),
          end: DateTime(2026, 10, day, 12, pauseMin),
        ),
    ],
  );
}

/// KW 41, 40 h an Mo-Fr (Tagessoll 8:00):
/// - Mo 08:00-16:30, Pause 30 min: brutto 8:30, netto 8:00
/// - Di 08:00-17:45, Pause 45 min: brutto 9:45, netto 9:00
/// - Mi Urlaub: 8:00 (geleistet = Soll)
/// - Do 07:30-16:00, Pause 30 min, manuell +0:15: brutto 8:30, netto 8:00
/// - Sa 10:00-12:00 (freier Tag, kein Soll): 2:00
///
/// Brutto 36:45, Pausen 1:45, netto 35:00; Soll 4 x 8:00 = 32:00;
/// Überstunden = 35:00 - 32:00 + 0:15 = +3:15. Arbeitstage 5,
/// Ø 35:00 / 5 = 7:00. Die frühere Widget-Rechnung (Summe der Tageswerte
/// minus Tagessoll je Tag) ergab 36:45 - 5 x 8:00 = -3:15.
List<WorkEntryEntity> _week() => [
      _work(5, 8, 0, 16, 30, pauseMin: 30),
      _work(6, 8, 0, 17, 45, pauseMin: 45),
      WorkEntryEntity(
          id: '2026-10-07',
          date: DateTime(2026, 10, 7),
          type: WorkEntryType.vacation),
      _work(8, 7, 30, 16, 0, pauseMin: 30, manual: const Duration(minutes: 15)),
      _work(10, 10, 0, 12, 0),
    ];

void main() {
  late SharedPreferences prefs;

  setUpAll(() async {
    await initializeDateFormatting('de', null);
    await initializeDateFormatting('en', null);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  /// Pumpt die Berichte. Mit [state] steht der State fest (Fake-ViewModel),
  /// sonst rechnet das echte ViewModel über In-Memory-Repositories.
  Future<void> pump(
    WidgetTester tester, {
    ReportsState? state,
    List<WorkEntryEntity> entries = const [],
    SettingsEntity settings = const SettingsEntity(),
    ApiClient? api,
    PdfReportService? pdf,
    DateTime? now,
    int tab = 0,
    Locale locale = const Locale('de'),
  }) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final work = FakeWorkRepository();
    for (final e in entries) {
      work.store[e.id] = e;
    }
    final settingsRepo = FakeSettingsRepository()
      ..workdays = settings.workdays
      ..weeklyHours = settings.weeklyTargetHours;
    final overtime = FakeOvertimeRepository()
      ..stored = const Duration(hours: 12, minutes: 30);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        clockProvider
            .overrideWithValue(() => now ?? DateTime(2026, 10, 11, 18)),
        sharedPreferencesProvider.overrideWithValue(prefs),
        isPremiumProvider.overrideWithValue(true),
        authStateProvider.overrideWithValue(const AsyncValue.data(_user)),
        activeWorkProfileIdProvider.overrideWith(_NoProfile.new),
        workProfilesProvider
            .overrideWith((ref) async => [WorkProfileEntity.defaultProfile()]),
        workRepositoryProvider.overrideWithValue(work),
        overtimeRepositoryProvider.overrideWithValue(overtime),
        settingsRepositoryProvider.overrideWithValue(settingsRepo),
        settingsViewModelProvider.overrideWith(() => _Settings(settings)),
        apiClientProvider.overrideWithValue(api ?? _Api()),
        if (pdf != null) pdfReportServiceProvider.overrideWithValue(pdf),
        if (state != null)
          reportsViewModelProvider.overrideWith(() => _StateViewModel(state)),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ReportsPage(),
      ),
    ));
    await tester.pumpAndSettle();
    if (tab > 0) {
      final labels = locale.languageCode == 'de'
          ? ['', 'Wöchentlich', 'Monatlich']
          : ['', 'Weekly', 'Monthly'];
      await tester.tap(find.text(labels[tab]));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  }

  ReportsState stateWith({
    DateTime? day,
    DailyReportState daily = DailyReportState.initial,
    WeeklyReportState weekly = WeeklyReportState.initial,
    MonthlyReportState monthly = MonthlyReportState.initial,
  }) {
    final d = day ?? DateTime(2026, 10, 9);
    return ReportsState(
      isLoading: false,
      focusedDay: d,
      selectedDay: d,
      selectedMonth: DateTime(d.year, d.month),
      workEntries: const {},
      dailyReportState: daily,
      weeklyReportState: weekly,
      monthlyReportState: monthly,
    );
  }

  group('Wochen-Tab', () {
    // Bewusst unplausibel: Weder Überstunden noch Gesamtarbeitszeit lassen
    // sich aus den Tageswerten ableiten.
    final weekly = WeeklyReportState(
      totalWorkDuration: const Duration(hours: 50),
      totalBreakDuration: const Duration(hours: 1),
      totalNetWorkDuration: const Duration(hours: 12, minutes: 34),
      averageWorkDuration: const Duration(hours: 6, minutes: 17),
      overtime: const Duration(hours: 7, minutes: 13),
      workDays: 2,
      dailyWork: {
        DateTime(2026, 10, 5): const Duration(hours: 8),
        DateTime(2026, 10, 6): const Duration(hours: 8),
      },
    );

    testWidgets('zeigt Überstunden und Netto aus dem State', (tester) async {
      await pump(tester, state: stateWith(weekly: weekly), tab: 1);

      expect(find.text('12:34:00'), findsOneWidget); // Gesamte Arbeitszeit
      expect(find.text('+07:13'), findsOneWidget); // Überstunden
      expect(find.text('16:00:00'), findsNothing); // Summe der Tageswerte
      expect(find.text('+00:00'), findsNothing); // 2 x (8:00 - 8:00)
      expect(find.text('Anwesenheit pro Tag (inkl. Pausen):'), findsOneWidget);
      expect(find.text('8:00:00'), findsNWidgets(2)); // Tageszeilen brutto
    });

    testWidgets('PDF bekommt dieselben Werte wie die Anzeige', (tester) async {
      final pdf = _RecordingPdf();
      await pump(tester, state: stateWith(weekly: weekly), pdf: pdf, tab: 1);
      await tester.tap(find.byIcon(Icons.picture_as_pdf_outlined));
      await tester.pumpAndSettle();
      expect(pdf.weeklyTotal, const Duration(hours: 12, minutes: 34));
      expect(pdf.weeklyOvertime, const Duration(hours: 7, minutes: 13));
    });

    testWidgets(
        'echtes ViewModel: Pause, Urlaub, freier Tag, manuelle Überstunden',
        (tester) async {
      await pump(tester, entries: _week(), tab: 1);

      expect(find.text('35:00:00'), findsOneWidget); // netto
      expect(find.text('1:45:00'), findsOneWidget); // Pausen
      expect(find.text('7:00:00'), findsOneWidget); // Ø pro Tag
      expect(find.text('+03:15'), findsOneWidget);
      expect(find.text('-03:15'), findsNothing); // alte Widget-Rechnung
      expect(find.text('36:45:00'), findsNothing); // brutto als Summe
      // Tageszeilen brutto: Mo 8:30, Di 9:45, Mi 8:00, Do 8:30, Sa 2:00
      expect(find.text('8:30:00'), findsNWidgets(2));
      expect(find.text('9:45:00'), findsOneWidget);
      expect(find.text('2:00:00'), findsOneWidget);
    });

    testWidgets('angemeldet: Werte der API-Antwort', (tester) async {
      await pump(
        tester,
        entries: _week(),
        api: _Api((
          daily: {'targetMs': 0, 'workedMs': 0, 'overtimeMs': 0},
          weekly: {
            'totalWorkedMs': const Duration(hours: 41).inMilliseconds,
            'totalBreaksMs': const Duration(hours: 2).inMilliseconds,
            'avgPerDayMs': const Duration(hours: 7, minutes: 48).inMilliseconds,
            'overtimeMs':
                const Duration(hours: -1, minutes: -23).inMilliseconds,
            'workDays': 5,
            'days': [
              {
                'date': '2026-10-05T00:00:00Z',
                'workedMs': const Duration(hours: 8, minutes: 30).inMilliseconds
              },
            ],
          },
          monthly: {'workDays': 0},
        )),
        tab: 1,
      );

      expect(find.text('39:00:00'), findsOneWidget); // 41:00 - 2:00
      expect(find.text('-01:23'), findsOneWidget);
      expect(find.text('+03:15'), findsNothing);
    });

    testWidgets('leere Arbeitstage-Liste: kein Absturz', (tester) async {
      await pump(tester,
          entries: _week(),
          settings: const SettingsEntity(workdays: []),
          tab: 1);
      // Ohne Arbeitstage ist das Tagessoll 0 (Backend): Der Urlaub zählt mit
      // 0, netto 27:00 ist ganz Überstunde, dazu 0:15 manuell.
      expect(find.text('27:00:00'), findsOneWidget);
      expect(find.text('+27:15'), findsOneWidget);
    });
  });

  group('Monats-Tab', () {
    final monthly = MonthlyReportState(
      totalWorkDuration: const Duration(hours: 120),
      totalBreakDuration: const Duration(hours: 3),
      totalNetWorkDuration: const Duration(hours: 99, minutes: 1),
      averageWorkDuration: const Duration(hours: 7),
      avgWorkDurationPerWeek: const Duration(hours: 33),
      overtime: const Duration(hours: -2, minutes: -22),
      totalOvertime: const Duration(hours: 5),
      workDays: 3,
      weeklyWork: {41: const Duration(hours: 8)},
      dailyWork: {DateTime(2026, 10, 5): const Duration(hours: 8)},
    );

    testWidgets('zeigt Überstunden und Netto aus dem State', (tester) async {
      await pump(tester, state: stateWith(monthly: monthly), tab: 2);

      expect(find.text('99:01:00'), findsOneWidget);
      expect(find.text('-02:22'), findsOneWidget);
      expect(find.text('+05:00'), findsOneWidget); // Gesamt = Saldo
      expect(find.text('+00:00'), findsNothing); // 8:00 - 8:00
      // Wochen- und Tageszeilen sind brutto und so beschriftet (#535).
      expect(find.text('Wochenübersicht (inkl. Pausen):'), findsOneWidget);
      expect(find.text('Tagesübersicht (inkl. Pausen):'), findsOneWidget);
    });

    // Schmale Breite mit echten Schriften: Screenshot (Testschrift Ahem ist
    // zu breit für die bestehenden Zeilen der Statistikkarte).
    testWidgets('Überschriften auf Englisch', (tester) async {
      await pump(tester,
          state: stateWith(monthly: monthly),
          tab: 2,
          locale: const Locale('en'));
      expect(find.text('Week overview (incl. breaks):'), findsOneWidget);
      expect(find.text('Day overview (incl. breaks):'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('PDF bekommt dieselben Werte wie die Anzeige', (tester) async {
      final pdf = _RecordingPdf();
      await pump(tester, state: stateWith(monthly: monthly), pdf: pdf, tab: 2);
      await tester.tap(find.byIcon(Icons.picture_as_pdf_outlined));
      await tester.pumpAndSettle();
      expect(pdf.monthlyTotal, const Duration(hours: 99, minutes: 1));
      expect(pdf.monthlyOvertime, const Duration(hours: -2, minutes: -22));
      expect(pdf.monthlyTotalOvertime, const Duration(hours: 5));
    });

    testWidgets(
        'echtes ViewModel: Pause, Urlaub, freier Tag, manuelle Überstunden',
        (tester) async {
      await pump(tester, entries: _week(), tab: 2);

      // Gesamte Arbeitszeit netto und Ø pro Woche (nur KW 41 im Monat).
      expect(find.text('35:00:00'), findsNWidgets(2));
      expect(find.text('+03:15'), findsOneWidget); // Überstunden Monat
      expect(find.text('+12:30'), findsOneWidget); // gespeicherter Saldo
      expect(find.text('-03:15'), findsNothing);
    });

    testWidgets('leere Arbeitstage-Liste: kein Absturz', (tester) async {
      await pump(tester,
          entries: _week(),
          settings: const SettingsEntity(workdays: []),
          tab: 2);
      expect(find.text('+27:15'), findsOneWidget);
    });
  });

  group('Tages-Tab', () {
    final closed = _work(9, 8, 0, 16, 30, pauseMin: 30);

    testWidgets('abgeschlossener Tag zeigt Soll, Ist und Saldo aus dem State',
        (tester) async {
      await pump(tester,
          state: stateWith(
            daily: DailyReportState(
              entries: [closed],
              workTime: const Duration(hours: 8, minutes: 30),
              breakTime: const Duration(minutes: 30),
              totalTime: const Duration(hours: 8),
              target: const Duration(hours: 7, minutes: 42),
              worked: const Duration(hours: 7, minutes: 11),
              overtime: const Duration(hours: 3, minutes: 21),
            ),
          ));

      expect(find.text('07:42'), findsOneWidget); // Soll
      expect(find.text('07:11'), findsOneWidget); // Ist
      expect(find.text('+03:21'), findsOneWidget); // Saldo
      expect(find.text('08:00'), findsNothing); // keine eigene Rechnung
      // Die Eintragskarte bleibt Anzeige je Eintrag.
      expect(find.text('Arbeitszeit: 8:00:00'), findsOneWidget);
    });

    testWidgets('laufender heutiger Eintrag zeigt weiter den Live-Wert',
        (tester) async {
      final running = WorkEntryEntity(
        id: '2026-10-09',
        date: DateTime(2026, 10, 9),
        workStart: DateTime(2026, 10, 9, 8),
        breaks: [
          BreakEntity(
              id: 'b',
              name: 'Pause',
              start: DateTime(2026, 10, 9, 12),
              end: DateTime(2026, 10, 9, 12, 30)),
        ],
      );
      // Der Tagesbericht (wie vom Backend) kennt den offenen Eintrag nur mit
      // netto 0.
      await pump(tester,
          now: DateTime(2026, 10, 9, 14),
          state: stateWith(
            daily: DailyReportState(
              entries: [running],
              workTime: Duration.zero,
              breakTime: const Duration(minutes: 30),
              totalTime: Duration.zero,
              target: const Duration(hours: 8),
              worked: Duration.zero,
              overtime: const Duration(hours: -8),
            ),
          ));

      // 08:00 bis 14:00 minus 30 min Pause = 5:30, Saldo 5:30 - 8:00.
      expect(find.text('08:00'), findsOneWidget); // Soll
      expect(find.text('05:30'), findsOneWidget); // Ist live
      expect(find.text('-02:30'), findsOneWidget); // Saldo live
      expect(find.text('-08:00'), findsNothing); // eingefrorener Wert
      expect(find.text('00:00'), findsNothing);
    });

    testWidgets('echtes ViewModel: Urlaub an einem freien Tag', (tester) async {
      // Sa 10.10. Urlaub: Soll = geleistet = Tagessoll, Saldo 0 (#535).
      await pump(tester, now: DateTime(2026, 10, 10, 18), entries: [
        WorkEntryEntity(
            id: '2026-10-10',
            date: DateTime(2026, 10, 10),
            type: WorkEntryType.vacation),
      ]);
      expect(find.text('Soll (Tag):'), findsOneWidget);
      expect(find.text('08:00'), findsNWidgets(2)); // Soll und Ist
      expect(find.text('+00:00'), findsOneWidget);
    });

    testWidgets('leere Arbeitstage-Liste: kein Absturz, Schnelleintrag geht',
        (tester) async {
      await pump(tester, settings: const SettingsEntity(workdays: []));
      await tester.tap(find.text('Schnell-Eintrag (Urlaub, Krank...)'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(QuickEntryDialog), findsOneWidget);
    });
  });
}
