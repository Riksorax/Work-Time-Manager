import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:printing/src/interface.dart' show PrintingPlatform;

import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/providers/subscription_provider.dart';
import 'package:flutter_work_time/core/services/pdf_report_service.dart';
import 'package:flutter_work_time/domain/entities/settings_entity.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/utils/yearly_report_utils.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/screens/reports_page.dart';
import 'package:flutter_work_time/presentation/state/reports_state.dart';
import 'package:flutter_work_time/presentation/state/settings_state.dart';
import 'package:flutter_work_time/presentation/state/yearly_report_state.dart';
import 'package:flutter_work_time/presentation/view_models/reports_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/settings_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/yearly_comparison_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/yearly_report_view_model.dart';

import '../../support/analytics_fixture.dart';
import '../../support/fake_printing_platform.dart';
import '../../support/fake_repositories.dart';
import '../../support/yearly_comparison_fixture.dart';

class _FakeReportsViewModel extends ReportsViewModel {
  @override
  ReportsState build() => ReportsState(
        focusedDay: DateTime(2026, 6, 10),
        selectedDay: DateTime(2026, 6, 10),
        selectedMonth: DateTime(2026, 6),
        workEntries: const {},
      );

  @override
  void loadCurrentMonthData() {}
}

class _FakeSettingsViewModel extends SettingsViewModel {
  @override
  AsyncValue<SettingsState> build() => AsyncValue.data(SettingsState(
      settings: SettingsEntity(), overtimeBalance: Duration.zero));
}

class _FakeYearlyViewModel extends YearlyReportViewModel {
  @override
  YearlyReportState build() => YearlyReportState(
        year: 2026,
        months: List.generate(12, (i) => MonthSummary.empty(i + 1)),
      );

  @override
  Future<void> loadYear(int year) async {}
}

WorkEntryEntity _entry(int month, int day, {bool homeOffice = false}) {
  final id =
      '2026-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  return WorkEntryEntity(
    id: id,
    date: DateTime(2026, month, day),
    workStart: DateTime(2026, month, day, 8),
    workEnd: DateTime(2026, month, day, 16),
    isHomeOffice: homeOffice,
  );
}

/// Zeichnet die an den PDF-Export übergebenen Werte auf und erzeugt das PDF.
class _RecordingPdf extends PdfReportService {
  final calls = <Map<String, Object?>>[];

  @override
  Future<void> exportHomeOfficeReport({
    required AppLocalizations l10n,
    required String locale,
    required String periodLabel,
    required String fileSuffix,
    required int homeOfficeDays,
    required int officeDays,
    required int totalWorkDays,
    required double? ratio,
    List<DateTime>? homeOfficeDates,
    List<(String month, int homeOffice, int office, double? ratio)>? perMonth,
  }) {
    calls.add({
      'periodLabel': periodLabel,
      'homeOfficeDays': homeOfficeDays,
      'officeDays': officeDays,
      'totalWorkDays': totalWorkDays,
      'ratio': ratio,
      'homeOfficeDates': homeOfficeDates,
      'perMonth': perMonth,
    });
    return super.exportHomeOfficeReport(
      l10n: l10n,
      locale: locale,
      periodLabel: periodLabel,
      fileSuffix: fileSuffix,
      homeOfficeDays: homeOfficeDays,
      officeDays: officeDays,
      totalWorkDays: totalWorkDays,
      ratio: ratio,
      homeOfficeDates: homeOfficeDates,
      perMonth: perMonth,
    );
  }
}

const _user =
    UserEntity(id: '123', email: 'test@test.com', displayName: 'Test User');

