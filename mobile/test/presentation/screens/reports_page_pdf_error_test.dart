import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:logger/logger.dart';
import 'package:printing/src/interface.dart' show PrintingPlatform;

import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/providers/subscription_provider.dart';
import 'package:flutter_work_time/core/utils/api_errors.dart';
import 'package:flutter_work_time/domain/entities/settings_entity.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';
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

import '../../support/fake_printing_platform.dart';
import '../../support/fake_repositories.dart';
import '../../support/offline_fixture.dart' show hostLookupError;
import '../../support/reported_logs.dart';
import '../../support/yearly_comparison_fixture.dart';

// #582: Scheitert ein PDF-Export, zeigt die Snackbar eine verständliche
// Meldung ohne Ausnahmetext; erwartbare Netzwerkfehler nur als logger.i.
// Der Fehler kommt aus dem letzten Schritt (Teilen des PDFs), so laufen alle
// Export-Wege bis zum Ende.

class _FailingPrintingPlatform extends FakePrintingPlatform {
  _FailingPrintingPlatform(this.error);
  final Object error;
  int calls = 0;

  @override
  Future<bool> sharePdf(Uint8List bytes, String filename, Rect bounds,
      String? subject, String? body, List<String>? emails) async {
    calls++;
    throw error;
  }
}

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

const _user =
    UserEntity(id: '123', email: 'test@test.com', displayName: 'Test User');

/// Der rohe Text, den die Snackbar früher zeigte.
const _rawParts = ['ClientException', 'SocketException', 'uri=', 'https://'];

/// Im Log steht nur der Typ (`errorLabel`), nie der Ausnahmetext.
const _rawLogParts = [
  'SocketException',
  'Failed host lookup',
  'uri=',
  'https://'
];

void main() {
  final logs = <LogEvent>[];
  captureLogs(logs);

  setUpAll(() async {
    await initializeDateFormatting('de', null);
    await initializeDateFormatting('en', null);
  });

  Future<_FailingPrintingPlatform> pumpView(WidgetTester tester, Widget view,
      {required Object error, String locale = 'de'}) async {
    final platform = _FailingPrintingPlatform(error);
    PrintingPlatform.instance = platform;
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(_user)),
        isPremiumProvider.overrideWithValue(true),
        workRepositoryProvider.overrideWithValue(FakeWorkRepository()),
        reportsViewModelProvider.overrideWith(_FakeReportsViewModel.new),
        settingsViewModelProvider.overrideWith(_FakeSettingsViewModel.new),
        yearlyReportViewModelProvider.overrideWith(_FakeYearlyViewModel.new),
        yearlyComparisonViewModelProvider
            .overrideWith(FakeYearlyComparisonViewModel.new),
      ],
      child: MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: view),
      ),
    ));
    await tester.pump();
    await tester.pump();
    return platform;
  }

  Future<void> tapAndWait(WidgetTester tester, String label,
      _FailingPrintingPlatform platform) async {
    await tester.tap(find.text(label));
    await tester.runAsync(() async {
      for (var i = 0; i < 400 && platform.calls == 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> openYearMenu(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  void expectClean(WidgetTester tester, String message) {
    expect(find.text(message), findsOneWidget);
    for (final part in _rawParts) {
      expect(find.textContaining(part), findsNothing, reason: part);
    }
    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.backgroundColor, Colors.red);
    for (final e in logs) {
      for (final part in _rawLogParts) {
        expect(e.message.toString(), isNot(contains(part)),
            reason: 'Log ohne Ausnahmetext');
      }
    }
  }

  for (final (locale, offlineText, generalText, pdf, homeOffice, yearly) in [
    (
      'de',
      'Keine Verbindung. Prüfe deine Internetverbindung und versuche es '
          'erneut.',
      'Der PDF-Export ist fehlgeschlagen. Bitte versuche es erneut.',
      'PDF-Export',
      'Home-Office-PDF',
      'Jahresbericht (PDF)',
    ),
    (
      'en',
      'No connection. Check your internet connection and try again.',
      'PDF export failed. Please try again.',
      'PDF export',
      'Home office PDF',
      'Yearly report (PDF)',
    ),
  ]) {
    group('Sprache $locale', () {
      final cases = <(String, Widget, Future<void> Function(WidgetTester))>[
        ('Wochenbericht', const WeeklyReportView(), (_) async {}),
        ('Monatsbericht', const MonthlyReportView(), (_) async {}),
      ];
      for (final (what, view, _) in cases) {
        testWidgets('$what: Netzwerkfehler → „Keine Verbindung“, logger.i',
            (tester) async {
          final p = await pumpView(tester, view,
              error: hostLookupError, locale: locale);
          await tapAndWait(tester, pdf, p);
          expectClean(tester, offlineText);
          expect(reported(logs, '[PDF-Export]'), isEmpty);
        });

        testWidgets('$what: anderer Fehler → allgemeine Meldung, logger.e',
            (tester) async {
          final p = await pumpView(tester, view,
              error: const ApiException('x', 500), locale: locale);
          await tapAndWait(tester, pdf, p);
          expectClean(tester, generalText);
          final r = reported(logs, '[PDF-Export] $what');
          expect(r, hasLength(1));
          expect(r.single.message.toString(), contains('ApiException(500)'));
        });
      }

      testWidgets('Home-Office Monat: Netzwerkfehler', (tester) async {
        final p = await pumpView(tester, const MonthlyReportView(),
            error: hostLookupError, locale: locale);
        await tapAndWait(tester, homeOffice, p);
        expectClean(tester, offlineText);
        expect(reported(logs, '[PDF-Export]'), isEmpty);
      });

      testWidgets('Jahresbericht: allgemeiner Fehler', (tester) async {
        final p = await pumpView(tester, const YearlyReportView(),
            error: StateError('kaputt'), locale: locale);
        await openYearMenu(tester, pdf);
        await tapAndWait(tester, yearly, p);
        expectClean(tester, generalText);
        expect(find.textContaining('kaputt'), findsNothing);
        expect(reported(logs, '[PDF-Export] Jahresbericht'), hasLength(1));
      });

      testWidgets('Home-Office Jahr: Netzwerkfehler', (tester) async {
        final p = await pumpView(tester, const YearlyReportView(),
            error: hostLookupError, locale: locale);
        await openYearMenu(tester, pdf);
        await tapAndWait(
            tester,
            locale == 'de'
                ? 'Home-Office-Auswertung (PDF)'
                : 'Home office report (PDF)',
            p);
        expectClean(tester, offlineText);
        expect(reported(logs, '[PDF-Export]'), isEmpty);
      });
    });
  }
}
