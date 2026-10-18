import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:printing/src/interface.dart' show PrintingPlatform;

import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/providers/subscription_provider.dart';
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
import 'package:flutter_work_time/presentation/view_models/yearly_report_view_model.dart';

import '../../support/fake_printing_platform.dart';
import '../../support/fake_repositories.dart';

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

const _user =
    UserEntity(id: '123', email: 'test@test.com', displayName: 'Test User');

void main() {
  setUpAll(() async {
    await initializeDateFormatting('de', null);
    await initializeDateFormatting('en', null);
  });

  late FakePrintingPlatform platform;
  late FakeWorkRepository repo;

  setUp(() {
    platform = FakePrintingPlatform();
    PrintingPlatform.instance = platform;
    repo = FakeWorkRepository();
    repo.store['2026-06-02'] = _entry(6, 2, homeOffice: true);
    repo.store['2026-06-03'] = _entry(6, 3);
  });

  Future<void> pumpView(
    WidgetTester tester, {
    required Widget view,
    bool premium = true,
    String locale = 'de',
    Size size = const Size(800, 1200),
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
          reportsViewModelProvider.overrideWith(_FakeReportsViewModel.new),
          settingsViewModelProvider.overrideWith(_FakeSettingsViewModel.new),
          yearlyReportViewModelProvider.overrideWith(_FakeYearlyViewModel.new),
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

      expect(find.text('Home-Office-Auswertung (PDF)'), findsOneWidget);
      expect(find.text('Als PDF exportieren'), findsOneWidget);

      await tapAndWait(tester, 'Home-Office-Auswertung (PDF)',
          done: () => platform.lastFilename != null);

      expect(platform.lastFilename, 'Home-Office-Auswertung_2026-06.pdf');
      expect(String.fromCharCodes(platform.lastBytes!.take(4)), '%PDF');
      expect(repo.monthReads, ['2026-06']);
    });

    testWidgets('Jahresansicht: Button lädt 12 Monate und exportiert',
        (tester) async {
      await pumpView(tester, view: const YearlyReportView());

      await tapAndWait(tester, 'Home-Office-Auswertung (PDF)',
          done: () => platform.lastFilename != null);

      expect(platform.lastFilename, 'Home-Office-Auswertung_2026.pdf');
      expect(repo.monthReads.toSet(), {
        for (var m = 1; m <= 12; m++) '2026-${m.toString().padLeft(2, '0')}',
      });
      expect(repo.monthReads, hasLength(12));
    });

    testWidgets('Lesefehler: Snackbar pdfExportFailed, kein Absturz',
        (tester) async {
      repo.failReads = true;
      await pumpView(tester, view: const MonthlyReportView());

      await tapAndWait(tester, 'Home-Office-Auswertung (PDF)',
          done: () => repo.monthReads.isNotEmpty);
      await tester.pump(const Duration(milliseconds: 100));

      expect(platform.lastFilename, isNull);
      expect(find.textContaining('PDF-Export fehlgeschlagen'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Englisch: beschriftet, Monat und Jahr', (tester) async {
      await pumpView(tester, view: const MonthlyReportView(), locale: 'en');
      expect(find.text('Home office report (PDF)'), findsOneWidget);

      await pumpView(tester, view: const YearlyReportView(), locale: 'en');
      expect(find.text('Home office report (PDF)'), findsOneWidget);
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
    });

    testWidgets('Jahresansicht: Paywall-Gate, kein Home-Office-Button',
        (tester) async {
      await pumpView(tester, view: const YearlyReportView(), premium: false);

      expect(find.text('Premium freischalten'), findsOneWidget);
      expect(find.text('Home-Office-Auswertung (PDF)'), findsNothing);
    });
  });
}