void main() {
  setUpAll(() async {
    await initializeDateFormatting('de', null);
    await initializeDateFormatting('en', null);
  });

  late FakePrintingPlatform platform;
  late FakeWorkRepository repo;
  late FakeAnalyticsApi api;
  late _RecordingPdf pdf;

  setUp(() {
    platform = FakePrintingPlatform();
    PrintingPlatform.instance = platform;
    repo = FakeWorkRepository();
    repo.store['2026-06-02'] = _entry(6, 2, homeOffice: true);
    repo.store['2026-06-03'] = _entry(6, 3);
    api = FakeAnalyticsApi();
    pdf = _RecordingPdf();
  });

  Future<void> pumpView(
    WidgetTester tester, {
    required Widget view,
    bool premium = true,
    String locale = 'de',
    Size size = const Size(800, 1200),
    String? profileId,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(_user)),
          isPremiumProvider.overrideWithValue(premium),
          workRepositoryProvider.overrideWithValue(repo),
          // Home-Office (#537): angemeldet vom Backend.
          apiClientProvider.overrideWithValue(api),
          activeWorkProfileIdProvider
              .overrideWith(() => TestProfile(profileId)),
          pdfReportServiceProvider.overrideWithValue(pdf),
          reportsViewModelProvider.overrideWith(_FakeReportsViewModel.new),
          settingsViewModelProvider.overrideWith(_FakeSettingsViewModel.new),
          yearlyReportViewModelProvider.overrideWith(_FakeYearlyViewModel.new),
          // Vergleichskarte (#530) steht im Jahres-Tab: fester Ladezustand.
          yearlyComparisonViewModelProvider
              .overrideWith(FakeYearlyComparisonViewModel.new),
        ],
        child: MaterialApp(
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: view),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  /// Tippt den Button und wartet (echte Zeit), bis der PDF-Export fertig ist.
  Future<void> tapAndWait(WidgetTester tester, String label,
      {required bool Function() done}) async {
    await tester.tap(find.text(label));
    await tester.runAsync(() async {
      for (var i = 0; i < 200 && !done(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
    });
    await tester.pump();
  }

  group('Premium', () {
    testWidgets('Monatsansicht: Button exportiert Home-Office-PDF',
        (tester) async {
      await pumpView(tester, view: const MonthlyReportView());

      // Aktionszeile (#535): kurze Beschriftung, voller Text als Tooltip
      // und für Screenreader.
      expect(find.text('Home-Office-PDF'), findsOneWidget);
      expect(find.text('PDF-Export'), findsOneWidget);
      expect(find.byTooltip('Als PDF exportieren'), findsOneWidget);
      expect(find.byTooltip('Home-Office-Auswertung (PDF)'), findsOneWidget);
      expect(find.bySemanticsLabel('Home-Office-Auswertung (PDF)'),
          findsOneWidget);

      await tapAndWait(tester, 'Home-Office-PDF',
          done: () => platform.lastFilename != null);

      expect(platform.lastFilename, 'Home-Office-Auswertung_2026-06.pdf');
      expect(String.fromCharCodes(platform.lastBytes!.take(4)), '%PDF');
      // Angemeldet (#537): ein Aufruf des Jahresendpunkts, keine Einträge
      // gelesen; Monatswerte aus `months[]`, Tage aus `homeOfficeDates`.
      expect(api.homeOfficeCalls, [(year: 2026, profileId: null)]);
      expect(repo.monthReads, isEmpty);
      expect(pdf.calls.single, {
        'periodLabel': 'Juni 2026',
        'homeOfficeDays': 5,
        'officeDays': 10,
        'totalWorkDays': 15,
        'ratio': 5 / 15,
        'homeOfficeDates': [
          DateTime(2026, 6, 2),
          DateTime(2026, 6, 9),
          DateTime(2026, 6, 16),
          DateTime(2026, 6, 23),
          DateTime(2026, 6, 30),
        ],
        'perMonth': null,
      });
    });

    testWidgets('Monatsansicht: Zusatzprofil fragt mit profileId an',
        (tester) async {
      await pumpView(tester, view: const MonthlyReportView(), profileId: 'p1');
      await tapAndWait(tester, 'Home-Office-PDF',
          done: () => platform.lastFilename != null);
      expect(api.homeOfficeCalls, [(year: 2026, profileId: 'p1')]);
    });

    testWidgets('Jahresansicht: Button lädt 12 Monate und exportiert',
        (tester) async {
      await pumpView(tester, view: const YearlyReportView());

      // Jahres-Tab (#284): Auswertungen im Menü des Buttons „PDF-Export“.
      await tester.tap(find.text('PDF-Export'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tapAndWait(tester, 'Home-Office-Auswertung (PDF)',
          done: () => platform.lastFilename != null);

      expect(platform.lastFilename, 'Home-Office-Auswertung_2026.pdf');
      // Angemeldet (#537): ein Aufruf statt 12 Monatsabfragen.
      expect(api.homeOfficeCalls, [(year: 2026, profileId: null)]);
      expect(repo.monthReads, isEmpty);
      final call = pdf.calls.single;
      expect(call['homeOfficeDays'], 6);
      expect(call['officeDays'], 12);
      expect(call['totalWorkDays'], 18);
      expect(call['ratio'], 6 / 18);
      expect(call['homeOfficeDates'], isNull);
      final perMonth = call['perMonth']! as List<(String, int, int, double?)>;
      expect(perMonth, hasLength(12));
      expect(perMonth[0], ('Januar', 0, 0, null));
      expect(perMonth[2], ('März', 1, 2, 1 / 3));
      expect(perMonth[5], ('Juni', 5, 10, 5 / 15));
    });

    testWidgets('Ladefehler: Snackbar pdfExportFailed, kein Absturz',
        (tester) async {
      api.onHomeOffice = (_) async => throw StateError('kaputt');
      await pumpView(tester, view: const MonthlyReportView());

      await tapAndWait(tester, 'Home-Office-PDF',
          done: () => api.homeOfficeCalls.isNotEmpty);
      await tester.pump(const Duration(milliseconds: 100));

      expect(platform.lastFilename, isNull);
      // Verständliche Meldung ohne Ausnahmetext (#582).
      expect(
          find.text('Der PDF-Export ist fehlgeschlagen. Bitte versuche es '
              'erneut.'),
          findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.textContaining('kaputt'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Englisch: beschriftet, Monat und Jahr', (tester) async {
      await pumpView(tester, view: const MonthlyReportView(), locale: 'en');
      expect(find.text('Home office PDF'), findsOneWidget);
      expect(find.byTooltip('Home office report (PDF)'), findsOneWidget);

      await pumpView(tester, view: const YearlyReportView(), locale: 'en');
      await tester.tap(find.text('PDF export'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Home office report (PDF)'), findsOneWidget);
    });

    testWidgets('Englisch: Backend-Werte im Monats- und Jahres-PDF',
        (tester) async {
      await pumpView(tester, view: const MonthlyReportView(), locale: 'en');
      await tapAndWait(tester, 'Home office PDF',
          done: () => platform.lastFilename != null);
      expect(pdf.calls.single['periodLabel'], 'June 2026');
      expect(pdf.calls.single['homeOfficeDays'], 5);

      platform.lastFilename = null;
      await pumpView(tester, view: const YearlyReportView(), locale: 'en');
      await tester.tap(find.text('PDF export'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tapAndWait(tester, 'Home office report (PDF)',
          done: () => platform.lastFilename != null);
      final perMonth =
          pdf.calls.last['perMonth']! as List<(String, int, int, double?)>;
      expect(perMonth[5], ('June', 5, 10, 5 / 15));
      expect(api.homeOfficeCalls, hasLength(2));
    });

    for (final locale in ['de', 'en']) {
      testWidgets('schmale Breite ohne Overflow (Monat, $locale)',
          (tester) async {
        await pumpView(tester,
            view: const MonthlyReportView(),
            locale: locale,
            size: const Size(280, 800));
        expect(tester.takeException(), isNull);
      });

      // Ein-Zeilen-Layout und vollständige Texte prüft
      // reports_page_action_row_test mit der echten Schrift; hier (Testschrift,
      // jedes Zeichen 1 em breit) nur: kein Overflow.
      for (final width in [360.0, 412.0]) {
        testWidgets(
            'Monat: Export-Buttons ohne Overflow (${width.toInt()} px, $locale)',
            (tester) async {
          await pumpView(tester,
              view: const MonthlyReportView(),
              locale: locale,
              size: Size(width, 800));
          expect(tester.takeException(), isNull);
          expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
          expect(find.byIcon(Icons.home_work_outlined), findsOneWidget);
        });
      }

      testWidgets('schmale Breite ohne Overflow (Jahr, $locale)',
          (tester) async {
        await pumpView(tester,
            view: const YearlyReportView(),
            locale: locale,
            size: const Size(280, 800));
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Free', () {
    testWidgets('Monatsansicht: Paywall-Gate, kein Home-Office-Button',
        (tester) async {
      await pumpView(tester, view: const MonthlyReportView(), premium: false);

      expect(find.text('Premium freischalten'), findsOneWidget);
      expect(find.text('Home-Office-Auswertung (PDF)'), findsNothing);
      expect(find.text('Home-Office-PDF'), findsNothing);
    });

    testWidgets('Jahresansicht: Paywall-Gate, kein Home-Office-Button',
        (tester) async {
      await pumpView(tester, view: const YearlyReportView(), premium: false);

      expect(find.text('Premium freischalten'), findsOneWidget);
      expect(find.text('Home-Office-Auswertung (PDF)'), findsNothing);
    });
  });
}
